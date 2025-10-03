# PasswordReset

**Summary:** Provides secure password reset functionality for Active Directory users with automatic random password generation, compliance checking, and comprehensive logging. The script supports both individual user resets and bulk operations via CSV input, with optional account unlocking and forced password change requirements. Features safe testing modes and detailed audit trails.

## Status
✅ **Fully Implemented** - Production ready with comprehensive error handling and security features.

## Usage
```powershell
# Reset specific users with manual password and force change at next logon (dry-run)
.\PasswordReset.ps1 -Identity alice,bob -NewPassword (Read-Host "New" -AsSecureString) -ForceChangeAtLogon -WhatIf -Verbose

# Use CSV and generate random passwords automatically; export results to CSV
.\PasswordReset.ps1 -CsvPath .\reset.csv -GenerateRandom -ExportCsv .\reset-out.csv -Unlock -Verbose
```

## CSV Schema
**Required columns:** `Identity` (SamAccountName or DN)
**Optional columns:** `NewPassword` (not needed if using -GenerateRandom)

## Features
- **Random Password Generation:** Strong 16-character passwords with customizable policies
- **Account Unlocking:** Automatically unlock accounts during password reset
- **Audit Trail:** Export results with plain-text passwords for secure distribution
- **Safety Controls:** Full -WhatIf and -Verbose support for testing