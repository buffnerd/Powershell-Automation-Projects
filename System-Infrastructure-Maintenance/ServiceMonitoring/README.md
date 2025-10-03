# Service Monitoring

Scripts to **monitor** and **remediate** Windows services across servers and workstations. Designed for helpdesk/ops/engineering teams that need reliable, auditable controls. All inputs are parameterized for easy future GUI integration.

---

## Prerequisites
- PowerShell Remoting (WinRM) enabled on target machines
- Permissions to query and manage services remotely
- Reliable DNS and network connectivity to targets

---

## Scripts

### 1) MonitorCriticalServices.ps1
Continuously (or one-shot) checks that critical services are **Running**, optionally that they're **Automatic**, and optionally that **dependencies** are healthy. Outputs a table and can append to a CSV for dashboards.

**Examples**
```powershell
# One-shot check with StartupType requirement
.\MonitorCriticalServices.ps1 -ComputerName app01,app02 -Services 'W3SVC','Schedule' -RequireAutomaticStart -Verbose

# 15-minute loop every 60s, checking dependencies and logging to CSV
.\MonitorCriticalServices.ps1 -ComputerName (gc .\servers.txt) -Services 'Spooler','LanmanServer' `
  -CheckDependencies -DurationSeconds 900 -IntervalSeconds 60 -OutputCsv .\svc_health.csv
```

**Adjust for your environment**
- Target list: `-ComputerName` (array or file)
- Service names: `-Services`
- StartupType requirement: `-RequireAutomaticStart`
- Dependency checks: `-CheckDependencies`
- Loop knobs: `-IntervalSeconds`, `-DurationSeconds`
- CSV path: `-OutputCsv`
- Credentials: `-Credential`

### 2) RestartServices.ps1
Safely **Restart**, **Start**, or **Stop** services at scale with timeouts, retries, dependency handling, and post-validation.

**Examples**
```powershell
# Restart IIS and Task Scheduler with validation
.\RestartServices.ps1 -ComputerName web01,web02 -Services 'W3SVC','Schedule' -ValidateAfter -Verbose

# Stop Spooler with longer timeout and extra retries
.\RestartServices.ps1 -ComputerName (gc .\print-servers.txt) -Services 'Spooler' -Action Stop -RetryCount 2 -TimeoutSeconds 120 -Verbose
```

**Adjust for your environment**
- Targets: `-ComputerName`
- Services: `-Services`
- Operation: `-Action` (Restart/Stop/Start)
- Timeouts/retries: `-TimeoutSeconds`, `-RetryCount`
- Dependencies: `-RestartDependencies`
- Validation: `-ValidateAfter`
- CSV output: `-OutputCsv`
- Credentials: `-Credential`

---

## Common Workflows

### Proactive Service Monitoring
1. **Define Critical Services**: Identify essential services for each application/role
2. **Continuous Monitoring**: Set up scheduled monitoring with CSV logging
3. **Alerting Integration**: Parse CSV results for automated notifications
4. **Dashboard Creation**: Feed monitoring data to operational dashboards
5. **Trend Analysis**: Analyze historical data for service reliability patterns

### Incident Response
1. **Health Assessment**: Quick one-shot monitoring of affected services
2. **Service Restart**: Targeted restart operations with validation
3. **Dependency Analysis**: Check dependent services for cascade failures
4. **Validation**: Confirm services reach healthy state after remediation
5. **Documentation**: Export operation results for incident reports

### Maintenance Operations
1. **Pre-Maintenance Health**: Baseline service status before changes
2. **Planned Restarts**: Controlled service operations during maintenance windows
3. **Post-Maintenance Validation**: Confirm all services return to healthy state
4. **Rollback Procedures**: Quick service recovery if maintenance causes issues
5. **Audit Trails**: Comprehensive logging for change management compliance

### Application Deployment
1. **Pre-Deployment Check**: Verify application services are healthy
2. **Service Stops**: Controlled shutdown of application services for updates
3. **Post-Deployment Start**: Restart services after application updates
4. **Health Validation**: Confirm services start correctly with new code
5. **Monitoring Setup**: Continuous monitoring during deployment stabilization

---

## Service Management Best Practices

### Service Identification
- **Use ServiceName**: Always use ServiceName (not DisplayName) for consistency
- **Document Dependencies**: Maintain service dependency maps for each application
- **Startup Type Standards**: Establish organizational standards for service startup types
- **Service Catalogs**: Create standardized lists of critical services per server role

### Monitoring Strategy
- **Tiered Monitoring**: Different monitoring intervals for different service criticality levels
- **Dependency Awareness**: Monitor dependent services for complete health pictures
- **Startup Type Validation**: Include startup type checks for compliance requirements
- **Historical Tracking**: Maintain service health history for trend analysis

### Operational Procedures
- **Change Windows**: Schedule service operations during approved maintenance windows
- **Validation Requirements**: Always validate service state after operations
- **Retry Logic**: Configure appropriate retry counts based on service characteristics
- **Timeout Settings**: Adjust timeouts based on service startup/shutdown behavior

### Security and Compliance
- **Least Privilege**: Use service accounts with minimal required permissions
- **Audit Logging**: Export all operations to CSV for compliance reporting
- **Change Approval**: Implement approval workflows for production service operations
- **Documentation**: Maintain current service operation procedures and dependencies

---

## Integration Scenarios

### Monitoring System Integration
```powershell
# SIEM/Dashboard Integration
.\MonitorCriticalServices.ps1 -ComputerName (Get-Content .\CriticalServers.txt) `
  -Services 'W3SVC','MSSQLSERVER','Spooler' -RequireAutomaticStart `
  -FailNonZeroExit -OutputCsv \\monitoring\logs\ServiceHealth.csv

