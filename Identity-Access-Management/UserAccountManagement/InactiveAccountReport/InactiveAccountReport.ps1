# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------

<#
.SYNOPSIS
  Reports AD users inactive for N days; optional disable and move to quarantine OU.

.DESCRIPTION
  - Calculates inactivity via lastLogonTimestamp -> DateTime.
  - Filters by OU (SearchBase) and can include disabled users if requested.
  - Optional remediation: Disable-ADAccount and/or Move-ADObject.
  - Exports to CSV.

.REQUIREMENTS
  - RSAT Active Directory module.
  - Rights to query, disable, and move AD objects as applicable.

.EXAMPLES
  PS> .\InactiveAccountReport.ps1 -DaysInactive 90 -SearchBase "OU=Staff,OU=Corp,DC=contoso,DC=com" -ExportCsv .\inactive.csv -Verbose
  PS> .\InactiveAccountReport.ps1 -DaysInactive 180 -Disable -MoveToOU "OU=Disabled,OU=Corp,DC=contoso,DC=com" -WhatIf -Verbose
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter()]
  [ValidateRange(1, 3650)]
  [int]$DaysInactive = 90,

  [Parameter()]
  [string]$SearchBase,            # OU DN to scope search

  [Parameter()]
  [switch]$IncludeDisabled,

  [Parameter()]
  [string]$ExportCsv,

  [Parameter()]
  [switch]$Disable,               # Disable found accounts

  [Parameter()]
  [string]$MoveToOU               # Move found accounts to this OU (DN)
)

function Convert-LLTToDate {
  param([long]$LLT)
  if (-not $LLT) { return $null }
  return [DateTime]::FromFileTime($LLT)
}

begin {
  try { Import-Module ActiveDirectory -ErrorAction Stop } catch { throw "Missing ActiveDirectory module." }

  $filter = if ($IncludeDisabled) { "*" } else { "(Enabled -eq $true)" }
  $props  = @("SamAccountName","Enabled","LastLogonTimeStamp","DistinguishedName","whenCreated","DisplayName")
  $getParams = @{
    LDAPFilter   = $null
    Filter       = $filter
    Properties   = $props
    ErrorAction  = 'Stop'
  }
  if ($SearchBase) { $getParams['SearchBase'] = $SearchBase }

  $now = Get-Date
  $cutoff = $now.AddDays(-$DaysInactive)
  $results = New-Object System.Collections.Generic.List[Object]
}

process {
  try {
    $users = Get-ADUser @getParams
  } catch {
    throw "Failed to query AD users: $($_.Exception.Message)"
  }

  foreach ($u in $users) {
    $lastLogon = Convert-LLTToDate -LLT $u.LastLogonTimeStamp
    # If lastLogon is null, consider account inactive since creation date
    $lastActive = if ($lastLogon) { $lastLogon } else { $u.whenCreated }
    if ($lastActive -lt $cutoff) {
      $results.Add([pscustomobject]@{
        SamAccountName = $u.SamAccountName
        DisplayName    = $u.DisplayName
        Enabled        = $u.Enabled
        LastLogon      = $lastLogon
        ConsideredInactiveSince = $lastActive
        DaysInactive   = [int]($now - $lastActive).TotalDays
        DN             = $u.DistinguishedName
      })
    }
  }
}

end {
  if ($Disable -or $MoveToOU) {
    foreach ($r in $results) {
      if ($Disable -and $PSCmdlet.ShouldProcess("User '$($r.SamAccountName)'", "Disable")) {
        try {
          Disable-ADAccount -Identity $r.SamAccountName -ErrorAction Stop
          Write-Verbose "Disabled '$($r.SamAccountName)'."
        } catch {
          Write-Warning "Failed to disable '$($r.SamAccountName)': $($_.Exception.Message)"
        }
      }
      if ($MoveToOU) {
        if ($PSCmdlet.ShouldProcess("User '$($r.SamAccountName)'", "Move to '$MoveToOU'")) {
          try {
            Move-ADObject -Identity $r.DN -TargetPath $MoveToOU -ErrorAction Stop
            Write-Verbose "Moved '$($r.SamAccountName)' to '$MoveToOU'."
          } catch {
            Write-Warning "Failed to move '$($r.SamAccountName)': $($_.Exception.Message)"
          }
        }
      }
    }
  }

  if ($ExportCsv) {
    try {
      $results | Sort-Object DaysInactive -Descending | Export-Csv -Path $ExportCsv -NoTypeInformation
      Write-Verbose "Exported report to '$ExportCsv'."
    } catch {
      Write-Warning "Failed to export report: $($_.Exception.Message)"
    }
  }

  $results | Sort-Object DaysInactive -Descending | Format-Table -AutoSize
}