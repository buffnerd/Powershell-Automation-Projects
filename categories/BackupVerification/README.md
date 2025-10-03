# Backup Verification

Enterprise-grade PowerShell scripts for **backup validation and integrity verification** across multiple backup engines and storage systems.

## Category Overview

This category provides comprehensive backup verification capabilities to ensure business continuity through proactive backup monitoring. Scripts support multiple backup engines, repository types, and verification methods with automated alerting and enterprise integration.

## Scripts in this Category

### [CheckBackupStatus](./CheckBackupStatus/)
**Multi-engine backup verification with automated alerting**
- **Purpose**: Verify recent backup success across multiple backup engines and systems
- **Engines**: WSB (Windows Server Backup), Veeam Agent/B&R, Azure Backup (MARS), Generic repository monitoring
- **Key Features**: Remote execution, time-window validation, CSV/HTML exports, CI/CD integration
- **Use Cases**: Daily backup validation, compliance monitoring, automated alerting, dashboard integration

### [Restore-AD](./Restore-AD/)
**Active Directory backup and restore automation**
- **Purpose**: Automated Active Directory backup verification and restore testing
- **Key Features**: System state validation, authoritative restore capabilities, forest recovery procedures
- **Safety**: Non-destructive testing modes, comprehensive validation, rollback procedures
- **Use Cases**: DR testing, compliance validation, system state verification, forest recovery planning

### [Restore-SQL](./Restore-SQL/)
**SQL Server backup validation and restore testing**
- **Purpose**: Automated SQL Server backup integrity checking and restore validation
- **Key Features**: Database consistency checks, backup chain validation, point-in-time recovery testing
- **Safety**: Isolated test environments, non-production restore validation, integrity verification
- **Use Cases**: Backup integrity validation, DR testing, compliance verification, RTO/RPO validation

## Common Features

### Multi-Engine Support
- **Native Backup Solutions**: Windows Server Backup, SQL Server native backups
- **Enterprise Backup Solutions**: Veeam Backup & Replication, Azure Backup (MARS)
- **Repository Monitoring**: Generic file system growth validation for any backup storage
- **Hybrid Environments**: Support for cloud and on-premises backup verification

### Verification Methods
- **Event Log Analysis**: Windows event log parsing for backup success/failure detection
- **Service Monitoring**: Backup service health and status verification
- **Repository Validation**: File system analysis for backup completion and integrity
- **Application-Specific**: Database consistency checks and application-aware validation

### Enterprise Integration
- **Remote Execution**: PowerShell remoting for centralized monitoring across multiple systems
- **Automated Alerting**: Exit codes and status reporting for integration with monitoring systems
- **Comprehensive Reporting**: Multiple export formats (CSV, HTML) for dashboards and compliance
- **Scheduling Support**: Designed for automated execution via Task Scheduler or CI/CD systems

## Prerequisites

### System Requirements
- **PowerShell 3.0+**: Required for advanced cmdlets and remoting capabilities
- **WinRM Configuration**: PowerShell remoting enabled for remote backup verification
- **Administrative Access**: Local administrator rights or specific backup-related permissions
- **Network Connectivity**: Direct network access between monitoring and target systems

### Backup System Dependencies
- **Windows Server Backup**: WSB feature installed and configured on target systems
- **Veeam Components**: Veeam Agent or Backup & Replication components as applicable
- **Azure Backup**: Microsoft Azure Recovery Services (MARS) agent for cloud backups
- **SQL Server**: SQL Server instances with backup history for database verification

### Permission Requirements
- **Event Log Access**: Read permissions for Application and backup-specific event logs
- **Service Query Rights**: Permission to enumerate and query backup service status
- **File System Access**: Read access to backup repositories and storage locations
- **Database Access**: Appropriate SQL Server permissions for backup validation (Restore-SQL)

## Usage Patterns

### Daily Backup Validation
```powershell
# Comprehensive daily backup verification across server fleet
$servers = Get-ADComputer -Filter "OperatingSystem -like '*Server*'" | Select-Object -ExpandProperty Name
.\CheckBackupStatus.ps1 -ComputerName $servers -Engines WSB,Veeam,AzureBackup -LookbackHours 26 -OutputCsv ".\DailyBackupStatus_$(Get-Date -Format 'yyyyMMdd').csv" -FailNonZeroExit
```