# Parse results for alerting
$unhealthy = Import-Csv \\monitoring\logs\ServiceHealth.csv | Where-Object { $_.Healthy -eq 'False' }
if ($unhealthy) { Send-Alert "Unhealthy services detected: $($unhealthy.Count)" }
```

### Automated Remediation
```powershell
# Combined monitoring and remediation
$issues = .\MonitorCriticalServices.ps1 -ComputerName app01 -Services 'W3SVC' -FailNonZeroExit
if ($LASTEXITCODE -eq 1) {
    Write-Warning "Services unhealthy, attempting restart..."
    .\RestartServices.ps1 -ComputerName app01 -Services 'W3SVC' -ValidateAfter -Verbose
}
```

### Scheduled Operations
```powershell
# Task Scheduler integration for regular monitoring
schtasks /create /tn "Service Health Check" /tr "PowerShell.exe -File C:\Scripts\MonitorCriticalServices.ps1 -ComputerName (gc C:\Scripts\servers.txt) -Services 'W3SVC','MSSQLSERVER' -OutputCsv C:\Logs\ServiceHealth.csv" /sc hourly
```

---

## Tips & Best Practices

### Monitoring Tips
- Use `MonitorCriticalServices` in a scheduled task with `-FailNonZeroExit` to flag pipelines/monitors
- Keep a **service catalog** per app stack (what must be running, startup type, dependencies)
- Pair with your alerting (e.g., parse the CSV and send email/Teams/Slack when a row has `Healthy = False`)
- Use **continuous mode** for real-time monitoring during maintenance windows
- Configure different **monitoring intervals** based on service criticality

### Restart Tips
- Always use `-ValidateAfter` for critical services to ensure successful operations
- Configure `-TimeoutSeconds` based on actual service startup/shutdown behavior
- Use `-RestartDependencies` for application services with complex dependency chains
- Test with `-WhatIf` before executing operations in production
- Schedule service restarts during approved maintenance windows

### Integration Tips
- **CSV Export**: Both scripts export CSV for easy integration with monitoring systems
- **Exit Codes**: Monitor script uses exit codes for pipeline integration
- **Structured Output**: Consistent output format enables automated parsing
- **Credential Handling**: Both scripts support secure credential management
- **Remote Execution**: Built on PowerShell remoting for secure operations

---

## Future GUI Integration Ideas

### Monitoring Interface
- **Service picker** (auto-complete from selected hosts)
- **Toggle for continuous mode**, intervals, durations
- **Real-time dashboard** with service health visualization
- **Historical charts** showing service uptime trends
- **Alert configuration** with notification preferences

### Restart Interface
- **Retry/timeout knobs** with recommended defaults
- **One-click restart** with dependency awareness and a pre-check/preview
- **Batch operations** with progress tracking
- **Rollback capabilities** for failed operations
- **Integration** with change management systems

### Unified Console
- **Combined monitoring and remediation** workflows
- **Service dependency visualization**
- **Automated remediation rules** based on monitoring results
- **Historical operation tracking** and reporting
- **Integration** with existing IT service management tools

---

## Troubleshooting Guide

### Common Issues
- **Access Denied**: Verify service account has appropriate permissions on target computers
- **WinRM Errors**: Ensure PowerShell remoting is enabled and configured properly
- **Service Not Found**: Confirm service names are correct (use ServiceName, not DisplayName)
- **Timeout Issues**: Adjust timeout values based on actual service behavior
- **Dependency Failures**: Verify dependent services exist and are properly configured

### Diagnostic Steps
1. **Test Connectivity**: Verify network connectivity and DNS resolution to targets
2. **Check Permissions**: Confirm service account has necessary privileges
3. **Validate Service Names**: Use `Get-Service` to verify correct service names
4. **Review Dependencies**: Check service dependency chains for missing components
5. **Monitor Logs**: Review Windows Event Logs for service-specific error messages

### Performance Optimization
- **Batch Processing**: Group operations by network segments to minimize latency
- **Parallel Execution**: Consider PowerShell jobs for large-scale operations
- **Timeout Tuning**: Adjust timeouts based on service characteristics and network conditions
- **Monitoring Intervals**: Balance monitoring frequency with system load
- **CSV Management**: Implement log rotation for long-running monitoring operations