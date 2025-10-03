# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------

<#
.SYNOPSIS
  Resets passwords for one or more AD users, with optional unlock and forced change on next logon.

.DESCRIPTION
  - Accepts user identities directly or via CSV.
  - Can generate random strong passwords and export results.
  - Supports -WhatIf, -Confirm, and -Verbose.

.REQUIREMENTS
  - RSAT Active Directory module.
  - Rights to reset passwords and unlock accounts.

.CSV SCHEMA (when using -CsvPath):
  Identity  (SamAccountName or DN)
  NewPassword (optional; if omitted and -GenerateRandom is used, script will generate)

.EXAMPLES
  PS> .\PasswordReset.ps1 -Identity alice,bob -NewPassword (Read-Host "New" -AsSecureString) -ForceChangeAtLogon -Verbose -WhatIf
  PS> .\PasswordReset.ps1 -CsvPath .\reset.csv -GenerateRandom -ExportCsv .\reset-out.csv -Unlock
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(ParameterSetName='Direct', Mandatory=$false)]
  [string[]]$Identity,

  [Parameter(ParameterSetName='Csv', Mandatory=$true)]
  [ValidateScript({ Test-Path $_ })]
  [string]$CsvPath,

  [Parameter()]
  [SecureString]$NewPassword,   # If omitted AND -GenerateRandom is used, passwords are generated.

  [Parameter()]
  [switch]$GenerateRandom,

  [Parameter()]
  [switch]$ForceChangeAtLogon,

  [Parameter()]
  [switch]$Unlock,

  [Parameter()]
  [string]$ExportCsv  # When generating random passwords, export results here (plain text password)
)

function New-RandomPassword {
  param([int]$Length = 16)
  # Simple strong generator; customize for your policy
  $chars = (33..126) | ForEach-Object {[char]$_} | Where-Object { $_ -notin @('"','`','\') }
  -join (1..$Length | ForEach-Object { $chars | Get-Random })
}

begin {
  try { Import-Module ActiveDirectory -ErrorAction Stop } catch { throw "Missing ActiveDirectory module." }

  $items = @()
  switch ($PSCmdlet.ParameterSetName) {
    'Direct' {
      if (-not $Identity) { throw "Provide -Identity or use -CsvPath." }
      $items = $Identity | ForEach-Object { [pscustomobject]@{ Identity = $_; NewPassword = $null } }
    }
    'Csv' {
      $items = Import-Csv -Path $CsvPath
      if (-not $items) { throw "CSV '$CsvPath' is empty or unreadable." }
    }
  }

  $results = New-Object System.Collections.Generic.List[Object]
}

process {
  foreach ($item in $items) {
    $id = $item.Identity
    if (-not $id) { Write-Warning "Row missing Identity; skipping."; continue }

    $pwdPlain = $null
    $pwdSecure = $NewPassword
    if (-not $pwdSecure) {
      if ($GenerateRandom) {
        $pwdPlain = New-RandomPassword
        $pwdSecure = ConvertTo-SecureString -String $pwdPlain -AsPlainText -Force
      } elseif ($item.PSObject.Properties.Match('NewPassword').Count -gt 0 -and $item.NewPassword) {
        $pwdSecure = ConvertTo-SecureString -String $item.NewPassword -AsPlainText -Force
      } else {
        throw "No password provided for '$id'. Provide -NewPassword, include NewPassword in CSV, or use -GenerateRandom."
      }
    }

    if ($PSCmdlet.ShouldProcess("AD User '$id'", "Reset password")) {
      try {
        Set-ADAccountPassword -Identity $id -NewPassword $pwdSecure -Reset -ErrorAction Stop
        if ($Unlock) { Unlock-ADAccount -Identity $id -ErrorAction SilentlyContinue }
        if ($ForceChangeAtLogon) { Set-ADUser -Identity $id -ChangePasswordAtLogon $true -ErrorAction SilentlyContinue }

        $results.Add([pscustomobject]@{
          Identity   = $id
          Password   = $pwdPlain  # null if not generated/known
          Changed    = $true
          ForcedCPW  = [bool]$ForceChangeAtLogon
          Unlocked   = [bool]$Unlock
        })
        Write-Verbose "Password reset for '$id'."
      } catch {
        Write-Error "Failed to reset '$id': $($_.Exception.Message)"
        $results.Add([pscustomobject]@{
          Identity   = $id
          Password   = $pwdPlain
          Changed    = $false
          ForcedCPW  = [bool]$ForceChangeAtLogon
          Unlocked   = [bool]$Unlock
        })
      }
    }
  }
}

end {
  if ($ExportCsv) {
    try {
      $results | Export-Csv -Path $ExportCsv -NoTypeInformation
      Write-Verbose "Results exported to '$ExportCsv'."
    } catch {
      Write-Warning "Failed to export results: $($_.Exception.Message)"
    }
  }
  $results | Format-Table -AutoSize
}