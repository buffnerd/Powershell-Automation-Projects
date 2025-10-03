# User Account Management

Scripts to administer Active Directory user accounts safely and at scale: **bulk creation**, **password resets**, and **inactive account reporting/remediation**. All scripts support `-WhatIf` and `-Verbose` for safe testing.

---

## Prerequisites

- Domain-joined admin workstation or a jump host
- **RSAT Active Directory** module installed
- Permissions:
  - Create users / set attributes (Bulk creation)
  - Reset passwords / unlock accounts (Password reset)
  - Disable / move objects (Inactive report remediation)
- Access to any file shares used for home directories (if applicable)

---

## Projects

### [Basic-Powershell-Administration](./Basic-Powershell-Administration/) 
Fundamental AD user lifecycle management scripts for creation, modification, and deletion.

### [Bulk-Updating-Proxy-Address-Attributes](./Bulk-Updating-Proxy-Address-Attributes/) 
Mass proxy address updates via CSV for Exchange integration and email routing.

### [BulkUserCreation](./BulkUserCreation/) ✅ **IMPLEMENTED**
Create multiple users from a CSV with optional group assignments and home-folder provisioning.

**CSV columns (minimum):**  
`SamAccountName, GivenName, Surname`  
**Optional:** `DisplayName, UserPrincipalName, OU, Department, Title, Email, Manager, Groups`  
- `Groups` is semicolon-separated (e.g., `GG_HR;GG_AllStaff`)

**Examples**
```powershell
# Dry-run (WhatIf) with verbose logging
.\BulkUserCreation.ps1 -CsvPath .\users.csv -TargetOU "OU=Staff,OU=Corp,DC=contoso,DC=com" `
  -DefaultUPNSuffix "@contoso.com" -DefaultPassword (Read-Host "Password" -AsSecureString) `
  -AddToGroups "GG_AllStaff" -Verbose -WhatIf

# Create and enable users, create home folders
.\BulkUserCreation.ps1 -CsvPath .\users.csv -TargetOU "OU=Staff,OU=Corp,DC=contoso,DC=com" `
  -DefaultUPNSuffix "@contoso.com" -DefaultPassword (Read-Host "Password" -AsSecureString) `
  -EnableAccounts -CreateHomeFolders -HomeRootPath "\\fs01\homes" -AddToGroups "GG_AllStaff" -Verbose
```

**Environment settings to adjust:**
- `-TargetOU` (OU DN for your environment)
- `-DefaultUPNSuffix` (e.g., @contoso.com)
- `-HomeRootPath` (UNC path to file server share)
- Default groups (`-AddToGroups`)

### [PasswordReset](./PasswordReset/) ✅ **IMPLEMENTED**
Reset passwords for one or many users. Supports input via `-Identity` or `-CsvPath`, optional unlock, and forced change at next logon. Can generate random strong passwords and export to CSV.

**CSV columns (when using -CsvPath):**
`Identity` (SamAccountName or DN), `NewPassword` (optional if using -GenerateRandom)

**Examples**
```powershell
# Reset two specific users and force a change at next logon (dry-run)
.\PasswordReset.ps1 -Identity alice,bob -NewPassword (Read-Host "New" -AsSecureString) -ForceChangeAtLogon -WhatIf -Verbose

# Use CSV and generate passwords automatically; export results to CSV
.\PasswordReset.ps1 -CsvPath .\reset.csv -GenerateRandom -ExportCsv .\reset-out.csv -Unlock -Verbose
```

**Environment settings to adjust:**
- Password policy (length/charset in New-RandomPassword)
- Whether to unlock accounts (`-Unlock`)
- Where to store exported CSV (`-ExportCsv`)

### [InactiveAccountReport](./InactiveAccountReport/) ✅ **IMPLEMENTED**
Report AD users inactive for N days, with optional disable and move-to-OU remediation.

**Examples**
```powershell
# Report inactive for 90 days under Staff OU and export to CSV
.\InactiveAccountReport.ps1 -DaysInactive 90 -SearchBase "OU=Staff,OU=Corp,DC=contoso,DC=com" -ExportCsv .\inactive.csv -Verbose

# Disable and move inactive accounts to a quarantine OU (dry-run first!)
.\InactiveAccountReport.ps1 -DaysInactive 180 -Disable -MoveToOU "OU=Disabled,OU=Corp,DC=contoso,DC=com" -WhatIf -Verbose
```

**Environment settings to adjust:**
- OU scope (`-SearchBase`)
- Quarantine OU (`-MoveToOU`)
- Cutoff days (`-DaysInactive`)
- Export path (`-ExportCsv`)

---

## Safety & Rollback

- Always start with `-WhatIf` and `-Verbose`.
- For bulk actions, keep your CSV files in version control.
- If you disable or move users mistakenly:
  - Re-enable with `Enable-ADAccount -Identity <SamAccountName>`
  - Move back with `Move-ADObject -Identity <DN> -TargetPath <OriginalOU>`

---

## Future GUI Integration

- Prompt user for OU pickers, UPN suffix, group multi-select, share path.
- Validate share existence & permissions before enabling home folders.
- Confirm password policy (length/charset) before generation.
- Support preview mode showing the exact changes before apply.