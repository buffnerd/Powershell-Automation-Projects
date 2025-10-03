# Outlook / Exchange Automation

Enterprise-grade PowerShell scripts for **mailbox provisioning at scale** and **comprehensive quota auditing**. Supports both **Exchange Online** and **on-premises Exchange** environments.

## Category Overview

This category provides essential Exchange administration capabilities with support for both cloud and on-premises environments. All scripts are designed for enterprise-scale operations with comprehensive error handling, audit trails, and flexible deployment options.

## Scripts in this Category

### [BulkMailboxCreation](./BulkMailboxCreation/)
**CSV-driven bulk mailbox provisioning with multi-environment support**
- **Purpose**: Create and enable mailboxes in bulk from CSV for existing or new users
- **Key Features**: EXO/on-prem support, user creation, licensing, regional settings, idempotent operations
- **Modes**: OnlineExisting, OnlineCreate, OnPremExisting, OnPremCreate
- **Use Cases**: New hire onboarding, department migrations, bulk provisioning projects

### [MailboxQuotaReport](./MailboxQuotaReport/)
**Comprehensive mailbox quota analysis and reporting**
- **Purpose**: Audit mailbox sizes against quotas with threshold analysis and multi-format exports
- **Key Features**: Percentage calculations, archive statistics, CSV/HTML exports, filtering
- **Environments**: Exchange Online and on-premises Exchange
- **Use Cases**: Capacity planning, quota compliance, storage optimization, alerting

## Common Features

### Multi-Environment Support
- **Exchange Online**: Full EXO V3 module integration with modern authentication
- **On-Premises Exchange**: PowerShell remoting with implicit session management
- **Hybrid Scenarios**: Flexible connection options for mixed environments
- **Credential Management**: Secure authentication with prompting and session reuse

### Enterprise Integration
- **CSV-Driven Operations**: Structured input/output for automation and integration
- **Audit Trails**: Comprehensive logging suitable for compliance and change management
- **Error Handling**: Graceful failure handling with detailed error reporting
- **Performance Optimization**: Efficient processing for large-scale operations

### Automation Ready
- **WhatIf Support**: Preview operations before execution (BulkMailboxCreation)
- **Threshold Filtering**: Configurable filtering for targeted operations
- **Export Flexibility**: Multiple output formats (CSV, HTML) for different use cases
- **Scripted Integration**: Designed for scheduled tasks and automation platforms

## Prerequisites

### Exchange Online
- **PowerShell 5.1+** (or 7+) with **ExchangeOnlineManagement** module
- **Administrative Permissions**:
  - Exchange Administrator (minimum for mailbox operations)
  - User Administrator + License Administrator (for user creation scenarios)
- **Additional Modules** (for user creation): MSOnline or Microsoft.Graph modules
- **Modern Authentication** enabled for tenant

### On-Premises Exchange
- **RSAT / Exchange Management Tools** on administrative workstation
- **PowerShell Remoting** access to Exchange server (`https://<exchange-server>/powershell/`)
- **Administrative Permissions**:
  - Exchange Organization Management (for mailbox operations)
  - Active Directory rights (for user creation scenarios)
- **Network Connectivity** with Kerberos authentication (recommended)

## Usage Patterns

### Bulk Mailbox Provisioning

#### Exchange Online - Existing Users
```powershell
# Create mailboxes for existing Entra ID users
.\BulkMailboxCreation.ps1 -CsvPath .\new_mailboxes.csv -Mode OnlineExisting -ConnectOnline -Verbose
```

#### Exchange Online - New Users with Licensing
```powershell
# Create users, assign licenses, and enable mailboxes
$cred = Get-Credential
$password = Read-Host "Default password" -AsSecureString
.\BulkMailboxCreation.ps1 -CsvPath .\hires.csv -Mode OnlineCreate -ConnectOnline -Credential $cred -DomainSuffix contoso.com -DefaultPassword $password -OutputCsv .\results.csv
```

