# MonitorCriticalServices

## Overview
Continuous or one-shot monitoring of critical Windows services across multiple computers with comprehensive health validation and reporting capabilities.

## Scripts
- **MonitorCriticalServices.ps1** - Main script for monitoring service health with configurable validation criteria

## Key Features
- **Flexible Monitoring Modes**: One-shot or continuous monitoring with configurable intervals
- **Comprehensive Health Checks**: Service status, startup type, and dependency validation
- **Multi-Computer Support**: Monitor service health across entire server fleets
- **Scheduler Friendly**: Exit codes and CSV logging for integration with monitoring systems
- **Dependency Validation**: Optional verification that required dependent services are running
- **Startup Type Validation**: Ensure services are configured for automatic startup
- **Real-time Reporting**: Console output with CSV logging for dashboard integration

## Environment Customization
- **Target Selection**: Computer picker with list/file/AD OU integration for GUI
- **Service Selection**: Multi-select control with validation for GUI
- **Monitoring Mode**: Toggle between one-shot and continuous with duration controls
- **Validation Options**: Checkboxes for startup type and dependency checking
- **Export Configuration**: File save dialog for CSV output path

## Usage Examples

### One-Shot Health Check with Startup Validation
```powershell
.\MonitorCriticalServices.ps1 -ComputerName app01,app02 `
  -Services 'W3SVC','Schedule' -RequireAutomaticStart -Verbose
```

### Continuous Monitoring with CSV Logging
```powershell
.\MonitorCriticalServices.ps1 -ComputerName (Get-Content .\servers.txt) `
  -Services 'Spooler','LanmanServer' -CheckDependencies `
  -DurationSeconds 900 -IntervalSeconds 60 -OutputCsv .\svc_health.csv
```

### Pipeline Integration with Exit Codes
```powershell
.\MonitorCriticalServices.ps1 -ComputerName web01,web02 `
  -Services 'W3SVC','WAS' -RequireAutomaticStart -FailNonZeroExit
if ($LASTEXITCODE -eq 1) { Send-Alert "Web services are down!" }
```

### Cross-Domain Monitoring
```powershell
$cred = Get-Credential
.\MonitorCriticalServices.ps1 -ComputerName dc01,dc02 `
  -Services 'NTDS','DNS','Netlogon' -Credential $cred `
  -CheckDependencies -RequireAutomaticStart -Verbose
```

### Scheduled Task Integration
```powershell
# Task Scheduler command line for automated monitoring
.\MonitorCriticalServices.ps1 -ComputerName (Get-Content C:\Scripts\CriticalServers.txt) `
  -Services 'W3SVC','MSSQLSERVER','Spooler' -RequireAutomaticStart `
  -FailNonZeroExit -OutputCsv C:\Logs\ServiceHealth.csv
```

## Parameters
- **ComputerName**: Target computer(s), defaults to local machine
- **Services**: Array of service names (ServiceName, not DisplayName)
- **Credential**: PSCredential for cross-domain/workgroup authentication
- **RequireAutomaticStart**: Validate services are set to Automatic startup
- **CheckDependencies**: Verify required dependent services are running
- **IntervalSeconds**: Polling interval for continuous mode (5-3600 seconds)
- **DurationSeconds**: Total monitoring duration, 0 for one-shot (0-86400 seconds)
- **OutputCsv**: Path for CSV export with timestamped results
- **FailNonZeroExit**: Exit with code 1 if any service is unhealthy

## Health Validation Criteria

### Service Status
- **Running**: Service is actively running
- **Stopped/Other**: Service is not in running state (unhealthy)

### Startup Type Validation (Optional)
- **Automatic**: Standard automatic startup
- **Automatic (Delayed Start)**: Delayed automatic startup
- **Manual/Disabled**: Non-automatic startup (fails validation)

### Dependency Validation (Optional)
- **Healthy Dependencies**: All required services are running
- **Broken Dependencies**: One or more dependencies are stopped/unknown

### Overall Health
Healthy = Running AND (AutoCompliant OR not required) AND (No dependency issues OR not checked)

## Monitoring Modes

### One-Shot Mode (Default)
- **DurationSeconds**: 0 (default)
- **Behavior**: Check once and exit
- **Use Cases**: Manual checks, scheduled tasks, pipeline validation

### Continuous Mode
- **DurationSeconds**: > 0
- **Behavior**: Poll at specified intervals for the duration
- **Use Cases**: Real-time monitoring, dashboard feeds, alerting systems

## Common Use Cases
1. **Infrastructure Monitoring** - Monitor critical services across server infrastructure
2. **Application Health Checks** - Validate application service dependencies
3. **Scheduled Validation** - Regular health checks via Windows Task Scheduler
4. **Pipeline Integration** - Service validation in CI/CD pipelines
5. **Incident Response** - Quick health assessment during outages
6. **Compliance Reporting** - Startup type validation for security compliance

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- PowerShell Remoting (WinRM) enabled on target computers
- Permissions to query services remotely
- Network connectivity and DNS resolution to targets
- For startup type checks: WMI/CIM access

## Output Format

### Console Output
Displays table with:
- **ComputerName**: Target computer
- **ServiceName**: Service name
- **Status**: Current service status
- **StartupType**: Service startup configuration
- **AutoCompliant**: Startup type validation result
- **DependencyIssues**: Dependency problems (if any)
- **Healthy**: Overall health status
- **CheckedAt**: Timestamp of check

### CSV Export
All console fields plus:
- **DisplayName**: Service display name
- **RequiresAuto**: Whether automatic startup is required
- **Additional metadata** for dashboard integration

## Integration with Monitoring Systems

### SIEM Integration
- CSV format compatible with log ingestion
- Structured data for alerting rules
- Timestamp correlation for event analysis

### Dashboard Integration
- Real-time health status feeds
- Historical trend analysis
- Service availability reporting

### Alerting Systems
- Exit code integration for pipeline triggers
- CSV parsing for email/Teams/Slack notifications
- Threshold-based alerting on service counts

## Performance Considerations
- WMI queries add overhead for startup type validation
- Remote service queries scale with computer count
- Continuous mode maintains persistent connections
- CSV appending suitable for long-running monitoring
- Network timeouts may affect large-scale monitoring

## Error Handling
- Individual computer failures don't stop monitoring
- Service query errors recorded as 'Unknown' status
- Graceful handling of authentication failures
- Comprehensive error logging in results
- Non-terminating errors for batch operations

## Security Considerations
- Uses PowerShell remoting for secure remote execution
- Credentials handled through secure PowerShell objects
- Read-only service queries minimize security risk
- WMI access follows standard Windows security model
- Audit trails through CSV logging

## Best Practices
1. **Service Catalogs**: Maintain documented lists of critical services per application
2. **Scheduled Monitoring**: Use Task Scheduler for regular health checks
3. **Alerting Integration**: Parse CSV results for automated notifications
4. **Credential Management**: Use service accounts for automated monitoring
5. **Network Optimization**: Group monitoring by network segments
6. **Documentation**: Document service dependencies and startup requirements