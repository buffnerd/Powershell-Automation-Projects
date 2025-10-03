# HardwareInventory - Comprehensive Hardware & Platform Asset Collection

## Overview
Enterprise-grade PowerShell script for collecting detailed hardware specifications, platform information, and security posture across Windows systems. Designed for asset management, compliance reporting, and security baseline assessment.

## Key Features
- **Complete Hardware Inventory**: Manufacturer, model, serial, BIOS, CPU, memory, storage
- **Platform Security Assessment**: TPM, Secure Boot, BitLocker status analysis
- **Network Configuration**: Active NIC detection with IPv4 address collection
- **Operating System Details**: Version, build, installation date, last boot
- **Parallel Execution**: Throttled concurrent collection across multiple systems
- **Multiple Export Formats**: CSV, JSONL, and formatted console output

## Hardware Data Collection

### System Information
- **Manufacturer**: System vendor (Dell, HP, Lenovo, etc.)
- **Model**: Specific system model and form factor
- **SerialNumber**: Unique hardware identifier for asset tracking
- **ChassisType**: Desktop, laptop, server, tablet classification

### BIOS/UEFI Details
- **BIOSVersion**: SMBIOS BIOS version string
- **BIOSReleaseDate**: Firmware release date for update tracking
- **UEFIMode**: UEFI vs Legacy BIOS detection
- **SecureBoot**: Secure Boot enablement status (optional)

### Processing & Memory
- **Processor**: CPU name and model identification
- **Cores**: Physical processor core count
- **LogicalProcessors**: Total logical processors (including hyperthreading)
- **MemoryGB**: Total physical RAM in gigabytes

### Storage Analysis
- **DiskCount**: Number of logical drives
- **DiskTotalGB**: Combined storage capacity across all drives
- **DiskFreeGB**: Available free space across all drives
- **DiskFreePct**: Percentage of free space remaining
- **DiskMediaTypes**: Physical disk types (SSD, HDD, etc.)

### Network Configuration
- **NIC_IPv4**: Comma-separated list of active IPv4 addresses
- **Network Adapters**: Enabled network interfaces only

### Operating System
- **OSCaption**: Full operating system name
- **OSEdition**: Windows edition/SKU
- **OSVersion**: Version number
- **OSBuild**: Build number for patch level tracking
- **OSInstallDate**: Original installation timestamp
- **LastBootUpTime**: Most recent system startup

## Security Posture Assessment

### TPM (Trusted Platform Module)
When `-IncludeTPM` is enabled:
- **TPM_Present**: TPM chip availability
- **TPM_Ready**: TPM enabled and activated status
- **TPM_SpecVersion**: TPM specification version (1.2, 2.0)

### Secure Boot
When `-IncludeSecureBoot` is enabled:
- **UEFIMode**: UEFI firmware mode detection
- **SecureBoot**: Secure Boot configuration status

### BitLocker Drive Encryption
When `-IncludeBitLocker` is enabled:
- **BitLockerSummary**: Per-drive protection status (C:On, D:Off, etc.)
- **Volume Protection**: Encryption status for each drive

## Usage Examples

### Basic Hardware Inventory
```powershell
# Single system local inventory
.\HardwareInventory.ps1 -OutputCsv .\local_hardware.csv

# Multiple systems from file
.\HardwareInventory.ps1 -ComputerName (Get-Content .\servers.txt) -OutputCsv .\server_hardware.csv

# Domain computer inventory
.\HardwareInventory.ps1 -ComputerName (Get-ADComputer -Filter "OperatingSystem -like '*Server*'" | Select-Object -ExpandProperty Name) -OutputCsv .\domain_servers.csv
```

### Security Posture Assessment
```powershell
# Complete security analysis
.\HardwareInventory.ps1 -ComputerName PC-01,PC-02,PC-03 -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputJsonl .\security_posture.jsonl

# TPM compliance check
.\HardwareInventory.ps1 -ComputerName (Get-Content .\workstations.txt) -IncludeTPM -OutputCsv .\tpm_compliance.csv

# BitLocker encryption status
.\HardwareInventory.ps1 -ComputerName (Get-Content .\laptops.txt) -IncludeBitLocker -OutputCsv .\bitlocker_status.csv
```

### Large-Scale Enterprise Collection
```powershell
# High-performance parallel collection
.\HardwareInventory.ps1 -ComputerName (Get-Content .\all_endpoints.txt) -ThrottleLimit 16 -OutputCsv .\enterprise_hardware.csv -Verbose

# Cross-domain collection with credentials
.\HardwareInventory.ps1 -ComputerName (Get-Content .\remote_sites.txt) -Credential (Get-Credential) -IncludeTPM -IncludeSecureBoot -OutputJsonl .\remote_inventory.jsonl
```

