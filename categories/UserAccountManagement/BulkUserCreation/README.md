# BulkUserCreation

**Summary:** Automates the creation of multiple Active Directory user accounts from CSV input files with comprehensive attribute support, group assignments, and optional home folder provisioning. This script standardizes user creation with consistent naming conventions, organizational unit placement, and security group assignments while supporting per-user overrides. Features safe testing with -WhatIf and detailed logging with -Verbose.

## Status
✅ **Fully Implemented** - Production ready with comprehensive error handling and safety features.

## Usage
```powershell
# Dry-run (WhatIf) with verbose logging
.\BulkUserCreation.ps1 -CsvPath .\users.csv -TargetOU "OU=Staff,OU=Corp,DC=contoso,DC=com" `
  -DefaultUPNSuffix "@contoso.com" -DefaultPassword (Read-Host "Password" -AsSecureString) `
  -AddToGroups "GG_AllStaff" -Verbose -WhatIf

# Create and enable users with home folders
.\BulkUserCreation.ps1 -CsvPath .\users.csv -TargetOU "OU=Staff,OU=Corp,DC=contoso,DC=com" `
  -DefaultUPNSuffix "@contoso.com" -DefaultPassword (Read-Host "Password" -AsSecureString) `
  -EnableAccounts -CreateHomeFolders -HomeRootPath "\\fs01\homes" -AddToGroups "GG_AllStaff" -Verbose
```

## CSV Schema
**Required columns:** `SamAccountName`, `GivenName`, `Surname`
**Optional columns:** `DisplayName`, `UserPrincipalName`, `OU`, `Department`, `Title`, `Email`, `Manager`, `Groups`
- `Groups` field uses semicolon separation (e.g., "GG_HR;GG_AllStaff")