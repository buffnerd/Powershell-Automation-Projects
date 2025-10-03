# NetworkDriveManagement

Comprehensive automation for network drive mapping, credential management, and repair operations.

## Scripts Overview

### MapNetworkDrives
**Primary Script**: `MapNetworkDrives.ps1`
- **Purpose**: Automated network drive mapping with CSV support and credential management
- **Key Features**: 
  - CSV-driven bulk mapping operations
  - Credential storage with cmdkey integration
  - Idempotent operations (skip existing mappings)
  - Individual drive letter mapping support
  - Comprehensive validation and error handling

### FixBrokenMappings  
**Primary Script**: `FixBrokenMappings.ps1`
- **Purpose**: Detect and repair broken/disconnected mapped network drives
- **Key Features**:
  - Multi-method detection (Get-PSDrive, Get-SmbMapping, net use)
  - Smart repair with credential re-authentication
  - Server allow-listing for safety
  - Stale mapping removal
  - Retry mechanism with configurable delays

## Common Workflows

### Initial Drive Mapping
1. Prepare CSV file with drive mappings
2. Run `MapNetworkDrives.ps1` with credential storage
3. Validate mappings across target systems

### Maintenance and Repair
1. Run `FixBrokenMappings.ps1` to detect issues
2. Apply targeted repairs with credential refresh
3. Remove stale mappings for decommissioned servers

### Bulk Operations
1. Use CSV files for standardized mapping deployment
2. Implement server-specific configurations
3. Automate credential management across environments

## Environment Integration
Both scripts are designed for easy GUI integration with:
- File picker dialogs for CSV selection
- Credential picker controls
- Multi-select server lists
- Progress indicators for bulk operations
- Comprehensive result reporting

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- Network access to target UNC paths
- Appropriate domain/local permissions
- Optional: RSAT tools for advanced AD integration

## Security Features
- Secure credential handling through PowerShell objects
- Optional persistent credential storage with cmdkey
- WhatIf support for safe testing
- Server allow-listing for controlled operations
- Comprehensive audit trails

## Best Practices
1. **Test First**: Always use -WhatIf for initial validation
2. **Credential Management**: Use service accounts for automated operations
3. **Server Lists**: Maintain allow-lists for production safety
4. **Documentation**: Keep CSV files and mappings documented
5. **Monitoring**: Regular health checks with repair scripts