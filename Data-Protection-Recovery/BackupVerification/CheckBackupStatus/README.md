# CheckBackupStatus

Comprehensive backup verification across multiple backup engines and environments with automated alerting capabilities.

## Overview

This PowerShell script provides enterprise-grade backup verification by monitoring backup success across multiple systems and backup engines. It supports both agent-based and repository-based backup validation with flexible time windows and comprehensive reporting.

## Key Features

### Multi-Engine Support
- **Windows Server Backup (WSB)**: Event log analysis and wbadmin integration
- **Veeam Agent/B&R**: Service detection and event log monitoring
- **Azure Backup (MARS)**: Microsoft Azure Recovery Services Agent verification
- **Generic Path Monitoring**: Repository freshness validation for any backup storage

### Intelligent Status Detection
- **Healthy**: Recent successful backup within the specified time window
- **Unhealthy**: Backup engine present but recent failures or insufficient activity
- **NotProtected**: No backup engine detected or configured
- **Unknown**: Unable to determine status due to permissions or connectivity issues

### Enterprise Integration
- **Remote Execution**: PowerShell remoting for centralized monitoring
- **Bulk Operations**: Monitor multiple servers simultaneously
- **Export Capabilities**: CSV and HTML reports for analysis and dashboards
- **CI/CD Integration**: Non-zero exit codes for automated alerting

## Script Parameters

### Target Configuration
- **ComputerName**: Target computers to check (supports pipeline input, defaults to local)
- **Credential**: PSCredential for remote authentication
- **Engines**: Backup engines to verify (WSB, Veeam, AzureBackup, GenericPath)

### Timing and Thresholds
- **LookbackHours**: Time window for "recent success" validation (1-168 hours, default: 26)
- **GenericMinGrowthMB**: Minimum storage growth for GenericPath health (default: 10 MB)

### Path Configuration
- **GenericPath**: Repository path for GenericPath engine validation (UNC or local paths)

### Output Options
- **OutputCsv**: CSV export path for structured data analysis
- **OutputHtml**: HTML report path with embedded styling
- **FailNonZeroExit**: Return exit code 1 for Unhealthy/NotProtected status (scheduler integration)

## Usage Examples

### Windows Server Backup Monitoring
```powershell
# Monitor WSB on multiple file servers with CSV export
.\CheckBackupStatus.ps1 -ComputerName FS01,FS02,FS03 -Engines WSB -LookbackHours 26 -OutputCsv .\wsb_status.csv -Verbose
```

### Multi-Engine Fleet Monitoring
```powershell
# Comprehensive backup verification across server fleet
$servers = Get-Content .\server_list.txt
.\CheckBackupStatus.ps1 -ComputerName $servers -Engines Veeam,AzureBackup -OutputHtml .\backup_dashboard.html -FailNonZeroExit
```

### Repository Freshness Validation
```powershell
# Validate NAS backup repository activity with high growth threshold
.\CheckBackupStatus.ps1 -ComputerName BKP-PROXY -Engines GenericPath -GenericPath "\\nas01\backups\critical_apps" -GenericMinGrowthMB 500 -LookbackHours 24
```

### Automated Daily Monitoring
```powershell
# Daily backup verification with email alerting
$results = .\CheckBackupStatus.ps1 -ComputerName (Get-ADComputer -Filter "OperatingSystem -like '*Server*'").Name -Engines WSB,Veeam -OutputCsv ".\BackupStatus_$(Get-Date -Format 'yyyyMMdd').csv" -FailNonZeroExit

if ($LASTEXITCODE -eq 1) {
    # Generate detailed HTML report for failures
    .\CheckBackupStatus.ps1 -ComputerName $failedServers -Engines WSB,Veeam -OutputHtml .\backup_failures.html
    Send-MailMessage -To "admin@company.com" -Subject "Backup Verification Failures" -Body "See attached report" -Attachments .\backup_failures.html
}
```

### Credential-Based Remote Monitoring
```powershell
# Monitor domain servers with specific credentials
$cred = Get-Credential domain\backupmonitor
.\CheckBackupStatus.ps1 -ComputerName (Get-ADComputer -Filter "Name -like 'SRV*'").Name -Credential $cred -Engines WSB,Veeam,AzureBackup -OutputHtml .\domain_backup_status.html
```

## Engine-Specific Detection Logic