### Automated Alerting Workflow
```powershell
# Daily monitoring with automated email alerts for failures
$results = .\CheckBackupStatus.ps1 -ComputerName (Get-Content .\critical_servers.txt) -Engines WSB,Veeam -OutputHtml .\backup_status.html -FailNonZeroExit

if ($LASTEXITCODE -eq 1) {
    # Generate detailed failure report
    $failureReport = .\CheckBackupStatus.ps1 -ComputerName $failedServers -Engines WSB,Veeam -OutputHtml .\backup_failures_detailed.html
    
    # Send alert with detailed report
    Send-MailMessage -To "backup-admins@company.com" -Subject "ALERT: Backup Verification Failures Detected" -Body "Critical backup failures detected. See attached report for details." -Attachments .\backup_failures_detailed.html -SmtpServer mail.company.com
}
```

### Repository Health Monitoring
```powershell
# Monitor backup repository growth and health
$repositories = @(
    @{Path="\\nas01\backups\finance"; MinGrowth=200},
    @{Path="\\nas01\backups\hr"; MinGrowth=50},
    @{Path="\\nas02\backups\engineering"; MinGrowth=1000}
)

foreach ($repo in $repositories) {
    .\CheckBackupStatus.ps1 -ComputerName backup-proxy01 -Engines GenericPath -GenericPath $repo.Path -GenericMinGrowthMB $repo.MinGrowth -OutputCsv ".\RepoHealth_$(Split-Path $repo.Path -Leaf)_$(Get-Date -Format 'yyyyMMdd').csv"
}
```

### Compliance Reporting
```powershell
# Weekly compliance report generation
$complianceResults = .\CheckBackupStatus.ps1 -ComputerName (Get-Content .\compliance_servers.txt) -Engines WSB,Veeam,AzureBackup -LookbackHours 168 -OutputHtml ".\WeeklyComplianceReport_$(Get-Date -Format 'yyyyMMdd').html"

# Generate executive summary
$summary = $complianceResults | Group-Object Status | Select-Object Name, Count
$summary | Export-Csv ".\ComplianceSummary_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
```

## Security Considerations

### Access Control
- **Least Privilege**: Scripts operate with minimum required permissions for backup validation
- **Credential Security**: Secure credential handling with encrypted storage and transmission
- **Audit Compliance**: Read-only operations suitable for regulated environments
- **Session Management**: Proper cleanup of remote sessions and temporary data

### Data Protection
- **No Backup Data Access**: Scripts validate backup completion without accessing backup content
- **Encrypted Communication**: All remote operations use encrypted PowerShell remoting
- **Local File Security**: Output files created with appropriate file system permissions
- **Privacy Compliance**: Event log analysis respects organizational privacy policies

## Best Practices

### Implementation Strategy
1. **Phased Deployment**: Start with non-critical systems and expand to production gradually
2. **Baseline Establishment**: Collect baseline metrics before implementing alerting thresholds
3. **Integration Planning**: Design integration with existing monitoring and alerting systems
4. **Documentation**: Maintain comprehensive documentation of validation procedures and thresholds

### Operational Excellence
1. **Regular Testing**: Perform periodic restore testing to validate backup integrity
2. **Threshold Tuning**: Regularly review and adjust validation thresholds based on environment changes
3. **Alert Optimization**: Fine-tune alerting to reduce false positives while maintaining sensitivity
4. **Performance Monitoring**: Monitor script execution performance and optimize for large environments

## Integration Notes

### Monitoring System Integration
- **SIEM Compatibility**: CSV outputs integrate with Security Information and Event Management systems
- **Dashboard Creation**: HTML reports can be published to monitoring dashboards and portals
- **Metrics Collection**: Validation data supports operational metrics and Key Performance Indicators
- **Alert Automation**: Exit codes enable integration with automated alerting and escalation systems

### GUI Development Readiness
All scripts include comprehensive parameter validation and structured output suitable for GUI development:
- **Status Dashboard**: Visual backup status indicators with real-time updates
- **Configuration Management**: Threshold and path configuration interfaces
- **Reporting Analysis**: Interactive results with export and visualization capabilities
- **Alert Management**: GUI-based alert configuration and notification setup