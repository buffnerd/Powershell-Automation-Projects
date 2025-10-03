# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------

<#
.SYNOPSIS
  Bulk creates Active Directory users from a CSV with safe defaults.

.DESCRIPTION
  - Reads a CSV and creates AD users with specified attributes.
  - Supports per-user OU and group assignments from CSV.
  - Optional home folder creation with NTFS permissions.
  - Forces password change at next logon by default.
  - Safe to test with -WhatIf and verbose with -Verbose.

.REQUIREMENTS
  - RSAT Active Directory module installed (PowerShell).
  - Run as a domain user with permissions to create users (and folders, if enabled).

.CSV SCHEMA (columns)
  Required:
    SamAccountName, GivenName, Surname
  Optional (highly recommended):
    DisplayName, UserPrincipalName, OU, Department, Title, Email, Manager, Groups
      - Groups: semicolon-separated list (e.g., "GG_HR;GG_AllStaff")

.EXAMPLES
  PS> .\BulkUserCreation.ps1 -CsvPath .\users.csv -TargetOU "OU=Staff,OU=Corp,DC=contoso,DC=com" `
       -DefaultUPNSuffix "@contoso.com" -DefaultPassword (Read-Host "Password" -AsSecureString) -EnableAccounts `
       -CreateHomeFolders -HomeRootPath "\\fs01\homes" -AddToGroups "GG_AllStaff" -Verbose -WhatIf

.NOTES (Adjustments for your environment)
  - Update -TargetOU to your default staging OU DN.
  - Set -DefaultUPNSuffix to your domain UPN suffix (e.g., @contoso.com).
  - If using home folders, set -HomeRootPath to your file server share and ensure the script runner can create folders.
  - Pre-create/securitize any default groups you pass in -AddToGroups.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory)]
  [ValidateScript({ Test-Path $_ })]
  [string]$CsvPath,

  [Parameter(Mandatory)]
  [SecureString]$DefaultPassword,

  [Parameter()]
  [string]$TargetOU, # Default OU if row doesn't specify OU

  [Parameter()]
  [string]$DefaultUPNSuffix = "@contoso.com",

  [Parameter()]
  [switch]$EnableAccounts,  # If not specified, users are created disabled (safer)

  [Parameter()]
  [switch]$CreateHomeFolders,

  [Parameter()]
  [ValidateScript({ $_ -match '^[\\]{2}.+' })]
  [string]$HomeRootPath,    # e.g., \\fs01\homes

  [Parameter()]
  [string[]]$AddToGroups    # Default groups for all created users (optional)
)

begin {
  try {
    Import-Module ActiveDirectory -ErrorAction Stop
  } catch {
    throw "ActiveDirectory module not found. Install RSAT or run on a domain-joined admin host."
  }

  if ($CreateHomeFolders -and -not $HomeRootPath) {
    throw "When -CreateHomeFolders is used, you must supply -HomeRootPath (e.g., \\fs01\homes)."
  }

  $users = Import-Csv -Path $CsvPath
  if (-not $users) { throw "CSV '$CsvPath' is empty or unreadable." }

  Write-Verbose "Loaded $($users.Count) row(s) from CSV."
}

process {
  foreach ($row in $users) {
    # Required fields
    $sam   = $row.SamAccountName
    $given = $row.GivenName
    $sn    = $row.Surname

    if (-not $sam -or -not $given -or -not $sn) {
      Write-Warning "Skipping row missing required fields (SamAccountName/GivenName/Surname). Row: $($row | ConvertTo-Json -Compress)"
      continue
    }

    # Optional fields and sensible defaults
    $display = if ($row.DisplayName) { $row.DisplayName } else { "$given $sn" }
    $upn     = if ($row.UserPrincipalName) { $row.UserPrincipalName } else { "$sam$DefaultUPNSuffix" }
    $ou      = if ($row.OU) { $row.OU } elseif ($TargetOU) { $TargetOU } else { $null }
    $dept    = $row.Department
    $title   = $row.Title
    $email   = $row.Email
    $manager = $row.Manager
    $rowGroups = @()
    if ($row.Groups) { $rowGroups = $row.Groups -split ';' | Where-Object { $_ -and $_.Trim() } }

    $enable = [bool]$EnableAccounts

    # Build New-ADUser arguments
    $newUserParams = @{
      SamAccountName            = $sam
      Name                      = $display
      GivenName                 = $given
      Surname                   = $sn
      DisplayName               = $display
      UserPrincipalName         = $upn
      AccountPassword           = $DefaultPassword
      ChangePasswordAtLogon     = $true
      Enabled                   = $enable
      ErrorAction               = 'Stop'
    }
    if ($ou)      { $newUserParams['Path']       = $ou }
    if ($dept)    { $newUserParams['Department'] = $dept }
    if ($title)   { $newUserParams['Title']      = $title }
    if ($email)   { $newUserParams['EmailAddress'] = $email }
    if ($manager) { $newUserParams['Manager']    = $manager }

    if ($PSCmdlet.ShouldProcess("AD User '$sam'", "Create")) {
      try {
        # If user already exists, skip gracefully
        $existing = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
        if ($existing) {
          Write-Warning "User '$sam' already exists (DN: $($existing.DistinguishedName)). Skipping create."
        } else {
          New-ADUser @newUserParams
          Write-Verbose "Created user '$sam'."
        }

        # Group membership (row-specific first, then default groups)
        $allGroups = @()
        if ($rowGroups) { $allGroups += $rowGroups }
        if ($AddToGroups) { $allGroups += $AddToGroups }
        $allGroups = $allGroups | Select-Object -Unique

        foreach ($g in $allGroups) {
          if (-not $g) { continue }
          if ($PSCmdlet.ShouldProcess("User '$sam'", "Add to group '$g'")) {
            try {
              Add-ADGroupMember -Identity $g -Members $sam -ErrorAction Stop
              Write-Verbose "Added '$sam' to '$g'."
            } catch {
              Write-Warning "Failed to add '$sam' to '$g': $($_.Exception.Message)"
            }
          }
        }

        # Home folder provisioning (optional)
        if ($CreateHomeFolders) {
          $userHome = Join-Path $HomeRootPath $sam
          if ($PSCmdlet.ShouldProcess("FileSystem '$userHome'", "Create & set NTFS perms")) {
            if (-not (Test-Path $userHome)) {
              New-Item -Path $userHome -ItemType Directory -Force | Out-Null
            }
            # Grant user full control on their home folder (NTFS)
            try {
              $acl = Get-Acl $userHome
              $id  = New-Object System.Security.Principal.NTAccount("$env:USERDOMAIN",$sam)
              $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
              $acl.SetAccessRule($rule)
              Set-Acl -Path $userHome -AclObject $acl
              Write-Verbose "Set NTFS permissions on '$userHome'."
            } catch {
              Write-Warning "Failed to set NTFS permissions for '$sam' on '$userHome': $($_.Exception.Message)"
            }

            # Optional: update AD home directory attributes
            try {
              Set-ADUser -Identity $sam -HomeDirectory $userHome -HomeDrive "H:" -ErrorAction Stop
            } catch {
              Write-Warning "Failed to set AD home directory attributes for '$sam': $($_.Exception.Message)"
            }
          }
        }

      } catch {
        Write-Error "Error creating user '$sam': $($_.Exception.Message)"
      }
    }
  }
}

end {
  Write-Verbose "Bulk user creation process completed."
}