#### On-Premises Exchange
```powershell
# Enable mailboxes for existing Active Directory users
.\BulkMailboxCreation.ps1 -CsvPath .\ad_users.csv -Mode OnPremExisting -ConnectOnPrem -OnPremUri https://ex01.contoso.com/powershell/ -Verbose
```

### Quota Monitoring and Reporting

#### High Usage Alerting
```powershell
# Generate alerts for mailboxes above 80% quota usage
.\MailboxQuotaReport.ps1 -ConnectOnline -MinPercentUsed 80 -OutputCsv .\quota_alerts.csv -Verbose
```

#### Departmental Analysis
```powershell
# Analyze specific department with HTML report
.\MailboxQuotaReport.ps1 -ConnectOnPrem -OnPremUri https://ex01/powershell/ -Identity "Sales*" -IncludeArchive -OutputHtml .\sales_quota_report.html
```

### Integrated Workflows

#### New Hire Complete Setup
```powershell
# Complete new hire workflow with quota validation
$hires = Import-Csv .\new_hires.csv

# Step 1: Create mailboxes
.\BulkMailboxCreation.ps1 -CsvPath .\new_hires.csv -Mode OnlineCreate -ConnectOnline -DomainSuffix contoso.com -OutputCsv .\hire_results.csv

# Step 2: Initial quota check
Start-Sleep 300  # Allow time for mailbox creation
.\MailboxQuotaReport.ps1 -ConnectOnline -Identity ($hires.UserPrincipalName -join ',') -OutputCsv .\initial_quotas.csv
```

#### Automated Daily Monitoring
```powershell
# Daily quota monitoring with automated alerting
$alertResults = .\MailboxQuotaReport.ps1 -ConnectOnline -MinPercentUsed 90 -OutputCsv ".\QuotaAlerts_$(Get-Date -Format 'yyyyMMdd').csv"

if ($alertResults.Count -gt 0) {
    $htmlReport = .\MailboxQuotaReport.ps1 -ConnectOnline -MinPercentUsed 90 -OutputHtml ".\CriticalQuotas_$(Get-Date -Format 'yyyyMMdd').html"
    # Send email alert with HTML report attachment
}
```

## CSV Format Reference

### BulkMailboxCreation Input Formats

#### Exchange Online - Existing Users
```csv
UserPrincipalName,DisplayName,PrimarySmtpAddress,Alias
john.doe@contoso.com,John Doe,john.doe@contoso.com,johndoe
jane.smith@contoso.com,Jane Smith,jane.smith@contoso.com,janesmith
```

#### Exchange Online - New Users with Licensing
```csv
UserPrincipalName,FirstName,LastName,DisplayName,LicenseSku,UsageLocation,TimeZone,Language
new.user1@contoso.com,New,User1,New User1,ENTERPRISEPACK,US,Pacific Standard Time,en-US
new.user2@contoso.com,New,User2,New User2,ENTERPRISEPACK,US,Eastern Standard Time,en-US
```

#### On-Premises Exchange
```csv
SamAccountName,UserPrincipalName,DisplayName,PrimarySmtpAddress,Alias
jdoe,john.doe@contoso.local,John Doe,john.doe@contoso.com,johndoe
jsmith,jane.smith@contoso.local,Jane Smith,jane.smith@contoso.com,janesmith
```

## Security Considerations

### Access Control
- **Least Privilege**: Scripts validate minimum required permissions for operations
- **Credential Security**: Secure handling of authentication with proper credential prompting
- **Session Management**: Proper establishment and cleanup of Exchange sessions
- **Audit Logging**: Comprehensive operation tracking for compliance requirements

### Data Protection
- **Read-Only Operations**: Quota reporting performs only read operations
- **Secure Transmission**: All Exchange communication uses encrypted channels
- **Password Handling**: Secure password management using SecureString objects
- **File Permissions**: Output files created with appropriate security contexts

### Change Management
- **Preview Capabilities**: WhatIf support for change validation before execution
- **Rollback Information**: Operations provide information for change reversal
- **Change Tracking**: Detailed audit trails support change management processes
- **Approval Workflows**: Structure supports integration with approval systems