### Windows Server Backup (WSB)
- **Success Detection**: Event ID 4 in Microsoft-Windows-Backup log within time window
- **Failure Detection**: Event IDs 5, 9, 546, 547 indicating backup failures
- **Validation**: Optional wbadmin version check for additional verification
- **Status Logic**: Healthy if recent success, Unhealthy if recent errors, NotProtected if no events

### Veeam Agent/B&R
- **Service Detection**: Presence of Veeam services (names starting with "Veeam")
- **Success Events**: Application log events from Veeam providers with "succeeded" or "completed" messages
- **Error Events**: Warning/Error level events with failure indicators
- **Status Logic**: Healthy if recent success, Unhealthy if service present but errors, NotProtected if no services

### Azure Backup (MARS)
- **Service Detection**: OBEngine service presence indicating MARS agent installation
- **Event Sources**: Azure Backup and OBEngine providers in Application log
- **Success Pattern**: Events containing "completed" or "succeeded" messages
- **Status Logic**: Similar to Veeam with service-based NotProtected detection

### GenericPath
- **File System Analysis**: Recursive enumeration of target directory
- **Growth Calculation**: Sum of file sizes for files modified within time window
- **Threshold Validation**: Compare growth against minimum required MB
- **Status Logic**: Healthy if growth exceeds threshold, Unhealthy if insufficient, NotProtected if no files

## Output Formats

### Console Output
Formatted table displaying:
- **ComputerName**: Target system name
- **Engine**: Backup engine type
- **LastSuccessUtc**: Most recent successful backup timestamp (UTC)
- **LastErrorUtc**: Most recent error timestamp (UTC)
- **Status**: Health status (Healthy/Unhealthy/NotProtected/Unknown)
- **Note**: Additional details or error messages

### CSV Export
Structured data export including all console columns with UTF-8 encoding for:
- Data analysis in Excel or Power BI
- Import into monitoring systems
- Historical trending and compliance reporting
- Automated processing by other scripts

### HTML Report
Professional formatted report featuring:
- Embedded CSS for standalone viewing
- Responsive table design
- Color-coded status indicators
- Generation timestamp and metadata
- Sort capabilities for interactive analysis

## Error Handling and Resilience

### Connection Management
- **Remote Execution**: Robust PowerShell remoting with error isolation
- **Authentication**: Secure credential handling with fallback prompting
- **Individual Failures**: Single computer failures don't stop batch processing
- **Timeout Handling**: Graceful handling of network timeouts and connectivity issues

### Permission Validation
- **Event Log Access**: Validates read permissions to required event logs
- **Service Queries**: Handles insufficient privileges for service enumeration
- **File System Access**: Graceful handling of path access denials
- **Fallback Reporting**: Clear error messages when operations fail

### Data Integrity
- **Null Handling**: Proper handling of missing timestamps and data
- **Date Conversion**: Safe UTC conversion with error handling
- **Export Validation**: Validates export operations and reports failures
- **Status Consistency**: Consistent status determination across all engines

## Prerequisites

### System Requirements
- **PowerShell 3.0+**: Required for advanced cmdlets and remoting features
- **WinRM Configuration**: PowerShell remoting enabled for remote monitoring
- **Administrative Rights**: Local admin or specific permissions for event log access
- **Network Connectivity**: Direct network access between monitoring and target systems

### Permission Requirements
- **Event Log Reader**: Read access to Application and Microsoft-Windows-Backup logs
- **Service Query**: Permission to enumerate and query service status
- **File System Access**: Read access to backup repository paths (GenericPath engine)
- **WMI Access**: Basic WMI query permissions for system information

### Backup Engine Dependencies
- **WSB**: Windows Server Backup feature installed and configured
- **Veeam**: Veeam Agent or Backup & Replication components installed
- **Azure Backup**: Microsoft Azure Recovery Services (MARS) agent installed
- **GenericPath**: Network or local access to backup storage locations

## Performance Considerations

### Scalability Optimization
- **Parallel Execution**: PowerShell remoting enables concurrent target processing
- **Efficient Event Queries**: Targeted event log queries with time-based filtering
- **Minimal Data Transfer**: Only essential data returned from remote systems
- **Connection Reuse**: Single remote session per target computer

