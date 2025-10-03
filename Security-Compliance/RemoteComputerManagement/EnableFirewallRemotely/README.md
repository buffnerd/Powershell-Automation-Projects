# EnableFirewallRemotely

Enable and configure Windows Defender Firewall remotely with comprehensive profile management and rule configuration.

## Overview

This PowerShell script provides enterprise-grade remote firewall management capabilities with:
- **Profile Management**: Enable Domain, Private, and/or Public firewall profiles
- **Built-in Rule Groups**: Manage WinRM, Remote Desktop, and File/Printer Sharing rules
- **Custom Port Rules**: Open specific TCP/UDP ports with standardized naming
- **Safety Features**: Dry-run mode, credential support, and comprehensive error handling
- **Reporting**: Optional CSV export of all changes and their status

## Key Features

### Firewall Profile Control
- **Domain Profile**: Enforce firewall for domain-joined networks
- **Private Profile**: Control firewall on private networks
- **Public Profile**: Manage firewall on public/untrusted networks
- **Selective Activation**: Choose any combination of profiles to enable

### Essential Admin Access
- **WinRM Rules**: Automatically preserve remote PowerShell access
- **Remote Desktop**: Enable RDP firewall rules when needed
- **File/Printer Sharing**: Allow network file operations
- **Intelligent Protection**: Prevents locking yourself out of remote systems

### Custom Port Management
- **TCP/UDP Support**: Open specific ports with proper validation
- **Named Rules**: Standardized naming convention for tracking
- **Duplicate Prevention**: Handles overlapping port requests gracefully
- **Profile Application**: Rules apply to all specified profiles

## Script Parameters

### Target Selection
- **ComputerName**: Target computers (supports pipeline input)
- **Credential**: PSCredential for remote authentication

### Profile Settings
- **EnableDomain**: Turn on Domain profile firewall
- **EnablePrivate**: Turn on Private profile firewall
- **EnablePublic**: Turn on Public profile firewall

### Access Rules
- **AllowWinRM**: Ensure Windows Remote Management access
- **AllowRDP**: Enable Remote Desktop firewall rules
- **AllowFilePrint**: Allow File and Printer Sharing

### Custom Ports
- **OpenTcp**: Array of TCP ports to open (e.g., 8443, 9443)
- **OpenUdp**: Array of UDP ports to open (e.g., 514, 1514)
- **RulePrefix**: Custom prefix for rule names (default: 'Ops-Open')

### Operation Control
- **DryRun**: Preview changes without applying them
- **OutputCsv**: Export results to CSV file

## Usage Examples

### Basic Firewall Hardening
```powershell
# Enable Domain and Private profiles with WinRM protection
.\EnableFirewallRemotely.ps1 -ComputerName web01,web02 -EnableDomain -EnablePrivate -AllowWinRM -Verbose
```

### Complete Profile Enforcement
```powershell
# Enable all profiles with RDP access for workstations
$computers = Get-Content .\workstations.txt
.\EnableFirewallRemotely.ps1 -ComputerName $computers -EnableDomain -EnablePrivate -EnablePublic -AllowWinRM -AllowRDP
```

### Custom Application Support
```powershell
# Open web server ports with custom naming
.\EnableFirewallRemotely.ps1 -ComputerName app-server -EnableDomain -AllowWinRM -OpenTcp 80,443,8080 -RulePrefix "WebApp"
```

### Security Log Server
```powershell
# Configure syslog collector with UDP 514
.\EnableFirewallRemotely.ps1 -ComputerName log-server -EnableDomain -EnablePrivate -AllowWinRM -OpenUdp 514 -RulePrefix "Syslog"
```

### Safe Preview Mode
```powershell
# Preview all changes before applying
.\EnableFirewallRemotely.ps1 -ComputerName $servers -EnableDomain -AllowWinRM -AllowRDP -DryRun -OutputCsv .\firewall_preview.csv
```

### Authenticated Remote Access
```powershell
# Use specific credentials for remote configuration
$cred = Get-Credential domain\admin
.\EnableFirewallRemotely.ps1 -ComputerName server01 -Credential $cred -EnableDomain -AllowWinRM -OpenTcp 3389
```

## Output and Reporting

### Console Output
- **Real-time Progress**: Shows each action and its result
- **Status Indicators**: OK/ERR/DRYRUN prefixes for quick assessment
- **Detailed Errors**: Full error messages for troubleshooting

### CSV Export
When using `-OutputCsv`, creates a detailed log with:
- Computer name for each operation
- Complete result description
- Success/failure status
- Timestamp and action details

### Example Output
```
ComputerName Result
------------ ------
web01        OK: Enable Domain profile
web01        OK: Enable WinRM rules
web01        OK: Open TCP 8443 (WebApp-TCP-8443)
web02        ERR: Access denied - insufficient privileges
```

## Security Considerations

### Access Prevention
- **WinRM Protection**: Script ensures remote access isn't blocked
- **Credential Validation**: Proper authentication before changes
- **Service Dependencies**: Validates firewall service availability

### Rule Management
- **Standardized Naming**: Consistent rule names for easy identification
- **Profile Awareness**: Rules apply to appropriate network profiles
- **Duplicate Handling**: Prevents conflicting or duplicate rules

### Audit Trail
- **Change Logging**: All modifications are recorded
- **Dry-Run Testing**: Validate changes before implementation
- **Error Tracking**: Failed operations are clearly documented

## Prerequisites

### PowerShell Requirements
- **PowerShell 3.0+**: Required for NetSecurity module
- **Administrative Rights**: Local admin on target computers
- **WinRM Enabled**: For remote operations

### Network Access
- **PowerShell Remoting**: Target computers must allow PS remoting
- **Firewall Service**: Windows Firewall service must be available
- **Network Connectivity**: Direct network access to target systems

## Error Handling

### Common Issues
- **Access Denied**: Insufficient privileges on target computer
- **Network Unreachable**: WinRM or network connectivity problems
- **Service Unavailable**: Windows Firewall service not running
- **Invalid Ports**: Port numbers outside valid range (1-65535)

### Troubleshooting Steps
1. **Verify Credentials**: Ensure account has local admin rights
2. **Test Connectivity**: Confirm WinRM access with `Test-WSMan`
3. **Check Service**: Validate firewall service status
4. **Review Logs**: Examine Windows Event Logs for additional details

## Best Practices

### Implementation Strategy
1. **Test First**: Always use `-DryRun` for initial validation
2. **Gradual Rollout**: Apply to test systems before production
3. **Document Changes**: Use CSV export for change tracking
4. **Credential Security**: Use secure credential storage methods

### Operational Guidelines
- **WinRM Access**: Always include `-AllowWinRM` to prevent lockouts
- **Profile Selection**: Choose appropriate profiles for network topology
- **Custom Naming**: Use descriptive rule prefixes for easy management
- **Regular Audits**: Periodically review firewall rules and profiles

## Integration Notes

### GUI Integration Points
- Computer selection dialog with bulk import options
- Checkbox interface for profile and rule group selection
- Port input fields with validation and help text
- Progress indicators and real-time status updates
- Results viewer with filtering and export capabilities

### Enterprise Deployment
- **Group Policy**: Can complement GP-based firewall settings
- **SCCM Integration**: Suitable for Configuration Manager deployment
- **Monitoring Tools**: Results integrate with SIEM and monitoring systems
- **Change Management**: CSV outputs support change tracking requirements