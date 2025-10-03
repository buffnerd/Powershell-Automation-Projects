# RestartServices

## Overview
Safely restart, start, or stop Windows services across multiple computers with comprehensive retry logic, dependency handling, and validation capabilities.

## Scripts
- **RestartServices.ps1** - Main script for service lifecycle management with advanced retry and validation features

## Key Features
- **Multiple Actions**: Support for Restart, Start, and Stop operations
- **Dependency Awareness**: Optional handling of service dependencies during operations
- **Retry Logic**: Configurable retry attempts with delays for failed operations
- **Post-Validation**: Optional verification that services reach desired states
- **Timeout Management**: Configurable timeouts for service state transitions
- **Comprehensive Logging**: Detailed results with CSV export for audit trails
- **WhatIf Support**: Safe testing with -WhatIf parameter before actual operations

## Environment Customization
- **Target Selection**: Computer picker with list/file/AD integration for GUI
- **Service Selection**: Multi-select control with service validation for GUI
- **Action Selection**: Dropdown for Restart/Start/Stop operations
- **Timeout Configuration**: Numeric inputs for timeout and retry settings
- **Validation Options**: Checkboxes for dependency handling and post-validation
- **Export Configuration**: File save dialog for CSV output

## Usage Examples

### Basic Service Restart with Validation
```powershell
.\RestartServices.ps1 -ComputerName web01,web02 `
  -Services 'W3SVC','Schedule' -ValidateAfter -Verbose
```

### Stop Services with Extended Timeout and Retries
```powershell
.\RestartServices.ps1 -ComputerName (Get-Content .\print-servers.txt) `
  -Services 'Spooler' -Action Stop -RetryCount 2 -TimeoutSeconds 120 -Verbose
```

### Dependency-Aware Service Start
```powershell
.\RestartServices.ps1 -ComputerName app01 `
  -Services 'W3SVC' -Action Start -RestartDependencies -ValidateAfter
```

### Cross-Domain Service Management
```powershell
$cred = Get-Credential
.\RestartServices.ps1 -ComputerName dmz01,dmz02 `
  -Services 'IISAdmin','W3SVC' -Credential $cred `
  -Action Restart -ValidateAfter -OutputCsv .\restart_results.csv
```

### Safe Testing with WhatIf
```powershell
.\RestartServices.ps1 -ComputerName prod01,prod02 `
  -Services 'MSSQLSERVER' -Action Restart -WhatIf -Verbose
```

### Pipeline Integration
```powershell
Get-ADComputer -Filter "Name -like 'WEB*'" | 
  Select-Object -ExpandProperty Name | 
  .\RestartServices.ps1 -Services 'W3SVC','WAS' -ValidateAfter
```

## Parameters
- **ComputerName**: Target computer(s), defaults to local machine
- **Services**: Array of service names (ServiceName, not DisplayName)
- **Credential**: PSCredential for cross-domain/workgroup authentication
- **Action**: Operation to perform (Restart/Stop/Start, default: Restart)
- **TimeoutSeconds**: Wait time for state transitions (10-600 seconds, default: 60)
- **RetryCount**: Number of retry attempts on failure (0-5, default: 1)
- **RestartDependencies**: Ensure dependencies are running for Start/Restart
- **ValidateAfter**: Verify service reaches desired state after operation
- **OutputCsv**: Path for detailed results export

## Service Operations

### Restart Action
- **Behavior**: Stops and starts the service in one operation
- **Dependencies**: Handled after restart if -RestartDependencies specified
- **Validation**: Confirms service is Running after restart

### Start Action
- **Behavior**: Starts the service if not already running
- **Dependencies**: Started before target service if -RestartDependencies specified
- **Validation**: Confirms service reaches Running state

### Stop Action
- **Behavior**: Stops the service with Force parameter
- **Dependencies**: Not applicable for stop operations
- **Validation**: Confirms service reaches Stopped state

## Dependency Handling
When -RestartDependencies is specified:
1. **Enumerate Dependencies**: Identifies services the target depends on
2. **Start Dependencies**: Ensures dependent services are running
3. **Wait for Dependencies**: Waits for dependencies to reach Running state
4. **Continue Operation**: Proceeds with main service operation

## Retry Logic
- **Attempt Tracking**: Each retry attempt is logged separately
- **Success Detection**: Based on validation criteria or error absence
- **Backoff Strategy**: 3-second delay between retry attempts
- **Timeout Handling**: Separate timeout for each service operation
- **Failure Recording**: Detailed error messages for troubleshooting

## Common Use Cases
1. **Application Maintenance** - Restart application services for updates
2. **Incident Response** - Quick service recovery during outages
3. **Scheduled Maintenance** - Planned service restarts via Task Scheduler
4. **Deployment Automation** - Service management in CI/CD pipelines
5. **Troubleshooting** - Targeted service operations for problem resolution
6. **Infrastructure Management** - Bulk service operations across server farms

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- PowerShell Remoting (WinRM) enabled on target computers
- Permissions to manage services remotely (typically local admin)
- Network connectivity and DNS resolution to targets
- Service Control Manager access on target systems

## Validation Criteria

### Success Determination
- **Without ValidateAfter**: Operation completes without error
- **With ValidateAfter**: Service reaches desired state within timeout

### Desired States
- **Restart/Start**: Service status = Running
- **Stop**: Service status = Stopped

### Retry Triggers
- Service operation throws exception
- Service doesn't reach desired state within timeout
- Remote execution failures

## Output Format

### Console Output
Results table with:
- **ComputerName**: Target computer
- **ServiceName**: Service name
- **Action**: Operation performed
- **Attempt**: Retry attempt number
- **Desired**: Expected final state
- **FinalStatus**: Actual final state
- **Success**: Operation success status
- **Message**: Error details (if any)
- **Timestamp**: Operation completion time

### CSV Export
Same fields as console output for:
- Audit trail maintenance
- Dashboard integration
- Historical analysis
- Compliance reporting

## Error Handling
- **Individual Failures**: Don't stop batch processing
- **Remote Execution**: Graceful handling of connectivity issues
- **Service Errors**: Detailed error capture and reporting
- **Timeout Management**: Clean handling of service state timeouts
- **Authentication**: Proper credential error handling

## Security Considerations
- **Privileged Operations**: Service management requires elevated permissions
- **Remote Execution**: Uses secure PowerShell remoting
- **Credential Handling**: Secure PSCredential object usage
- **WhatIf Support**: Safe testing before production execution
- **Audit Logging**: Comprehensive operation tracking

## Performance Considerations
- **Service State Waits**: Timeouts affect overall execution time
- **Retry Overhead**: Multiple attempts increase total runtime
- **Remote Execution**: Network latency impacts performance
- **Dependency Chains**: Deep dependencies extend operation time
- **Batch Processing**: Large computer lists require time planning

## Best Practices
1. **Test First**: Always use -WhatIf for production operations
2. **Validation**: Use -ValidateAfter for critical services
3. **Timeouts**: Adjust timeouts based on service characteristics
4. **Dependencies**: Use -RestartDependencies for application services
5. **Retry Strategy**: Configure retries based on environment reliability
6. **Documentation**: Maintain service restart procedures and dependencies
7. **Scheduling**: Use appropriate maintenance windows for service operations
8. **Monitoring**: Export results for operational dashboards

## Integration with Monitoring
- **Pre-Operation Health**: Use with MonitorCriticalServices.ps1 for baseline
- **Post-Operation Validation**: Confirm services remain healthy after operations
- **Alert Integration**: Parse CSV results for automated notifications
- **Dashboard Feeds**: Real-time service operation status
- **Historical Analysis**: Track service restart patterns and success rates