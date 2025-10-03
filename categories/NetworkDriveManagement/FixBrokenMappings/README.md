# FixBrokenMappings

## Overview
Automated repair of broken/disconnected mapped network drives with credential management and selective remediation.

## Scripts
- **FixBrokenMappings.ps1** - Main script for detecting and repairing network drive issues

## Key Features
- **Multi-Detection Method**: Uses Get-PSDrive, Get-SmbMapping, and 'net use' for comprehensive mapping discovery
- **Smart Repair Logic**: Removes and recreates broken mappings with proper credential handling
- **Server Allow-listing**: Optional safety feature to only touch specific servers
- **Credential Management**: Optional cmdkey integration for persistent authentication
- **Stale Removal**: Option to remove mappings that cannot be repaired
- **Retry Mechanism**: Configurable retry attempts with delays
- **Comprehensive Reporting**: Detailed results with CSV export capability

## Environment Customization
- **Servers**: Multi-select list for GUI implementation
- **Credential**: Credential picker dialog for GUI
- **RemoveStale**: Checkbox with confirmation dialog for GUI
- **Retry Settings**: Numeric inputs for retry count and delay

## Usage Examples

### Basic Repair
```powershell
.\FixBrokenMappings.ps1 -Verbose
```

### Targeted Server Repair with Credentials
```powershell
$cred = Get-Credential
.\FixBrokenMappings.ps1 -Servers fs01,nas01 -Credential $cred -StoreCredWithCmdKey -Verbose
```

### Remove Stale Mappings
```powershell
.\FixBrokenMappings.ps1 -RemoveStale -Verbose -OutputCsv .\repair_results.csv
```

## Parameters
- **Servers**: Array of server names to restrict repairs to
- **Credential**: PSCredential for re-authentication
- **StoreCredWithCmdKey**: Store credentials persistently with cmdkey
- **RemoveStale**: Remove unreachable mappings after repair attempts
- **RetryCount**: Number of retry attempts (0-10, default: 2)
- **RetryDelaySeconds**: Delay between retries (1-60, default: 5)
- **OutputCsv**: Path for results export

## Common Use Cases
1. **Post-reboot repair** - Fix all disconnected drives after system restart
2. **Credential refresh** - Update stored credentials for multiple shares
3. **Infrastructure cleanup** - Remove mappings to decommissioned servers
4. **Selective maintenance** - Target specific file servers for updates

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- Network access to target UNC paths
- Appropriate permissions for drive mapping
- Optional: cmdkey utility for credential storage

## Security Considerations
- Credentials are handled securely through PowerShell credential objects
- cmdkey storage is optional and server-scoped
- WhatIf support for safe testing
- Server allow-listing prevents accidental modifications

## Error Handling
- Graceful fallback between detection methods
- Comprehensive try/catch blocks for each operation
- Detailed error reporting in results
- Non-terminating errors for bulk operations

## Output Format
Results include:
- **Letter**: Drive letter
- **Path**: UNC path
- **Action**: Performed action (None/Repair/Remove)
- **Result**: Outcome (Healthy/Success/Failed/Error/StaleRemoved)
- **Message**: Additional details or error messages