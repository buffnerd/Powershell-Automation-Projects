# SoftwareInventory - Registry-Based Application & Update Discovery

## Overview
High-performance PowerShell script for comprehensive software inventory across Windows systems using registry-based enumeration. Avoids the problematic Win32_Product WMI class while providing detailed application information, optional update tracking, and flexible filtering capabilities.

## Key Features
- **Registry-Based Discovery**: Fast, reliable enumeration without MSI reconfiguration risks
- **Multi-Architecture Support**: Both 64-bit and 32-bit application detection
- **Advanced Filtering**: Name, publisher, and version-based filtering
- **Update Integration**: Optional Windows Update (KB) enumeration
- **System Component Exclusion**: Intelligent filtering of OS components
- **Parallel Processing**: Throttled concurrent collection across multiple systems

## Software Discovery Methods

### Registry Sources
- **64-bit Applications**: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
- **32-bit Applications**: `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`
- **Windows Updates**: `Get-HotFix` cmdlet integration (optional)

### Data Collection Points
- **DisplayName**: Application name as shown in Programs and Features
- **DisplayVersion**: Version string from application manifest
- **Publisher**: Software vendor or manufacturer
- **InstallDate**: Installation timestamp (when available)
- **EstimatedSizeMB**: Installation footprint in megabytes
- **UninstallString**: Command line for application removal
- **ProductCode**: MSI product code for tracking and deployment

## Filtering Capabilities

### Content Filtering
- **Name Filtering**: Substring matching on application display names
- **Publisher Filtering**: Vendor-specific application discovery
- **Version Filtering**: Minimum version requirements for compliance

### System Component Management
- **Automatic Exclusion**: Filters out OS components and dependencies
- **SystemComponent Flag**: Respects MSI system component designation
- **ParentKeyName Detection**: Excludes child/update entries
- **DisplayName Validation**: Requires valid application names

## Usage Examples

### Basic Software Inventory
```powershell
# Complete local system inventory
.\SoftwareInventory.ps1 -OutputCsv .\local_software.csv

# Multiple systems from file
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\servers.txt) -OutputCsv .\server_software.csv

# Domain workstation inventory
.\SoftwareInventory.ps1 -ComputerName (Get-ADComputer -Filter "OperatingSystem -like '*Windows 10*'" | Select-Object -ExpandProperty Name) -OutputCsv .\workstation_software.csv
```

### Filtered Discovery
```powershell
# Specific vendor analysis
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\systems.txt) -PublisherContains "Microsoft" -OutputCsv .\microsoft_software.csv

# Version compliance check
.\SoftwareInventory.ps1 -ComputerName APP-01 -NameContains "Java" -MinVersion "1.8.0" -OutputCsv .\java_compliance.csv

# Multi-vendor security software audit
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\endpoints.txt) -PublisherContains "Symantec" -OutputCsv .\antivirus_inventory.csv
```

### Comprehensive Analysis
```powershell
# Full inventory including Windows Updates
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\critical_servers.txt) -IncludeUpdates -OutputJsonl .\complete_inventory.jsonl

# Security software with updates
.\SoftwareInventory.ps1 -ComputerName SECURITY-01 -IncludeUpdates -PublisherContains "McAfee" -OutputCsv .\security_software.csv

# Enterprise software compliance
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\enterprise_systems.txt) -ExcludeSystemComponents -MinVersion "2019.1.0" -OutputCsv .\enterprise_compliance.csv
```

## Parameters

### Core Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ComputerName` | String[] | Target computers for inventory | Local computer |
| `Credential` | PSCredential | Authentication for remote systems | Current user |

### Filtering Options
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `NameContains` | String | Substring filter for application names | All applications |
| `PublisherContains` | String | Substring filter for publishers | All publishers |
| `MinVersion` | Version | Minimum version requirement | All versions |

### Collection Scope
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `IncludeUpdates` | Switch | Include Windows Updates (KB numbers) | False |
| `ExcludeSystemComponents` | Switch | Filter out OS components | True |

