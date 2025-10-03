# DeployNetworkPrinters

## Overview
Automated deployment of shared network printers to target computers with support for both per-machine (all users) and per-user installation methods.

## Scripts
- **DeployNetworkPrinters.ps1** - Main script for deploying network printers with comprehensive options

## Key Features
- **Dual Installation Modes**: Per-machine (all users) or per-user installation
- **Idempotent Operations**: Skips already-present connections to prevent duplicates
- **Default Printer Setting**: Optional default printer configuration (per-user mode)
- **Reachability Validation**: Pre-deployment UNC path testing
- **Spooler Management**: Optional Print Spooler restart for immediate availability
- **Batch Processing**: Support for multiple computers and printers simultaneously
- **Comprehensive Reporting**: Detailed results with CSV export capability

## Environment Customization
- **Printer Selection**: Multi-select picker populated from print server for GUI
- **Installation Mode**: Toggle between per-machine and per-user deployment
- **Default Printer**: Dropdown selection from deployed printers (per-user mode)
- **Validation Options**: Checkboxes for reachability check and spooler restart
- **Credential Management**: Secure credential prompt for remote execution

## Usage Examples

### Per-Machine Deployment with Spooler Restart
```powershell
.\DeployNetworkPrinters.ps1 -ComputerName (Get-Content .\hosts.txt) `
  -Printers '\\print01\HR-1stFloor','\\print01\Ops-2ndFloor' `
  -PerMachine -RestartSpooler -ValidateReachability -Verbose
```

### Per-User Deployment with Default Setting
```powershell
.\DeployNetworkPrinters.ps1 -ComputerName PC-007 `
  -Printers '\\print01\HR-1stFloor' -SetDefault '\\print01\HR-1stFloor' -Verbose
```

### Bulk Deployment with Credentials
```powershell
$cred = Get-Credential
.\DeployNetworkPrinters.ps1 -ComputerName DC01,DC02 `
  -Printers '\\print01\Executive','\\print01\Legal' `
  -Credential $cred -OutputCsv .\deployment_results.csv
```

### Pipeline Input from Active Directory
```powershell
Get-ADComputer -Filter "OperatingSystem -like '*Windows 10*'" | 
  Select-Object -ExpandProperty Name | 
  .\DeployNetworkPrinters.ps1 -Printers '\\print01\StandardOffice' -PerMachine
```

## Parameters
- **ComputerName**: Target computer(s), defaults to local machine
- **Printers**: Array of UNC printer paths (e.g., '\\server\queue')
- **Credential**: PSCredential for remote authentication
- **PerMachine**: Switch for per-machine installation (all users)
- **SetDefault**: Printer queue to set as default (per-user mode only)
- **ValidateReachability**: Pre-deployment UNC path validation
- **RestartSpooler**: Restart Print Spooler after per-machine installation
- **OutputCsv**: Path for detailed results export

## Installation Methods

### Per-Machine Installation
- Uses `rundll32 printui.dll,PrintUIEntry /ga`
- Appears for all users after spooler restart or logon refresh
- Requires local administrator privileges
- Recommended for shared workstations and kiosks

### Per-User Installation
- Uses `Add-Printer -ConnectionName`
- Installs for current user context only
- Supports default printer setting
- Ideal for personal workstations and specific user requirements

## Common Use Cases
1. **Standardized Deployment** - Deploy standard printer sets to computer groups
2. **User Onboarding** - Provision printers for new user workstations
3. **Office Moves** - Redeploy printers after physical relocations
4. **Printer Server Migration** - Batch update to new print server locations
5. **Kiosk Configuration** - Deploy per-machine printers for shared terminals

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- Network access to print servers and target computers
- Print Spooler service running on target computers
- For per-machine: Local administrator rights on targets
- PowerShell Remoting (WinRM) enabled for remote operations

## Security Considerations
- Uses PowerShell remoting for secure remote execution
- Credentials handled through secure PowerShell credential objects
- UNC path validation prevents invalid printer deployments
- WhatIf support for safe testing before actual deployment
- Comprehensive error handling for authentication failures

## Error Handling
- Individual computer/printer failures don't stop batch processing
- Detailed error messages in results output
- Graceful handling of unreachable printers or computers
- Comprehensive logging with -Verbose support
- Non-terminating errors for bulk operations

## Output Format
Results include:
- **ComputerName**: Target computer processed
- **Queue**: Printer UNC path
- **Mode**: Installation mode (PerMachine/PerUser)
- **Action**: Performed action (Install/None)
- **Result**: Operation outcome (Installed/AlreadyPresent/Error/Unreachable)
- **Message**: Additional details or error information

## Best Practices
1. **Test First**: Always use -WhatIf for initial validation
2. **Validate Connectivity**: Use -ValidateReachability for large deployments
3. **Credential Management**: Use service accounts for automated operations
4. **Spooler Restart**: Use -RestartSpooler for immediate per-machine availability
5. **Documentation**: Export results with -OutputCsv for audit trails
6. **Batch Size**: Consider processing large computer lists in smaller batches

## Troubleshooting
- **Access Denied**: Verify credentials and local admin rights
- **Unreachable Queue**: Check DNS resolution and firewall rules
- **Spooler Issues**: Ensure Print Spooler service is running
- **Per-Machine Delays**: Allow time for spooler restart or user logon
- **Default Printer**: Only works in per-user mode with valid queue name