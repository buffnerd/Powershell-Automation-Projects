# Remote Computer Management

Enterprise-grade PowerShell scripts for safe and efficient remote computer operations.

## Category Overview

This category provides comprehensive remote computer management capabilities with built-in safety features, credential support, and enterprise-ready error handling. All scripts are designed to prevent accidental system lockouts while enabling efficient bulk operations across multiple computers.

## Scripts in this Category

### [RestartRemoteComputers](./RestartRemoteComputers/)
**Safe remote computer restart with comprehensive verification**
- **Purpose**: Restart multiple computers remotely with grace periods and verification
- **Key Features**: Pre-restart validation, graceful shutdown options, post-restart verification
- **Safety**: Prevents restarts during critical hours, validates user sessions, confirms system readiness
- **Use Cases**: Patch deployment, maintenance windows, troubleshooting unresponsive systems

### [EnableFirewallRemotely](./EnableFirewallRemotely/)
**Configure Windows Defender Firewall remotely with profile management**
- **Purpose**: Enable firewall profiles and configure access rules across multiple systems
- **Key Features**: Profile control (Domain/Private/Public), built-in rule groups, custom port management
- **Safety**: Preserves WinRM access, dry-run mode, comprehensive validation
- **Use Cases**: Security hardening, compliance enforcement, application deployment support

### [VPN-Proxy-Chains-In-Powershell](./VPN-Proxy-Chains-In-Powershell/)
**VPN and proxy chain automation for enhanced network security**
- **Purpose**: Automate VPN connections and proxy chain configurations
- **Key Features**: Multi-hop proxy chains, VPN integration, connection validation
- **Safety**: Connection testing, fallback mechanisms, secure credential handling
- **Use Cases**: Secure remote access, network security testing, compliance requirements

## Common Features

### Remote Access Methods
- **PowerShell Remoting**: Primary method using WinRM for secure operations
- **Credential Support**: PSCredential objects for authenticated access
- **Fallback Mechanisms**: Alternative methods when primary access fails
- **Connection Validation**: Pre-operation connectivity and permission checks

### Safety and Reliability
- **Pre-execution Checks**: Validate system state before making changes
- **Dry-run Capabilities**: Preview operations without making actual changes
- **Grace Periods**: Allow users time to save work before disruptive operations
- **Comprehensive Logging**: Detailed operation logs with success/failure tracking

### Enterprise Integration
- **Bulk Operations**: Process multiple computers efficiently
- **CSV Import/Export**: Support for computer lists and operation results
- **Credential Management**: Secure handling of administrative credentials
- **Progress Reporting**: Real-time status updates during long operations

## Usage Patterns

### Basic Remote Operations
```powershell
# Simple restart of development servers
.\RestartRemoteComputers.ps1 -ComputerName dev01,dev02 -Credential $adminCred -Verbose

# Enable firewall on workstations with RDP access
.\EnableFirewallRemotely.ps1 -ComputerName (Get-Content .\workstations.txt) -EnableDomain -AllowWinRM -AllowRDP
```

### Bulk Operations with Validation
```powershell
# Preview restart operations before execution
.\RestartRemoteComputers.ps1 -ComputerName $servers -DryRun -OutputCsv .\restart_plan.csv

# Test firewall changes before applying
.\EnableFirewallRemotely.ps1 -ComputerName $webServers -EnableDomain -OpenTcp 80,443 -DryRun
```

### Maintenance Window Operations
```powershell
# Coordinate restart with firewall hardening
$computers = Get-Content .\maintenance_targets.txt
$cred = Get-Credential

# First, prepare firewall settings
.\EnableFirewallRemotely.ps1 -ComputerName $computers -Credential $cred -EnableDomain -AllowWinRM -AllowRDP

# Then restart to apply all changes
.\RestartRemoteComputers.ps1 -ComputerName $computers -Credential $cred -GracePeriod 300 -VerifyRestart
```

## Security Considerations

### Access Control
- **Least Privilege**: Scripts validate minimum required permissions
- **Credential Protection**: Secure handling of authentication objects
- **Session Management**: Proper cleanup of remote sessions
- **Audit Logging**: Comprehensive tracking of administrative actions

### Network Security
- **WinRM Protection**: All scripts preserve remote management access
- **Firewall Awareness**: Operations consider existing firewall configurations
- **Encrypted Communication**: PowerShell remoting uses encrypted channels
- **Connection Validation**: Verify secure communication before operations

### Change Management
- **Preview Capabilities**: All scripts support dry-run mode
- **Rollback Information**: Operations provide information for reverting changes
- **Change Tracking**: Detailed logs support change management processes
- **Impact Assessment**: Pre-operation checks identify potential issues

## Prerequisites

### System Requirements
- **PowerShell 3.0+**: Required for all remote management features
- **WinRM Configuration**: Target computers must have PowerShell remoting enabled
- **Administrative Access**: Local administrator rights on target computers
- **Network Connectivity**: Direct network access between management and target systems

### Service Dependencies
- **Windows Remote Management**: Core service for PowerShell remoting
- **Windows Firewall**: Must be available for firewall management operations
- **Computer Browser**: Required for some network discovery operations
- **Event Log**: Services must be running for comprehensive logging

## Best Practices

### Planning and Preparation
1. **Test Environment**: Always test scripts in non-production environment first
2. **Computer Lists**: Maintain accurate inventories of target computers
3. **Credential Management**: Use secure credential storage solutions
4. **Maintenance Windows**: Schedule disruptive operations during appropriate times

### Execution Guidelines
1. **Start Small**: Begin with small groups of computers
2. **Monitor Progress**: Watch for errors and unexpected behavior
3. **Verify Results**: Confirm operations completed successfully
4. **Document Changes**: Maintain records of all administrative actions

### Error Handling
1. **Connectivity Tests**: Verify network access before bulk operations
2. **Permission Validation**: Confirm administrative rights on target systems
3. **Service Dependencies**: Check required services are running
4. **Graceful Failures**: Handle individual computer failures without stopping bulk operations

## Troubleshooting

### Common Issues
- **Access Denied**: Insufficient privileges or authentication failures
- **Network Timeouts**: Connectivity issues or firewall blocking
- **Service Unavailable**: Required services not running on target computers
- **WinRM Errors**: PowerShell remoting configuration problems

### Diagnostic Steps
1. **Test-WSMan**: Verify WinRM connectivity to target computers
2. **Get-Credential**: Validate administrative credentials
3. **Test-NetConnection**: Check network connectivity and port access
4. **Get-Service**: Verify required services are running

### Resolution Strategies
- **Credential Reset**: Refresh authentication tokens and credentials
- **WinRM Reconfiguration**: Reset PowerShell remoting on target computers
- **Firewall Adjustment**: Temporarily adjust firewall rules for testing
- **Service Restart**: Restart required services on management or target systems

## Integration Notes

### SCCM Integration
- Scripts complement System Center Configuration Manager capabilities
- Can be packaged as SCCM applications or scripts
- Results integrate with SCCM reporting and compliance features

### Group Policy Coordination
- Firewall scripts work alongside Group Policy firewall settings
- Restart operations can trigger Group Policy refresh
- Changes may require Group Policy update cycles

### Monitoring Integration
- Operation logs integrate with SIEM and monitoring systems
- Success/failure metrics support operational dashboards
- Change tracking supports compliance and audit requirements

### GUI Development Readiness
All scripts include comprehensive parameter validation and structured output suitable for GUI development:
- Computer selection dialogs with validation
- Progress indicators and real-time status updates
- Results grids with filtering and export capabilities
- Credential input with secure storage options