### Performance & Output
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ThrottleLimit` | Int | Maximum concurrent connections | 8 |
| `OutputCsv` | String | CSV export file path | None |
| `OutputJsonl` | String | JSONL export file path | None |

## Output Schema

### Application Records
- **ComputerName**: Source system identifier
- **Type**: Record type (Product or Update)
- **DisplayName**: Application name
- **DisplayVersion**: Version string
- **Publisher**: Software vendor
- **InstallDate**: Installation timestamp
- **EstimatedSizeMB**: Installation size in megabytes
- **UninstallString**: Removal command line
- **ProductCode**: MSI product identifier

### Update Records (when `-IncludeUpdates`)
- **ComputerName**: Source system identifier
- **Type**: Always "Update"
- **DisplayName**: KB number (e.g., KB4567890)
- **DisplayVersion**: Update description
- **Publisher**: Always "Microsoft"
- **InstallDate**: Update installation date

## Performance Considerations

### Collection Strategy
- **Registry Speed**: Registry enumeration is significantly faster than WMI queries
- **Network Optimization**: Minimizes remote calls through efficient scriptblocks
- **Memory Management**: Streams results to avoid memory accumulation
- **Error Resilience**: Individual system failures don't impact overall collection

### Filtering Impact
- **Pre-filtering**: Server-side filtering reduces network traffic
- **Version Parsing**: Semantic version comparison for accurate filtering
- **Publisher Matching**: Case-insensitive substring matching
- **System Component Logic**: Intelligent exclusion of OS-level components

### Throttling Guidelines
- **Default (8)**: Balanced performance for most environments
- **High Performance (16-32)**: For robust infrastructure with fast networks
- **Conservative (4-6)**: For slower systems or limited bandwidth
- **Single (1)**: For troubleshooting or very constrained environments

## Integration Examples

### License Compliance
```powershell
# Microsoft Office inventory
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\all_workstations.txt) -NameContains "Office" -PublisherContains "Microsoft" -OutputCsv ".\compliance\office_licenses_$(Get-Date -Format 'yyyyMM').csv"

# Adobe Creative Suite tracking
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\design_workstations.txt) -PublisherContains "Adobe" -OutputCsv ".\compliance\adobe_licenses_$(Get-Date -Format 'yyyyMM').csv"
```

### Security Assessment
```powershell
# Antivirus software audit
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\endpoints.txt) -NameContains "antivirus" -OutputCsv ".\security\antivirus_deployment.csv"

# Java version compliance (security vulnerability management)
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\web_servers.txt) -NameContains "Java" -MinVersion "1.8.0.261" -OutputCsv ".\security\java_compliance.csv"
```

### Asset Management
```powershell
# Enterprise application inventory
.\SoftwareInventory.ps1 -ComputerName (Get-ADComputer -Filter * | Select-Object -ExpandProperty Name) -ExcludeSystemComponents -OutputJsonl "\\assetdb\feeds\software_$(Get-Date -Format 'yyyyMMdd').jsonl"

# Update status across infrastructure
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\production_servers.txt) -IncludeUpdates -OutputCsv "\\reports\update_status_$(Get-Date -Format 'yyyyMMdd').csv"
```

## Advantages Over Win32_Product

### Performance Benefits
- **No MSI Reconfiguration**: Avoids triggering MSI validation processes
- **Faster Execution**: Registry queries are significantly faster than WMI
- **Lower System Impact**: Minimal CPU and I/O overhead
- **Network Efficiency**: Reduced remote execution time

### Reliability Improvements
- **No Product Reconfiguration**: Eliminates risk of unintended MSI repairs
- **Consistent Results**: Registry data is stable and predictable
- **Better Error Handling**: More granular error control and reporting
- **Reduced Dependencies**: Fewer service and provider dependencies

## Filtering Strategies

### Publisher-Based Analysis
```powershell
# Security software vendors
$securityVendors = @("Symantec", "McAfee", "Trend Micro", "Kaspersky", "Bitdefender")
foreach ($vendor in $securityVendors) {
    .\SoftwareInventory.ps1 -ComputerName (Get-Content .\endpoints.txt) -PublisherContains $vendor -OutputCsv ".\security\$vendor_inventory.csv"
}
```

### Version Compliance Checking
```powershell
# Minimum version requirements for security
$requirements = @{
    "Java" = "1.8.0.261"
    "Adobe Flash" = "32.0.0.0"
    "Google Chrome" = "84.0.0.0"
}

foreach ($app in $requirements.Keys) {
    .\SoftwareInventory.ps1 -ComputerName (Get-Content .\workstations.txt) -NameContains $app -MinVersion $requirements[$app] -OutputCsv ".\compliance\$app_compliance.csv"
}
```

## Best Practices

### Planning
- Define filtering criteria based on business requirements
- Establish regular inventory schedules for change tracking
- Document approved software lists for compliance comparison
- Plan for data retention and historical analysis

### Execution
- Start with pilot groups to validate filtering effectiveness
- Use verbose output for progress monitoring on large collections
- Implement retry logic for critical system inventories
- Monitor network impact during large-scale operations

### Analysis
- Compare results against approved software baselines
- Track version changes to identify unauthorized installations
- Correlate with vulnerability databases for security assessment
- Generate exception reports for non-compliant systems

## Troubleshooting

### Common Issues
- **Empty Results**: Verify registry access permissions
- **Slow Performance**: Check network connectivity and reduce throttle limit
- **Missing Applications**: Review system component exclusion settings
- **Version Parsing Errors**: Validate version string formats

### Optimization Tips
- Use filtering to reduce output volume and improve performance
- Test filtering criteria with small groups before full deployment
- Consider time-based execution for different application categories
- Implement caching for repeated inventory operations

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- Registry read access on target systems
- WinRM enabled for remote collection
- Network connectivity to target computers
- Administrative privileges for comprehensive application detection