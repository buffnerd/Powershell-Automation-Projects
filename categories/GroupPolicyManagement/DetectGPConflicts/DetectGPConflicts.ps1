<#
.SYNOPSIS
  Detect conflicting registry-backed GPO settings in an OU's inheritance chain.

.DESCRIPTION
  - Builds the effective link order for an OU (highest precedence last).
  - Extracts registry policy items from each linked GPO (Computer + User).
  - Flags keys/values that appear in multiple GPOs with different data.
  - Indicates which GPO "wins" based on link order and enforcement.

.PARAMETER TargetOU
  Distinguished Name (DN) of the OU to analyze. Example: "OU=Workstations,OU=Corp,DC=contoso,DC=com"

.PARAMETER Domain
  Optional AD domain (DNS name). Uses the current domain if omitted.

.PARAMETER IncludeEnforcedOnly
  If set, only considers links marked Enforced (rare; not typical).

.PARAMETER IncludeComputer
  Include Computer Configuration (default: on).

.PARAMETER IncludeUser
  Include User Configuration (default: on).

.PARAMETER OutputCsv
  Optional CSV export for conflicts.

.PARAMETER OutputHtml
  Optional HTML export (human-readable).

.EXAMPLES
  # Full conflict analysis for an OU, CSV + HTML
  .\DetectGPConflicts.ps1 -TargetOU "OU=Workstations,OU=Corp,DC=contoso,DC=com" -OutputCsv .\gpo_conflicts.csv -OutputHtml .\gpo_conflicts.html -Verbose

  # User config only
  .\DetectGPConflicts.ps1 -TargetOU "OU=Sales,DC=contoso,DC=com" -IncludeComputer:$false -IncludeUser:$true -Verbose

.REQUIREMENTS
  - RSAT Group Policy Management Console (GPMC) PowerShell module (`GroupPolicy`).
  - Rights to read GPOs and OU link info.

.NOTES (Environment adjustments & future GUI prompts)
  - OU picker tree (GUI).
  - Toggles for Computer/User configuration.
  - Filters for enforced-only links.
  - Export destinations (CSV/HTML).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$TargetOU,

  [Parameter()]
  [string]$Domain,

  [Parameter()]
  [switch]$IncludeEnforcedOnly,

  [Parameter()]
  [bool]$IncludeComputer = $true,

  [Parameter()]
  [bool]$IncludeUser = $true,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputHtml
)

begin {
  try { Import-Module GroupPolicy -ErrorAction Stop } catch { throw "GroupPolicy module not found. Install RSAT: GPMC." }

  if (-not $IncludeComputer -and -not $IncludeUser) {
    throw "Nothing to analyze. Enable IncludeComputer and/or IncludeUser."
  }

  $domainArg = @{}
  if ($Domain) { $domainArg['Domain'] = $Domain }

  $conflicts = New-Object System.Collections.Generic.List[Object]
}

