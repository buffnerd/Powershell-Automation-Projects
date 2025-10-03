<#
.SYNOPSIS
  Generates a Windows Update compliance report per computer (missing important updates).

.DESCRIPTION
  Uses the Windows Update COM API to query for applicable, not-yet-installed updates.
  Reports counts and titles (optional). Works with WSUS or Microsoft Update.

.PARAMETER ComputerName
  One or more computers.

.PARAMETER Credential
  Optional credential for remote execution.

.PARAMETER IncludeTitles
  If set, include a semicolon-separated list of pending update titles.

.PARAMETER OutputCsv
  Optional CSV path for results.

.EXAMPLES
  PS> .\PatchComplianceReport.ps1 -ComputerName (gc .\servers.txt) -IncludeTitles -OutputCsv .\patch_report.csv
  PS> .\PatchComplianceReport.ps1 -ComputerName server01 -Verbose

.REQUIREMENTS
  - Windows Update Service running on targets.
  - Network access to WSUS or Internet (based on policy).
  - Rights to execute remote scripts.

.NOTES (Environment adjustments & future GUI prompts)
  - Targets: host list / AD query (GUI).
  - Toggle `-IncludeTitles` and CSV export (GUI).
  - Consider adding severity filters in GUI (e.g., Security/Critical only).
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [switch]$IncludeTitles,

  [Parameter()]
  [string]$OutputCsv
)

$results = New-Object System.Collections.Generic.List[Object]

$scriptBlock = {
  param($includeTitles)
  try {
    $session = New-Object -ComObject 'Microsoft.Update.Session'
    $searcher = $session.CreateUpdateSearcher()
    # Filter: not installed, not hidden, software updates
    $criteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"
    $result = $searcher.Search($criteria)

    $missing = 0
    $titles = @()
    if ($result.Updates) {
      foreach ($upd in $result.Updates) {
        # Optionally inspect $upd.Categories for Security/Critical filtering
        $missing++
        if ($includeTitles) { $titles += $upd.Title }
      }
    }

    return [pscustomobject]@{
      MissingCount = $missing
      Titles       = ($titles -join '; ')
    }
  } catch {
    return [pscustomobject]@{
      MissingCount = -1
      Titles       = "Error: $($_.Exception.Message)"
    }
  }
}

foreach ($cn in $ComputerName) {
  try {
    $data = if ($Credential) {
      Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $IncludeTitles.IsPresent -ErrorAction Stop
    } else {
      Invoke-Command -ComputerName $cn -ScriptBlock $scriptBlock -ArgumentList $IncludeTitles.IsPresent -ErrorAction Stop
    }

    $status = if ($data.MissingCount -eq 0) { 'Compliant' }
              elseif ($data.MissingCount -gt 0) { 'NonCompliant' }
              else { 'Error' }
              
    $row = [pscustomobject]@{
      ComputerName = $cn
      MissingCount = $data.MissingCount
      Titles       = if ($IncludeTitles) { $data.Titles } else { $null }
      Status       = $status
    }
    $results.Add($row)
  } catch {
    $results.Add([pscustomobject]@{
      ComputerName = $cn
      MissingCount = -1
      Titles       = "Error: $($_.Exception.Message)"
      Status       = 'Error'
    })
  }
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Sort-Object ComputerName | Format-Table -AutoSize