## Best Practices

### Planning and Preparation
1. **Environment Testing**: Always test scripts in non-production environments first
2. **CSV Validation**: Validate input CSV format and data quality before execution
3. **Permission Verification**: Confirm administrative rights before bulk operations
4. **Backup Procedures**: Maintain current Exchange backups before major changes

### Execution Guidelines
1. **Phased Rollouts**: Process large operations in smaller, manageable batches
2. **Progress Monitoring**: Use verbose output and logging to track operation progress
3. **Error Handling**: Monitor for errors and have remediation procedures ready
4. **Verification Steps**: Validate results after completion of bulk operations

### Operational Excellence
1. **Scheduled Monitoring**: Implement regular quota monitoring and alerting
2. **Trend Analysis**: Maintain historical quota data for capacity planning
3. **Documentation**: Keep comprehensive documentation of all bulk operations
4. **Performance Tuning**: Optimize batch sizes based on environment performance

## Troubleshooting

### Common Issues
- **Connection Failures**: Verify network connectivity and authentication credentials
- **Permission Denied**: Check Exchange administrative role assignments
- **CSV Format Errors**: Validate CSV structure, encoding, and required columns
- **Module Dependencies**: Confirm required PowerShell modules are installed

### Diagnostic Steps
1. **Connectivity Testing**: Use Test-WSMan for PowerShell remoting validation
2. **Authentication Verification**: Test manual Exchange connections
3. **Module Validation**: Verify PowerShell module versions and availability
4. **CSV Inspection**: Review input data format and content validation

### Resolution Strategies
- **Connection Retry**: Implement retry logic for transient network failures
- **Batch Optimization**: Adjust batch sizes for large-scale operations
- **Error Isolation**: Use preview modes to identify issues before execution
- **Support Resources**: Leverage Exchange logs and documentation for troubleshooting

## Integration Notes

### Enterprise Automation
- **SCCM Integration**: Scripts can be packaged and deployed via Configuration Manager
- **Azure Automation**: Compatible with Azure Automation PowerShell runbooks
- **Scheduled Tasks**: Suitable for Windows Task Scheduler automation
- **PowerShell DSC**: Can be integrated into Desired State Configuration

### Monitoring and Alerting
- **SIEM Integration**: CSV outputs suitable for Security Information and Event Management systems
- **Dashboard Creation**: HTML reports can be published to monitoring dashboards
- **Email Automation**: Results can trigger automated email notifications
- **Metrics Collection**: Data supports operational metrics and KPI tracking

### Identity Management Integration
- **HR System Integration**: BulkMailboxCreation supports HR-driven provisioning workflows
- **Identity Governance**: Compatible with identity lifecycle management solutions
- **Compliance Reporting**: Audit trails support regulatory compliance requirements
- **Access Reviews**: Quota reports support regular access and resource reviews

### GUI Development Readiness

All scripts include comprehensive parameter validation and structured output suitable for GUI development:

#### Connection Management
- **Connection Wizards**: Parameter structure supports connection setup dialogs
- **Credential Forms**: Secure credential input with validation
- **Environment Selection**: Radio buttons for EXO vs on-premises selection
- **URI Configuration**: Text inputs with validation for on-premises URIs

#### File Operations
- **CSV File Pickers**: Browse dialogs for input and output file selection
- **Format Validation**: Real-time CSV format validation and preview
- **Template Generation**: Ability to generate CSV templates for different modes
- **Export Wizards**: Multi-format export with format selection and options

#### Operation Control
- **Mode Selection**: Radio buttons or dropdowns for operation modes
- **Parameter Forms**: Dynamic forms based on selected mode and environment
- **Preview Capabilities**: Result preview grids before execution
- **Progress Indicators**: Real-time progress bars and status updates

#### Results Management
- **Results Grids**: Sortable, filterable result displays
- **Export Options**: Multiple export format selection with options
- **Error Handling**: User-friendly error display and resolution guidance
- **Report Viewing**: Integrated HTML report viewing capabilities