# InactiveAccountReport

**Summary:** Analyzes Active Directory to identify and report user accounts that have been inactive for specified periods using lastLogonTimestamp conversion to accurate dates. This script helps maintain security compliance by identifying potentially abandoned accounts that should be disabled or removed, with optional automated remediation including account disabling and quarantine OU movement.

## Status
✅ **Fully Implemented** - Production ready with comprehensive reporting and remediation capabilities.

## Usage
```powershell
# Report inactive accounts for 90 days under Staff OU and export to CSV
.\InactiveAccountReport.ps1 -DaysInactive 90 -SearchBase "OU=Staff,OU=Corp,DC=contoso,DC=com" -ExportCsv .\inactive.csv -Verbose

# Disable and move inactive accounts to quarantine OU (dry-run first!)
.\InactiveAccountReport.ps1 -DaysInactive 180 -Disable -MoveToOU "OU=Disabled,OU=Corp,DC=contoso,DC=com" -WhatIf -Verbose
```

## Features
- **Accurate Date Conversion:** Converts lastLogonTimestamp to readable DateTime for precise inactivity calculation
- **Flexible Scoping:** Target specific OUs with -SearchBase parameter
- **Automated Remediation:** Optional account disabling and quarantine OU movement
- **Comprehensive Reporting:** Detailed CSV export with last logon dates and inactivity periods
- **Safety Controls:** Full -WhatIf support for testing remediation actions