# MailboxQuotaReport

Comprehensive mailbox quota analysis and reporting for Exchange Online and on-premises Exchange environments.

## Overview

This PowerShell script provides detailed mailbox quota reporting with threshold analysis, archive statistics, and multiple export formats. It supports both Exchange Online and on-premises Exchange environments with flexible filtering and comprehensive quota calculations.

## Key Features

### Quota Analysis
- **Size vs Quota Comparison**: Calculate percentage used against ProhibitSendReceiveQuota
- **Multiple Quota Thresholds**: Track IssueWarning, ProhibitSend, and ProhibitSendReceive quotas
- **Item Count Statistics**: Include total item counts alongside size metrics
- **Threshold Filtering**: Show only mailboxes exceeding specified usage percentages

### Archive Mailbox Support
- **Archive Statistics**: Include archive mailbox sizes and item counts
- **Combined Reporting**: View primary and archive data in unified reports
- **Archive Status Tracking**: Identify which mailboxes have archive enabled
- **Optional Inclusion**: Toggle archive data collection for performance

### Multi-Format Output
- **Console Display**: Formatted table output with sorting by usage percentage
- **CSV Export**: Structured data export for further analysis and automation
- **HTML Reports**: Professional-formatted reports with embedded styling
- **Audit Trails**: Timestamped reports suitable for compliance documentation

## Script Parameters

### Connection Parameters
- **ConnectOnline**: Connect to Exchange Online using EXO V3 module
- **ConnectOnPrem**: Connect to on-premises Exchange via PowerShell remoting
- **OnPremUri**: Exchange server PowerShell URI for on-premises connections
- **Credential**: PSCredential for authenticated connections (prompts if not provided)

### Filtering and Scope
- **Identity**: Optional mailbox identity filter supporting wildcards (e.g., "Sales*")
- **MinPercentUsed**: Threshold filter to show only mailboxes above specified usage percentage (0-100)
- **IncludeArchive**: Include archive mailbox statistics in the report

### Output Options
- **OutputCsv**: Export results to CSV file for data analysis
- **OutputHtml**: Generate formatted HTML report with embedded styling

## Usage Examples

### Exchange Online - High Usage Analysis
```powershell
# Show mailboxes at or above 80% quota usage with CSV export
.\MailboxQuotaReport.ps1 -ConnectOnline -MinPercentUsed 80 -OutputCsv .\high_usage_mailboxes.csv -Verbose
```

### On-Premises Exchange - Department Analysis
```powershell
# Report on Sales department mailboxes with HTML output
.\MailboxQuotaReport.ps1 -ConnectOnPrem -OnPremUri https://ex01.contoso.com/powershell/ -Identity "Sales*" -OutputHtml .\sales_quota_report.html
```

### Complete Archive Analysis
```powershell
# Comprehensive report including archive statistics
$cred = Get-Credential
.\MailboxQuotaReport.ps1 -ConnectOnline -Credential $cred -IncludeArchive -MinPercentUsed 50 -OutputCsv .\complete_quota_analysis.csv -OutputHtml .\quota_dashboard.html
```

### Automated Monitoring
```powershell
# Daily automated quota monitoring with alerting
$results = .\MailboxQuotaReport.ps1 -ConnectOnline -MinPercentUsed 90 -OutputCsv ".\QuotaAlerts_$(Get-Date -Format 'yyyyMMdd').csv"
if ($results.Count -gt 0) {
    # Trigger alerting system
    Send-MailMessage -To "admin@contoso.com" -Subject "Mailbox Quota Alert" -Body "$(($results).Count) mailboxes above 90% quota usage"
}
```