## Parameters

### Core Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ComputerName` | String[] | Target computers for inventory | Local computer |
| `Credential` | PSCredential | Authentication for remote systems | Current user |

### Security Assessment
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `IncludeTPM` | Switch | Collect TPM status information | False |
| `IncludeSecureBoot` | Switch | Collect Secure Boot status | False |
| `IncludeBitLocker` | Switch | Collect BitLocker encryption status | False |

### Performance & Output
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ThrottleLimit` | Int | Maximum concurrent connections | 8 |
| `OutputCsv` | String | CSV export file path | None |
| `OutputJsonl` | String | JSONL export file path | None |

## Output Schema

### Standard Fields (Always Collected)
- ComputerName, Manufacturer, Model, SerialNumber
- BIOSVersion, BIOSReleaseDate, ChassisType
- Processor, Cores, LogicalProcessors, MemoryGB
- DiskCount, DiskTotalGB, DiskFreeGB, DiskFreePct, DiskMediaTypes
- NIC_IPv4, OSCaption, OSEdition, OSVersion, OSBuild
- OSInstallDate, LastBootUpTime

### Optional Security Fields
- UEFIMode, SecureBoot (when `-IncludeSecureBoot`)
- TPM_Present, TPM_Ready, TPM_SpecVersion (when `-IncludeTPM`)
- BitLockerSummary (when `-IncludeBitLocker`)

## Performance Optimization

### Throttling Strategy
- **Default Throttle**: 8 concurrent connections balances speed and system impact
- **High-Performance**: Increase to 16-32 for powerful infrastructure
- **Conservative**: Reduce to 4-6 for slower networks or older systems
- **Network Considerations**: Factor in WAN links and bandwidth limitations

### Collection Scope
- **Security Features**: Optional TPM/Secure Boot/BitLocker collection adds overhead
- **Target Selection**: Use AD filters to focus on specific computer types
- **Batch Processing**: Split large inventories into manageable chunks
- **Scheduling**: Run during maintenance windows for minimal user impact

### Error Handling
- **Connection Failures**: Individual system failures don't stop overall collection
- **Permission Issues**: Graceful handling of access denied scenarios
- **Timeout Management**: Built-in timeouts prevent hanging operations
- **Verbose Logging**: Detailed progress information for troubleshooting

## Integration Examples

### Asset Management Integration
```powershell
# Monthly asset refresh
$month = Get-Date -Format 'yyyyMM'
.\HardwareInventory.ps1 -ComputerName (Get-ADComputer -Filter * | Select-Object -ExpandProperty Name) -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputCsv "\\assetdb\imports\hardware_$month.csv"
```

### Security Compliance
```powershell
# Security baseline assessment
.\HardwareInventory.ps1 -ComputerName (Get-Content .\security_scope.txt) -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputJsonl "\\compliance\security_baseline_$(Get-Date -Format 'yyyyMMdd').jsonl"
```

### SIEM Integration
```powershell
# Daily security posture feed
.\HardwareInventory.ps1 -ComputerName (Get-Content .\critical_systems.txt) -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputJsonl "\\siem\feeds\hardware_security_$(Get-Date -Format 'yyyyMMdd').jsonl"
```

## Best Practices

### Planning
- Start with small pilot groups to validate performance and results
- Document approved hardware configurations for comparison
- Establish regular collection schedules for trending analysis
- Coordinate with network teams for large-scale operations

### Execution
- Use verbose output for monitoring progress on large collections
- Implement retry logic for critical systems that fail initial collection
- Validate credentials before starting large-scale remote operations
- Monitor disk space for output files during extensive inventories

### Analysis
- Compare results against approved hardware baselines
- Track changes over time to identify unauthorized modifications
- Correlate hardware specifications with performance issues
- Use security flags to prioritize remediation efforts

## Troubleshooting

### Common Issues
- **WinRM Not Enabled**: Verify PowerShell Remoting configuration
- **Access Denied**: Confirm administrative privileges on target systems
- **Slow Performance**: Reduce throttle limit or collection scope
- **Missing Security Data**: Verify TPM/UEFI availability on target systems

### Optimization Tips
- Use `-Verbose` for detailed progress monitoring
- Test with single systems before large-scale deployment
- Consider network segments when planning collection strategy
- Implement error handling for production automation

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- WinRM enabled for remote collection
- Administrative privileges on target systems
- Network connectivity to target computers
- TPM/UEFI hardware for optional security features