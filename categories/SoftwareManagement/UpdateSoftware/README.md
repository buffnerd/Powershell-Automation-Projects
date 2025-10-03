# UpdateSoftware.ps1 ✅ **IMPLEMENTED**

Update an application to a target version using either a new installer or winget (if present). Provides version gating to ensure updates only occur when needed.

## Features

- **Version-aware updates**: Only installs when current version is below target
- **Dual update methods**: Traditional installer packages or winget for modern systems
- **Comprehensive detection**: ProductCode or DisplayName-based application discovery
- **Remote execution**: Multi-computer support with credential handling
- **Safe deployment**: `-WhatIf` support for testing update scenarios
- **Status reporting**: CSV export for compliance tracking and audit trails

## Usage Examples

```powershell
# Update via installer when current version < target
.\UpdateSoftware.ps1 -ComputerName server01 `
  -ProductCode '{111...}' -TargetVersion 10.6.0 `
  -InstallerPath \\fs\sw\AcmeClient_10.6.0.msi -SilentArgs "/qn /norestart" -Verbose

# Use winget for desktops/workstations
.\UpdateSoftware.ps1 -ComputerName desktop01 -UseWinget -WingetId "Acme.Client" -TargetVersion 10.6.0 -Verbose

# Bulk update from server list with CSV output
.\UpdateSoftware.ps1 -ComputerName (Get-Content .\servers.txt) -DisplayNameContains "Acme Client" `
  -TargetVersion 11.0.0 -InstallerPath \\share\sw\AcmeClient_11.0.0.msi -OutputCsv .\update_results.csv
```

## Environment Adjustments

- **Target version**: Set `-TargetVersion` based on your deployment schedule
- **Detection method**: Use `-ProductCode` for MSI or `-DisplayNameContains` for broader matching
- **Update source**: Choose between installer packages (`-InstallerPath`) or winget (`-UseWinget`)
- **Silent switches**: Configure `-SilentArgs` per vendor requirements
- **Credentials**: Use `-Credential` for cross-domain or elevated access
- **Output tracking**: Set `-OutputCsv` for compliance documentation

## Requirements

- PowerShell 5+ with remoting capabilities
- Admin access to target computers for installer execution
- For installer mode: Access to software repository (UNC share)
- For winget mode: Winget installed on target systems
- Appropriate permissions for software installation

## Update Methods

### Installer Mode (Default)
- Stages installer package to remote system
- Executes with silent switches
- Works with MSI and EXE packages
- Best for server environments

### Winget Mode
- Uses Windows Package Manager for updates
- Ideal for desktop/workstation scenarios
- Requires winget availability on targets
- Simplified package management

**Status**: Fully implemented with flexible update methodologies for enterprise environments.