### Bulk Department Analysis
```powershell
# Analyze multiple departments with separate reports
$departments = @('Sales', 'Marketing', 'Engineering', 'Finance')
foreach ($dept in $departments) {
    .\MailboxQuotaReport.ps1 -ConnectOnPrem -OnPremUri https://ex01/powershell/ -Identity "$dept*" -OutputHtml ".\Reports\$dept`_quota_report.html" -MinPercentUsed 70
}
```

## Report Output Structure

### Console Output
The script displays a formatted table sorted by quota usage percentage (highest first) with the following columns:
- **DisplayName**: User's display name
- **PrimarySmtp**: Primary email address
- **ItemCount**: Total number of items in mailbox
- **TotalSize**: Current mailbox size in Exchange format
- **ProhibitSend**: Quota at which sending is prohibited
- **ProhibitSR**: Quota at which sending and receiving are prohibited
- **IssueWarning**: Quota at which warnings are issued
- **PercentUsed**: Calculated percentage against ProhibitSendReceiveQuota
- **ArchiveItems**: Archive item count (if IncludeArchive is enabled)
- **ArchiveSize**: Archive size (if IncludeArchive is enabled)

### CSV Export Format
CSV exports include all report columns with UTF-8 encoding for international character support. The format is suitable for:
- Data analysis in Excel or Power BI
- Import into monitoring and alerting systems
- Automated processing by other scripts
- Compliance and audit trail documentation

### HTML Report Features
HTML reports include:
- Professional styling with responsive design
- Sortable columns for interactive analysis
- Color-coded rows for high-usage mailboxes
- Embedded CSS for standalone viewing
- Generation timestamp for audit purposes
- Summary statistics and trend indicators

## Quota Calculation Details

### Size Conversion
The script includes robust size conversion logic that handles Exchange's standard size format:
- **Parse Exchange Format**: Extracts byte values from "123.4 MB (129,555,555 bytes)" format
- **Fallback Handling**: Gracefully handles various size representations
- **Numeric Precision**: Maintains accuracy for large mailbox sizes
- **Error Tolerance**: Returns zero for unparseable size values

### Percentage Calculations
- **Primary Metric**: Uses ProhibitSendReceiveQuota as the primary quota threshold
- **Precision**: Rounds to one decimal place for readability
- **Zero Handling**: Gracefully handles unlimited or zero quotas
- **Error States**: Identifies calculation errors with -1 values

### Archive Integration
When archive statistics are included:
- **Separate Tracking**: Archive data is reported alongside primary mailbox data
- **Optional Collection**: Archive data collection can be disabled for performance
- **Status Awareness**: Only attempts archive statistics for enabled archives
- **Error Handling**: Gracefully handles archive access failures

## Prerequisites

### Exchange Online Requirements
- **PowerShell 5.1+** or **PowerShell 7+**
- **ExchangeOnlineManagement** module (V3 recommended)
- **Exchange View-Only Administrator** role (minimum for read operations)
- **Modern Authentication** enabled for the tenant

### On-Premises Exchange Requirements
- **Exchange Management Tools** installed on administrative workstation
- **PowerShell Remoting** access to Exchange server
- **Exchange View-Only Organization Management** role (minimum)
- **Network Connectivity** to Exchange server PowerShell endpoint

## Performance Considerations

### Large Environment Optimization
- **ResultSize Management**: Uses -ResultSize Unlimited but considers chunking for very large environments
- **Archive Toggle**: Use -IncludeArchive selectively as it doubles the Exchange calls
- **Identity Filtering**: Use specific identity filters to reduce scope when possible
- **Connection Reuse**: Maintains single connection throughout script execution

### Memory Management
- **Streaming Output**: Results are processed and output incrementally
- **Generic Collections**: Uses efficient List<Object> for result accumulation
- **Disposal Patterns**: Properly cleans up Exchange sessions and objects
- **Error Isolation**: Individual mailbox failures don't impact overall processing

## Error Handling

### Connection Resilience
- **Authentication Validation**: Validates credentials and permissions before processing
- **Session Management**: Properly establishes and maintains Exchange connections
- **Timeout Handling**: Handles network timeouts and connection interruptions
- **Retry Logic**: Implements basic retry for transient failures

### Data Validation
- **Quota Parsing**: Robust parsing of various quota format representations
- **Size Calculation**: Safe numeric conversions with error handling
- **Archive Availability**: Graceful handling of archive access issues
- **Permission Errors**: Clear error messages for insufficient permissions

### Result Integrity
- **Partial Success**: Continues processing even if individual mailboxes fail
- **Error Tracking**: Records specific error messages for failed operations
- **Data Completeness**: Identifies incomplete data with null/error indicators
- **Export Validation**: Validates export operations and reports failures

## Security Considerations

### Credential Management
- **Secure Prompting**: Uses Get-Credential when credentials aren't provided
- **Session Security**: Leverages Exchange's secure authentication mechanisms
- **Permission Validation**: Operates with minimum required permissions
- **Audit Compliance**: Generates audit trails suitable for compliance requirements

### Data Protection
- **Read-Only Operations**: Script performs only read operations on Exchange data
- **Secure Transmission**: All Exchange communication uses encrypted channels
- **Local Storage**: Output files are created with appropriate file permissions
- **Sensitive Data**: No passwords or sensitive data are stored in outputs

## Integration Notes

### Monitoring Systems
- **SIEM Integration**: CSV outputs are suitable for SIEM ingestion
- **Dashboard Creation**: HTML reports can be hosted for dashboard viewing
- **Alerting Integration**: Results can trigger automated alerting systems
- **Trend Analysis**: Regular execution supports quota usage trend analysis

### Automation Platforms
- **Scheduled Tasks**: Suitable for Windows Task Scheduler automation
- **PowerShell Jobs**: Can be executed as background jobs for large environments
- **Azure Automation**: Compatible with Azure Automation PowerShell runbooks
- **SCCM Integration**: Can be packaged and deployed via System Center

### Reporting Infrastructure
- **Power BI Integration**: CSV exports work directly with Power BI data sources
- **Excel Analysis**: Results are Excel-compatible for pivot table analysis
- **SharePoint Storage**: HTML reports can be published to SharePoint sites
- **Email Distribution**: Reports can be automatically distributed via email

### GUI Development Readiness
The script architecture supports GUI development with:
- **Parameter Validation**: Comprehensive parameter validation for form inputs
- **Progress Tracking**: Structure supports progress bar implementation
- **Result Filtering**: Built-in filtering suitable for GUI result grids
- **Export Options**: Multiple export formats for GUI save dialogs
- **Connection Management**: Credential handling suitable for GUI credential forms