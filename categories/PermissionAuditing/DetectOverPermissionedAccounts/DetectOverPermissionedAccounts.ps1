<#
.SYNOPSIS
  Detect over-permissioned accounts (users or groups) on NTFS paths.

.DESCRIPTION
  Walks ACLs on one or more roots and flags ACEs that grant high rights (Write/Modify/Full)
  to accounts not in an allow-list. Optionally expands AD groups recursively to show
  user membership that inherits those rights (effective risk).

.PARAMETER Path
  One or more root paths (UNC or local).

.PARAMETER Recurse
  Recurse into subfolders. Use -MaxDepth to control scope.

.PARAMETER MaxDepth
  Maximum recursion depth when -Recurse is set (default: 5).

.PARAMETER IncludeFiles
  If set, evaluate files as well as folders.

.PARAMETER ResolveSIDs
  Resolve SID to NTAccount. Recommended when using -AllowedPrincipals/-DeniedPrincipals.

.PARAMETER MinRight
  Minimum right to flag: 'Write', 'Modify', or 'FullControl'. Default: 'Modify'.

.PARAMETER AllowedPrincipals
  Principals (domain\group or user) allowed to have >= MinRight without being flagged.

.PARAMETER ExcludePrincipals
  Principals to ignore entirely (e.g., 'BUILTIN\Administrators','NT AUTHORITY\SYSTEM').

.PARAMETER IncludePathLike
  Optional wildcard filter for paths to include (e.g., '*\Finance\*').

.PARAMETER ExcludePathLike
  Optional wildcard filter for paths to exclude.

.PARAMETER ExpandADGroups
  If set, expand AD group members recursively (requires RSAT ActiveDirectory). Emits additional rows per user.

.PARAMETER Domain
  Optional AD domain (DNS name) for queries when expanding groups.

.PARAMETER OutputCsv
  Optional CSV output for findings.

