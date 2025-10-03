# BulkMailboxCreation

Bulk create and enable Exchange mailboxes from CSV for both Exchange Online and on-premises Exchange environments.

## Overview

This PowerShell script provides enterprise-grade bulk mailbox creation capabilities with support for both cloud and on-premises environments. It handles existing user scenarios, new user creation, licensing (EXO), and comprehensive validation with idempotent operations.

## Key Features

### Multi-Environment Support
- **Exchange Online (EXO)**: Cloud mailbox creation with Entra ID integration
- **On-Premises Exchange**: Traditional Exchange server mailbox enabling
- **Flexible Modes**: Choose between existing users or new user creation
- **Credential Management**: Secure authentication for both environments

### CSV-Driven Operations
- **Comprehensive Column Support**: UPN, SamAccountName, DisplayName, SMTP addresses, aliases
- **Optional Fields**: Regional settings, licensing, organizational units, passwords
- **Validation and Inference**: Automatically derives missing values where possible
- **Case-Insensitive Headers**: Flexible CSV format handling

### Mailbox Creation Modes

#### Exchange Online
- **OnlineExisting**: Create mailboxes for existing Entra ID users (recommended)
- **OnlineCreate**: Create new Entra ID users, assign licenses, and enable mailboxes

#### On-Premises Exchange
- **OnPremExisting**: Enable mailboxes for existing Active Directory users (recommended)
- **OnPremCreate**: Create new AD users and enable mailboxes (requires RSAT)

## Script Parameters

### Required Parameters
- **CsvPath**: Path to input CSV file containing mailbox data
- **Mode**: Operation mode (OnlineExisting/OnlineCreate/OnPremExisting/OnPremCreate)