process {
  # 1) Get OU inheritance: list of links in processing order
  try {
    $inh = Get-GPInheritance -Target $TargetOU @domainArg
  } catch {
    throw "Failed to get GP inheritance for $TargetOU : $($_.Exception.Message)"
  }

  # Links come as "Links" with properties: GPOName, Enabled, Enforced, Order
  # Effective precedence: LOWER 'Order' applies LAST (wins). We'll sort by Order ascending to know final winners.
  $links = $inh.Links | Where-Object { $_.Enabled -eq $true } |
           Where-Object { -not $IncludeEnforcedOnly -or $_.Enforced -eq $true } |
           Sort-Object Order

  if (-not $links) {
    Write-Warning "No enabled GPO links found for $TargetOU with current filters."
    return
  }

  # 2) Pull registry policy items from each linked GPO
  #    Build a map: Scope (Computer/User) + Hive + Key + ValueName  -> list of (GPO, Data, Winning?)
  $items = @{}

  foreach ($link in $links) {
    $gpoName = $link.GPOName
    try {
      $gpo = Get-GPO -Name $gpoName @domainArg -ErrorAction Stop
      $xml = Get-GPOReport -Guid $gpo.Id -ReportType Xml
      [xml]$doc = $xml

      if ($IncludeComputer) {
        # Computer registry policies
        $nodes = $doc.GPO.Computer.ExtensionData.Extension | Where-Object { $_.name -like '*Registry*' }
        foreach ($n in $nodes) {
          foreach ($rs in $n.RegistrySettings.Registry) {
            $hive  = $rs.hive
            $key   = $rs.key
            $name  = $rs.name
            $type  = $rs.type
            $value = $rs.value
            $k = "Computer|$hive|$key|$name"
            if (-not $items.ContainsKey($k)) { $items[$k] = New-Object System.Collections.Generic.List[Object] }
            $items[$k].Add([pscustomobject]@{ Scope='Computer'; GPO=$gpo.DisplayName; Enforced=$link.Enforced; Order=$link.Order; Hive=$hive; Key=$key; Name=$name; Type=$type; Value=$value })
          }
        }
      }

      if ($IncludeUser) {
        # User registry policies
        $nodes = $doc.GPO.User.ExtensionData.Extension | Where-Object { $_.name -like '*Registry*' }
        foreach ($n in $nodes) {
          foreach ($rs in $n.RegistrySettings.Registry) {
            $hive  = $rs.hive
            $key   = $rs.key
            $name  = $rs.name
            $type  = $rs.type
            $value = $rs.value
            $k = "User|$hive|$key|$name"
            if (-not $items.ContainsKey($k)) { $items[$k] = New-Object System.Collections.Generic.List[Object] }
            $items[$k].Add([pscustomobject]@{ Scope='User'; GPO=$gpo.DisplayName; Enforced=$link.Enforced; Order=$link.Order; Hive=$hive; Key=$key; Name=$name; Type=$type; Value=$value })
          }
        }
      }

    } catch {
      Write-Warning "Failed to analyze GPO '$gpoName': $($_.Exception.Message)"
      continue
    }
  }

  # 3) Find conflicts: same (Scope+Hive+Key+Name) set more than once with different values
  foreach ($pair in $items.GetEnumerator()) {
    $list = $pair.Value
    if ($list.Count -lt 2) { continue }

    # Are there multiple distinct values?
    $values = $list | Select-Object -ExpandProperty Value -Unique
    if ($values.Count -gt 1) {
      # Determine winner: highest precedence (lowest Order value applies last in practice)
      $winner = $list | Sort-Object Order | Select-Object -First 1
      foreach ($entry in $list) {
        $conflicts.Add([pscustomobject]@{
          Scope      = $entry.Scope
          Hive       = $entry.Hive
          Key        = $entry.Key
          ValueName  = $entry.Name
          ValueData  = $entry.Value
          GPO        = $entry.GPO
          Enforced   = $entry.Enforced
          LinkOrder  = $entry.Order
          WinnerGPO  = $winner.GPO
          WinnerData = $winner.Value
          Conflict   = ($entry.GPO -ne $winner.GPO)
        })
      }
    }
  }
}

end {
  if ($OutputCsv) {
    try { $conflicts | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
  }

  if ($OutputHtml) {
    $style = @"
<style>
table { border-collapse: collapse; font-family: Segoe UI, Arial, sans-serif; font-size: 12px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; }
th { background: #f4f4f4; text-align: left; }
tr:nth-child(even) { background: #fafafa; }
.conflict { background: #fff3f3; }
.winner { font-weight: 600; }
</style>
"@
    $rows = $conflicts | Sort-Object Scope, Hive, Key, ValueName, LinkOrder
    $html = $rows | ConvertTo-Html -Title "GPO Conflict Report" -Head $style -PreContent "<h2>GPO Conflict Report</h2><p>Target OU: $TargetOU</p><p>Generated: $(Get-Date)</p>"
    try { $html | Out-File -FilePath $OutputHtml -Encoding UTF8 } catch { Write-Warning "HTML export failed: $($_.Exception.Message)" }
  }

  if (-not $OutputCsv -and -not $OutputHtml) {
    $conflicts | Sort-Object Scope, Hive, Key, ValueName, LinkOrder | Format-Table -AutoSize
  }
}