.EXAMPLES
  # Flag anything >= Modify that isn't explicitly allowed
  .\DetectOverPermissionedAccounts.ps1 -Path '\\fs01\Projects' -Recurse -MaxDepth 4 `
    -AllowedPrincipals 'CONTOSO\FileAdmins','CONTOSO\Project-Leads' -OutputCsv .\overperm.csv

  # Expand group membership to list at-risk users (effective access)
  .\DetectOverPermissionedAccounts.ps1 -Path 'D:\Data' -Recurse -ExpandADGroups -ResolveSIDs -MinRight Write -Verbose

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Scope: -Path, -Recurse, -MaxDepth, -IncludeFiles
  - Threshold: -MinRight (Write/Modify/FullControl)
  - Policy: -AllowedPrincipals, -ExcludePrincipals
  - Filters: -IncludePathLike, -ExcludePathLike
  - SID resolution & AD expansion: -ResolveSIDs, -ExpandADGroups, -Domain
  - Exports: -OutputCsv
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [string[]]$Path,

  [Parameter()]
  [switch]$Recurse,

  [Parameter()]
  [ValidateRange(1,64)]
  [int]$MaxDepth = 5,

  [Parameter()]
  [switch]$IncludeFiles,

  [Parameter()]
  [switch]$ResolveSIDs,

  [Parameter()]
  [ValidateSet('Write','Modify','FullControl')]
  [string]$MinRight = 'Modify',

  [Parameter()]
  [string[]]$AllowedPrincipals = @('BUILTIN\Administrators','NT AUTHORITY\SYSTEM'),

  [Parameter()]
  [string[]]$ExcludePrincipals,

  [Parameter()]
  [string]$IncludePathLike,

  [Parameter()]
  [string]$ExcludePathLike,

  [Parameter()]
  [switch]$ExpandADGroups,

  [Parameter()]
  [string]$Domain,

  [Parameter()]
  [string]$OutputCsv
)

begin {
  function Simplify-Right {
    param([System.Security.AccessControl.FileSystemRights]$r)
    if ($r -band [System.Security.AccessControl.FileSystemRights]::FullControl) { return 'FullControl' }
    if ($r -band [System.Security.AccessControl.FileSystemRights]::Modify)      { return 'Modify' }
    if ($r -band [System.Security.AccessControl.FileSystemRights]::Write)       { return 'Write' }
    return 'ReadOrLower'
  }

  function Meets-Threshold {
    param([string]$simple,[string]$min='Modify')
    switch ($min) {
      'FullControl' { return ($simple -eq 'FullControl') }
      'Modify'      { return ($simple -eq 'FullControl' -or $simple -eq 'Modify') }
      'Write'       { return ($simple -in @('FullControl','Modify','Write')) }
    }
  }

  function Res-Name {
    param($id,[switch]$DoResolve)
    try {
      if (-not $DoResolve) { return $id.Value }
      $sid = try { New-Object System.Security.Principal.SecurityIdentifier($id.Value) } catch { $null }
      if ($sid) { return ($sid.Translate([System.Security.Principal.NTAccount])).Value }
      return $id.Value
    } catch { return $id.Value }
  }

  function Enum-Targets {
    param([string]$root,[switch]$Recurse,[int]$MaxDepth,[switch]$Files)
    $targets = @($root)
    if ($Recurse) {
      $dirs = Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue
      $targets += $dirs.FullName
      if ($Files) {
        $targets += (Get-ChildItem -Path $root -File -Recurse -ErrorAction SilentlyContinue).FullName
      }
      if ($MaxDepth -gt 0) {
        $base = ($root -split '[\\/]').Count
        $targets = $targets | Where-Object { (($_ -split '[\\/]').Count - $base) -le $MaxDepth }
      }
    }
    return $targets | Sort-Object -Unique
  }

  function AD-Expand {
    param([string]$Principal,[string]$Domain)
    # Returns list of user SamAccountNames (or domain\user) for a group principal
    try {
      Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
      $isGroup = (Get-ADGroup -Identity $Principal -Server $Domain -ErrorAction SilentlyContinue)
      if (-not $isGroup) { return @() }
      $mem = Get-ADGroupMember -Identity $Principal -Recursive -Server $Domain -ErrorAction Stop |
             Where-Object { $_.objectClass -eq 'user' }
      return $mem | ForEach-Object { $_.SamAccountName }
    } catch { return @() }
  }

  $findings = New-Object System.Collections.Generic.List[Object]
}

process {
  foreach ($root in $Path) {
    if (-not (Test-Path $root)) { Write-Warning "Path not found: $root"; continue }

    $targets = Enum-Targets -root $root -Recurse:$Recurse.IsPresent -MaxDepth $MaxDepth -Files:$IncludeFiles.IsPresent

    foreach ($t in $targets) {
      if ($IncludePathLike -and ($t -notlike $IncludePathLike)) { continue }
      if ($ExcludePathLike -and ($t -like  $ExcludePathLike))   { continue }

      try {
        $acl = Get-Acl -LiteralPath $t
      } catch { Write-Verbose "ACL read failed for $t : $($_.Exception.Message)"; continue }

      foreach ($ace in $acl.Access) {
        $principal = Res-Name -id $ace.IdentityReference -DoResolve:$ResolveSIDs.IsPresent

        if ($ExcludePrincipals -and ($principal -in $ExcludePrincipals)) { continue }

        $right = Simplify-Right -r $ace.FileSystemRights
        $isHigh = Meets-Threshold -simple $right -min $MinRight
        if (-not $isHigh) { continue }

        $isAllow = ($ace.AccessControlType -eq 'Allow')
        if (-not $isAllow) { continue } # focus on over-permissioned (Allow)

        $allowed = ($AllowedPrincipals -contains $principal)
        if ($allowed) { continue }

        # At this point: candidate finding
        $finding = [pscustomobject]@{
          Path            = $t
          Principal       = $principal
          Rights          = $right
          IsInherited     = $ace.IsInherited
          InheritanceOn   = -not $acl.AreAccessRulesProtected
          AccessType      = $ace.AccessControlType
          IncludeReason   = ">= $MinRight and not in AllowedPrincipals"
          EffectiveUsers  = $null
        }

        if ($ExpandADGroups) {
          # Only attempt expansion for group-like principals
          $users = AD-Expand -Principal $principal -Domain $Domain
          if ($users.Count -gt 0) { $finding.EffectiveUsers = ($users -join '; ') }
        }

        $findings.Add($finding)
      }
    }
  }
}

end {
  $out = $findings | Sort-Object Path, Principal

  if ($OutputCsv) {
    try { $out | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
  }

  $out | Format-Table -AutoSize
}