### Resource Management
- **Memory Efficiency**: Streaming results processing without large object accumulation
- **CPU Optimization**: Lightweight detection logic minimizing system impact
- **Network Bandwidth**: Minimal network overhead with compressed PowerShell remoting
- **Storage Access**: Optimized file system enumeration for GenericPath validation

## Security Considerations

### Authentication and Authorization
- **Credential Security**: Secure credential prompting and storage
- **Least Privilege**: Operates with minimum required permissions
- **Session Management**: Proper cleanup of PowerShell remote sessions
- **Audit Compliance**: Read-only operations suitable for compliance environments

### Data Protection
- **No Sensitive Data**: Script doesn't access or store sensitive backup data
- **Encrypted Communication**: PowerShell remoting uses encrypted channels
- **Local File Security**: Output files created with appropriate permissions
- **Log Privacy**: Event log data handling respects organizational privacy policies

## Integration Scenarios

### Monitoring System Integration
- **SIEM Compatibility**: CSV outputs suitable for SIEM ingestion and alerting
- **Dashboard Integration**: HTML reports can be hosted on monitoring dashboards
- **Metrics Collection**: Status data supports operational metrics and KPI tracking
- **Alert Triggering**: Exit codes enable automated alert generation

### Automation Platform Integration
- **Task Scheduler**: Windows Task Scheduler for automated daily/weekly monitoring
- **Azure Automation**: Compatible with Azure Automation PowerShell runbooks
- **SCCM Integration**: Can be packaged and deployed via System Center Configuration Manager
- **PowerShell Jobs**: Suitable for background job execution in large environments

### Change Management Integration
- **Approval Workflows**: Results can trigger change management processes
- **Compliance Reporting**: Regular execution supports compliance auditing
- **Trend Analysis**: Historical data enables backup infrastructure trend analysis
- **Capacity Planning**: Repository growth data supports storage capacity planning

## Troubleshooting

### Common Issues
- **WinRM Connection Failures**: Verify PowerShell remoting configuration and firewall rules
- **Event Log Access Denied**: Check user permissions for event log reading
- **Service Query Failures**: Validate administrative rights on target systems
- **Path Access Issues**: Confirm network connectivity and share permissions for GenericPath

### Diagnostic Steps
1. **Connectivity Testing**: Use `Test-WSMan` to verify PowerShell remoting
2. **Permission Validation**: Test manual event log access on target systems
3. **Service Verification**: Confirm backup services are installed and running
4. **Path Validation**: Verify file system access to backup repositories

### Resolution Strategies
- **Credential Refresh**: Update stored credentials and re-authenticate
- **Permission Escalation**: Ensure monitoring account has required privileges
- **Network Troubleshooting**: Validate firewall rules and network connectivity
- **Configuration Review**: Verify backup engine installation and configuration

## Advanced Configuration

### Custom Event Filtering
The script can be customized for specific backup engine versions by modifying:
- Event provider names for different Veeam versions
- Event ID ranges for custom backup solutions
- Message pattern matching for localized environments
- Success/failure criteria based on organizational standards

### Threshold Tuning
Adjust detection thresholds based on organizational requirements:
- Extend or reduce LookbackHours based on backup schedules
- Modify GenericMinGrowthMB based on expected backup sizes
- Customize status determination logic for specific environments
- Add additional health checks for comprehensive validation

### Integration Customization
Extend the script for specific organizational needs:
- Add custom notification methods (Teams, Slack, email)
- Integrate with existing monitoring and alerting systems
- Customize HTML report styling and branding
- Add additional export formats (JSON, XML) for specific consumers

## GUI Development Readiness

The script architecture fully supports GUI development with:

### Parameter Management
- **Engine Selection**: Checkbox interface for multiple engine selection
- **Time Window Control**: Slider or numeric input for LookbackHours
- **Path Browser**: Folder picker dialog for GenericPath configuration
- **Target Management**: Computer picker with AD integration and bulk import

### Execution Control
- **Credential Manager**: Secure credential input and storage
- **Progress Monitoring**: Real-time progress bars and status updates
- **Result Filtering**: Interactive filtering and sorting of results
- **Export Options**: Save dialog with multiple format options

### Results Display
- **Status Dashboard**: Visual status indicators with color coding
- **Detailed Views**: Drill-down capabilities for individual engine results
- **Historical Trends**: Integration points for historical data visualization
- **Alert Configuration**: GUI-based alert threshold and notification setup