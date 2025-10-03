# CleanupOfflinePrinters

## Overview
Automated detection, repair, and removal of offline or stale network printer connections with support for both per-machine and per-user remediation modes.

## Scripts
- **CleanupOfflinePrinters.ps1** - Main script for detecting and remediating printer connection issues

## Key Features
- **Comprehensive Detection**: Identifies network printers with connectivity or status issues
- **Dual Remediation Modes**: Per-machine (/gd and /ga) or per-user (Remove/Add-Printer) repair
- **Server Allow-listing**: Safety feature to only touch specific print servers
- **Stale Removal**: Option to remove printers that cannot be restored
- **Retry Mechanism**: Configurable retry attempts with delays for validation
- **Printer Filtering**: Optional filtering to specific queue names
- **Status Validation**: Tests both UNC reachability and printer status

## Environment Customization
- **Server Selection**: Multi-select allow-list for safety in GUI
- **Operation Mode**: Toggle between repair and remove actions
- **Machine Mode**: Checkbox for per-machine vs per-user operations
- **Retry Configuration**: Numeric inputs for retry count and delay
- **Printer Filtering**: Multi-select specific queues for targeted operations

## Usage Examples

### Remove Stale Printers from Specific Server
```powershell
.\CleanupOfflinePrinters.ps1 -ComputerName (Get-Content .\hosts.txt) `
  -Servers print01 -RemoveStale -Verbose
```

### Repair All Broken Queues (Per-User Mode)
```powershell
.\CleanupOfflinePrinters.ps1 -ComputerName PC-007 `
  -ReinstallIfBroken -Verbose
```

### Per-Machine Cleanup on VDI Pool
```powershell
.\CleanupOfflinePrinters.ps1 -ComputerName VDI-01,VDI-02 `
  -PerMachine -ReinstallIfBroken -Verbose
```

### Targeted Queue Repair with Credentials
```powershell
$cred = Get-Credential
.\CleanupOfflinePrinters.ps1 -ComputerName PC-100 `
  -Printers '\\print01\HR-Floor1','\\print01\Legal' `
  -ReinstallIfBroken -Credential $cred -OutputCsv .\cleanup_results.csv
```

### Server-Specific Cleanup with Multiple Options
```powershell
.\CleanupOfflinePrinters.ps1 -ComputerName (Get-ADComputer -Filter "Name -like 'KIOSK*'") `
  -Servers print01,print02 -PerMachine -ReinstallIfBroken -RemoveStale `
  -RetryCount 3 -RetryDelaySeconds 10 -Verbose
```

## Parameters
- **ComputerName**: Target computer(s), defaults to local machine
- **Credential**: PSCredential for remote authentication
- **Servers**: Allow-list of print servers to touch (safety feature)
- **RemoveStale**: Remove printers that remain unreachable after repair
- **ReinstallIfBroken**: Attempt remove+reinstall for broken connections
- **PerMachine**: Use per-machine operations (/gd and /ga)
- **Printers**: Optional filter to specific queue names
- **RetryCount**: Number of post-remediation validation attempts (0-10)
- **RetryDelaySeconds**: Delay between retry attempts (1-60 seconds)
- **OutputCsv**: Path for detailed results export

## Detection Criteria

### Network Printer Identification
- Printers with UNC-style names (\\server\queue)
- Printers with UNC-style ShareName properties
- Excludes local and direct IP printers

### Health Assessment
- **Healthy**: UNC path reachable AND PrinterStatus is Normal/0/null
- **Broken**: UNC path unreachable OR PrinterStatus indicates error
- **Filtered**: Server not in allow-list (when specified)

## Remediation Methods

### Per-User Mode (Default)
- **Detection**: Uses `Get-Printer` to enumerate connections
- **Repair**: `Remove-Printer` followed by `Add-Printer -ConnectionName`
- **Validation**: UNC path reachability testing
- **Scope**: Current user context only

### Per-Machine Mode
- **Detection**: Same enumeration but treats as machine-wide
- **Repair**: `PrintUIEntry /gd` followed by `PrintUIEntry /ga`
- **Spooler Management**: Automatic restart after /ga operations
- **Scope**: All users on the machine

## Common Use Cases
1. **Post-Migration Cleanup** - Remove old server references after print server migration
2. **VDI Maintenance** - Clean stale connections in virtual desktop environments
3. **Network Changes** - Update printer connections after network infrastructure changes
4. **Scheduled Maintenance** - Regular cleanup of orphaned printer connections
5. **User Support** - Quick repair of broken printer connections
6. **Server Decommissioning** - Remove connections to retired print servers

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- Print Spooler service running on target computers
- Network access to print servers for validation
- For per-machine operations: Local administrator rights
- PowerShell Remoting (WinRM) enabled for remote operations

## Security Considerations
- Server allow-listing prevents accidental modification of production printers
- Uses PowerShell remoting for secure remote execution
- Credentials handled through secure PowerShell credential objects
- WhatIf support for safe testing before actual changes
- Comprehensive error handling and logging

## Error Handling
- Individual computer failures don't stop batch processing
- Graceful handling of inaccessible computers or print servers
- Detailed error reporting in results output
- Non-terminating errors for bulk operations
- Comprehensive logging with -Verbose support

## Output Format
Results include:
- **ComputerName**: Target computer processed
- **Queue**: Printer UNC path
- **Action**: Performed action (None/Skip/PerUserReinstall/PerMachineReinstall/RemovePerUser/RemovePerMachine)
- **Result**: Operation outcome (Healthy/ServerFiltered/Restored/Failed/Removed/Broken)
- **Message**: Additional details, error information, or operation results

## Performance Considerations
- UNC path testing can be slow for unreachable servers
- Per-machine operations include spooler restarts (brief service interruption)
- Retry mechanisms add time but improve reliability
- Large computer lists should be processed in batches
- Network timeouts may affect overall execution time

## Best Practices
1. **Server Allow-listing**: Always use -Servers parameter in production
2. **Test Mode**: Use -WhatIf for initial validation
3. **Incremental Approach**: Start with repair before resorting to removal
4. **Monitoring**: Export results with -OutputCsv for tracking
5. **Scheduled Execution**: Consider regular cleanup schedules
6. **Backup Connections**: Document important printer connections before cleanup

## Troubleshooting
- **Access Denied**: Verify credentials and permissions
- **Spooler Errors**: Check Print Spooler service status
- **Network Issues**: Validate DNS resolution and firewall rules
- **Per-Machine Delays**: Allow time for spooler restart effects
- **Filter Issues**: Verify server names match exactly (case-sensitive)

## Integration with Deployment
This script pairs well with `DeployNetworkPrinters.ps1` for complete printer lifecycle management:
1. Use cleanup script to remove old/broken connections
2. Use deployment script to install new/updated connections
3. Both scripts support the same computer targeting and credential methods