### Connection Parameters
- **ConnectOnline**: Connect to Exchange Online using EXO V3 module
- **ConnectOnPrem**: Connect to on-premises Exchange via PowerShell remoting
- **OnPremUri**: Exchange server PowerShell URI (e.g., https://exch01.contoso.com/powershell/)
- **Credential**: PSCredential for authentication (prompts if not provided)

### Configuration Parameters
- **DomainSuffix**: Default SMTP domain when PrimarySmtpAddress is missing
- **DefaultPassword**: SecureString default password for new user scenarios
- **WhatIf**: Preview operations without making changes
- **OutputCsv**: CSV file path for operation results and audit trail

## CSV Column Reference

### Required Columns (Mode-Dependent)
- **UserPrincipalName**: Required for Exchange Online operations
- **SamAccountName**: Required for on-premises operations (especially when creating users)

### Standard User Attributes
- **DisplayName**: Full display name for the mailbox
- **FirstName**: Given name (used for user creation)
- **LastName**: Surname (used for user creation)
- **PrimarySmtpAddress**: Primary email address (derived from UPN if missing)
- **Alias**: Mail nickname (derived from UPN if missing)

### Environment-Specific Columns
- **OU**: Organizational Unit DN for new on-premises users
- **InitialPassword**: Password for new user creation (overrides DefaultPassword)
- **LicenseSku**: Exchange Online license (e.g., 'ENTERPRISEPACK')
- **UsageLocation**: Country code for licensing (e.g., 'US')
- **TimeZone**: Mailbox timezone (e.g., 'Pacific Standard Time')
- **Language**: Mailbox language (e.g., 'en-US')

## Usage Examples

### Exchange Online - Existing Users
```powershell
# Create mailboxes for existing Entra ID users
.\BulkMailboxCreation.ps1 -CsvPath .\new_mailboxes.csv -Mode OnlineExisting -ConnectOnline -Verbose
```

### Exchange Online - New Users with Licensing
```powershell
# Create users, assign licenses, and create mailboxes
$cred = Get-Credential
$password = Read-Host "Default password" -AsSecureString
.\BulkMailboxCreation.ps1 -CsvPath .\hires.csv -Mode OnlineCreate -ConnectOnline -Credential $cred -DomainSuffix contoso.com -DefaultPassword $password -Verbose
```

### On-Premises Exchange - Existing AD Users
```powershell
# Enable mailboxes for existing Active Directory users
.\BulkMailboxCreation.ps1 -CsvPath .\ad_users.csv -Mode OnPremExisting -ConnectOnPrem -OnPremUri https://ex01.contoso.com/powershell/ -Verbose
```

### Preview Mode with Audit Trail
```powershell
# Preview operations and export results
.\BulkMailboxCreation.ps1 -CsvPath .\mailbox_list.csv -Mode OnlineExisting -ConnectOnline -WhatIf -OutputCsv .\preview_results.csv
```

### Batch Processing with Error Handling
```powershell
# Process large batches with comprehensive logging
$results = @()
Get-Content .\department_csvs.txt | ForEach-Object {
    $result = .\BulkMailboxCreation.ps1 -CsvPath $_ -Mode OnPremExisting -ConnectOnPrem -OnPremUri https://ex01/powershell/ -OutputCsv ".\results_$(Split-Path $_ -Leaf)"
    $results += $result
}
```

## Sample CSV Formats

### Exchange Online - Existing Users
```csv
UserPrincipalName,DisplayName,PrimarySmtpAddress,Alias
john.doe@contoso.com,John Doe,john.doe@contoso.com,johndoe
jane.smith@contoso.com,Jane Smith,jane.smith@contoso.com,janesmith
```

### Exchange Online - New Users with Licensing
```csv
UserPrincipalName,FirstName,LastName,DisplayName,LicenseSku,UsageLocation,TimeZone,Language
new.user1@contoso.com,New,User1,New User1,ENTERPRISEPACK,US,Pacific Standard Time,en-US
new.user2@contoso.com,New,User2,New User2,ENTERPRISEPACK,US,Eastern Standard Time,en-US
```

### On-Premises Exchange - Existing AD Users
```csv
SamAccountName,UserPrincipalName,DisplayName,PrimarySmtpAddress,Alias
jdoe,john.doe@contoso.local,John Doe,john.doe@contoso.com,johndoe
jsmith,jane.smith@contoso.local,Jane Smith,jane.smith@contoso.com,janesmith
```

## Error Handling and Validation

### Pre-Execution Validation
- **CSV File Existence**: Validates input file before processing
- **Required Columns**: Ensures necessary columns are present for selected mode
- **Connection Testing**: Verifies Exchange connectivity before bulk operations
- **Module Dependencies**: Checks for required PowerShell modules

### Per-Row Processing
- **Idempotent Operations**: Skips existing mailboxes gracefully
- **Data Validation**: Validates email addresses, licensing requirements, and user attributes
- **Graceful Failures**: Individual row failures don't stop batch processing
- **Detailed Error Messages**: Comprehensive error information for troubleshooting

### Result Tracking
- **Success/Failure Status**: Clear indication of operation results
- **Action Descriptions**: Detailed description of what was performed
- **Error Messages**: Specific error information for failed operations
- **CSV Export**: Audit trail suitable for change management processes

## Prerequisites

### Exchange Online Requirements
- **PowerShell 5.1+** or **PowerShell 7+**
- **ExchangeOnlineManagement** module (V3 recommended)
- **Exchange Administrator** role (minimum)
- **User Administrator** and **License Administrator** roles (for user creation)
- **MSOnline** or **Microsoft.Graph** modules (for user/license management)

### On-Premises Exchange Requirements
- **Exchange Management Tools** on administrative workstation
- **PowerShell Remoting** access to Exchange server
- **Exchange Organization Management** role (minimum)
- **Active Directory RSAT** tools (for user creation scenarios)
- **Network Connectivity** to Exchange server PowerShell endpoint

## Security Considerations

### Credential Management
- **Secure Storage**: Use credential managers for stored credentials
- **Least Privilege**: Assign minimum required permissions
- **Session Cleanup**: Properly disconnect from Exchange sessions
- **Audit Logging**: Maintain comprehensive audit trails

### Password Handling
- **SecureString**: Always use SecureString for password parameters
- **No Plaintext Storage**: Avoid storing passwords in CSV files
- **Secure Transmission**: Ensure encrypted communication channels
- **Password Policies**: Comply with organizational password requirements

### Access Control
- **Service Account**: Use dedicated service accounts for bulk operations
- **Role Separation**: Separate mailbox creation from licensing operations
- **Change Approval**: Implement change management processes
- **Testing Environments**: Validate scripts in non-production environments

## Troubleshooting

### Common Issues
- **Connection Failures**: Check network connectivity and authentication
- **Permission Denied**: Verify administrative rights and role assignments
- **Module Not Found**: Install required PowerShell modules
- **CSV Format Errors**: Validate CSV structure and encoding

### Diagnostic Steps
1. **Test Connectivity**: Verify Exchange connectivity manually
2. **Validate Permissions**: Check user roles and permissions
3. **Module Verification**: Confirm PowerShell module availability
4. **CSV Inspection**: Review input data for formatting issues

### Resolution Strategies
- **Connection Retry**: Implement retry logic for transient failures
- **Batch Processing**: Process large datasets in smaller chunks
- **Error Isolation**: Use WhatIf mode to identify issues before execution
- **Logging Enhancement**: Increase verbosity for detailed troubleshooting

## Integration Notes

### SCCM/Automation Integration
- Suitable for packaging as SCCM applications or scripts
- Can be triggered by Configuration Manager compliance rules
- Results integrate with SCCM reporting infrastructure

### Identity Management Integration
- Designed to complement HR-driven provisioning systems
- Can be triggered by identity lifecycle management solutions
- Supports integration with third-party identity governance platforms

### Monitoring and Alerting
- CSV results suitable for SIEM ingestion
- Success/failure metrics support operational dashboards
- Error conditions can trigger automated alerts

### GUI Development Readiness
All parameters and operations are designed for GUI implementation:
- File picker dialogs for CSV selection and result export
- Mode selection with dynamic field requirements
- Connection wizards with credential management
- Progress indicators and real-time status updates
- Results viewer with filtering, sorting, and export capabilities