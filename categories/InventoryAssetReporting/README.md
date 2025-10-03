# Inventory & Asset Reporting

Collect **hardware** and **software** inventories across Windows endpoints/servers. Outputs are flattened and SIEM/Excel/PowerBI-friendly.

---

## Prerequisites
- PowerShell Remoting (WinRM) enabled for remote collection (or run locally)
- Local admin / appropriate rights to query CIM/WMI and registry
- Sufficient disk space for CSV/JSONL exports

---

## Scripts

### 1) HardwareInventory.ps1
Collects manufacturer/model/serial, BIOS/UEFI, CPU/RAM, disk summaries, NIC IPv4s, OS build, and optional **TPM**, **Secure Boot**, and **BitLocker** summaries.

**Examples**
```powershell
# Fleet snapshot
.\HardwareInventory.ps1 -ComputerName (gc .\hosts.txt) -OutputCsv .\hw.csv

# Security posture bits included
.\HardwareInventory.ps1 -ComputerName PC-01,PC-02 -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputJsonl .\hw.jsonl
```

**Adjust for your environment**
- **Targets**: `-ComputerName` (array/file/AD query)
- **Security options**: `-IncludeTPM`, `-IncludeSecureBoot`, `-IncludeBitLocker`
- **Parallelism**: `-ThrottleLimit`
- **Exports**: `-OutputCsv`, `-OutputJsonl`
- **Credentials**: `-Credential`

### 2) SoftwareInventory.ps1
Enumerates installed products from Uninstall registry hives (both 64/32-bit), with optional filters and optional Windows Update (KB) rows.

**Examples**
```powershell
# Full inventory
.\SoftwareInventory.ps1 -ComputerName (gc .\hosts.txt) -OutputCsv .\sw.csv

# Vendor filter, versions >= 10.5 only
.\SoftwareInventory.ps1 -ComputerName app01 -PublisherContains "Acme" -MinVersion 10.5

# Include KBs and export JSONL
.\SoftwareInventory.ps1 -ComputerName desk01 -IncludeUpdates -OutputJsonl .\sw.jsonl
```

**Adjust for your environment**
- **Filters**: `-NameContains`, `-PublisherContains`, `-MinVersion`
- **Policy**: `-ExcludeSystemComponents` (default on)
- **Updates**: `-IncludeUpdates`
- **Exports**: `-OutputCsv`, `-OutputJsonl`
- **Parallelism**: `-ThrottleLimit`
- **Credentials**: `-Credential`

---

## Hardware Inventory Capabilities

### System Information
- **Hardware Details**: Manufacturer, Model, Serial Number, Chassis Type
- **BIOS/UEFI**: Version, Release Date, UEFI Mode Detection
- **Processor**: Name, Core Count, Logical Processor Count
- **Memory**: Total Physical RAM (GB)
- **Storage**: Disk count, total/free space summaries, media types (SSD/HDD)
- **Network**: Enabled NICs with IPv4 addresses

### Operating System Details
- **OS Information**: Caption, Edition, Version, Build Number
- **Installation Data**: Install Date, Last Boot Time
- **Update Status**: Current patch level and build information

### Security Posture (Optional)
- **TPM**: Presence, Ready State, Specification Version
- **Secure Boot**: UEFI Mode and Secure Boot Status
- **BitLocker**: Volume protection status summary per drive

## Software Inventory Capabilities

### Application Discovery
- **Registry-Based**: Reads from standard Uninstall registry hives
- **Architecture Support**: Both 64-bit and 32-bit (WOW6432Node) applications
- **MSI Products**: Product codes and uninstall strings
- **Estimated Size**: Installation footprint in MB

### Update Tracking
- **Windows Updates**: Optional KB number enumeration via Get-HotFix
- **Patch Level**: Integrated view of applications and updates
- **Installation Dates**: Historical installation timeline

### Filtering Capabilities
- **Name Filtering**: Substring matching on application names
- **Publisher Filtering**: Vendor-specific application discovery
- **Version Filtering**: Minimum version requirements
- **System Component Exclusion**: Hide OS components and dependencies

---

## Enterprise Features

### Parallel Processing
- **Throttled Execution**: Configurable concurrent connection limits
- **Resource Management**: Memory and network bandwidth optimization
- **Error Handling**: Graceful failure handling for unreachable systems
- **Progress Tracking**: Verbose output for large-scale operations

### Multi-Format Output
- **CSV Export**: Structured data for Excel analysis and reporting
- **JSONL Export**: Streaming JSON for SIEM and big data platforms
- **Console Display**: Immediate results with formatted tables
- **Error Logging**: Comprehensive error tracking and reporting

### Remote Execution
- **PowerShell Remoting**: Secure remote command execution
- **Credential Support**: Cross-domain and workgroup authentication
- **WinRM Optimization**: Efficient remote data collection
- **Network Resilience**: Timeout and retry mechanisms

---

## Common Use Cases

### Asset Management
- **Hardware Lifecycle**: Track system age, specifications, and replacement needs
- **Software Compliance**: Ensure licensed software deployment and usage
- **Security Baseline**: Monitor security feature adoption (TPM, Secure Boot, BitLocker)
- **Capacity Planning**: Analyze storage, memory, and processing requirements

### Security Operations
- **Vulnerability Management**: Identify unpatched systems and outdated software
- **Compliance Reporting**: Generate reports for security frameworks and audits
- **Incident Response**: Rapid inventory collection during security investigations
- **Risk Assessment**: Evaluate security posture across infrastructure

### IT Operations
- **Change Management**: Track software and hardware changes over time
- **Standardization**: Identify configuration drift and non-standard deployments
- **Migration Planning**: Document current state before infrastructure changes
- **Troubleshooting**: Correlate issues with hardware and software configurations

### Business Intelligence
- **Cost Optimization**: Identify underutilized resources and redundant software
- **Vendor Management**: Track software licensing and hardware warranties
- **Performance Analysis**: Correlate performance issues with system specifications
- **Strategic Planning**: Data-driven decisions for IT investments

---

## Performance Considerations

### Scanning Strategy
- **Throttle Limits**: Balance speed with system impact using `-ThrottleLimit`
- **Network Bandwidth**: Consider WAN links for remote site scanning
- **Target Grouping**: Organize scans by network segments or organizational units
- **Scheduling**: Run intensive scans during maintenance windows

### Data Volume Management
- **Output Size**: Monitor disk space for large-scale inventory exports
- **Network Transfer**: Consider compression for remote file storage
- **Database Integration**: Plan for ongoing data ingestion and retention
- **Historical Tracking**: Implement data lifecycle management strategies

### System Impact
- **Resource Usage**: Monitor CPU and memory consumption on target systems
- **Security Software**: Consider antivirus and EDR impact on WMI queries
- **Service Dependencies**: Ensure required services are running (WinRM, WMI)
- **User Impact**: Schedule scans to minimize disruption to end users

---

## Integration Examples

### SIEM Integration
```powershell
# Daily hardware posture feed
.\HardwareInventory.ps1 -ComputerName (Get-ADComputer -Filter * | Select-Object -ExpandProperty Name) -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputJsonl "\\siem-server\feeds\hardware_$(Get-Date -Format 'yyyyMMdd').jsonl"

# Software vulnerability feed
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\production_servers.txt) -ExcludeSystemComponents -OutputJsonl "\\siem-server\feeds\software_$(Get-Date -Format 'yyyyMMdd').jsonl"
```

### Asset Management Database
```powershell
# Weekly comprehensive inventory
$date = Get-Date -Format 'yyyyMMdd'
.\HardwareInventory.ps1 -ComputerName (Get-Content .\all_systems.txt) -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputCsv "\\assetdb-server\imports\hardware_$date.csv"
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\all_systems.txt) -IncludeUpdates -OutputCsv "\\assetdb-server\imports\software_$date.csv"
```

### Compliance Reporting
```powershell
# Security compliance scan
.\HardwareInventory.ps1 -ComputerName (Get-Content .\compliance_scope.txt) -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputCsv ".\compliance\security_posture_$(Get-Date -Format 'yyyyMM').csv"

# Software license compliance
.\SoftwareInventory.ps1 -ComputerName (Get-Content .\workstations.txt) -PublisherContains "Microsoft" -ExcludeSystemComponents -OutputCsv ".\compliance\microsoft_software_$(Get-Date -Format 'yyyyMM').csv"
```

---

## Tips
- **Avoid Win32_Product** (slow and intrusive). This toolkit uses registry hives for reliability.
- **Pair SoftwareInventory** with your UpdateSoftware pipeline to identify drift and out-of-date versions.
- **Use HardwareInventory security flags** (TPM/Secure Boot/BitLocker) to baseline endpoint security posture.
- **Start small** with pilot groups before enterprise-wide deployment
- **Monitor performance** and adjust throttle limits based on infrastructure capacity

---

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- WinRM enabled for remote collection
- Administrative privileges for comprehensive data collection
- Network connectivity to target systems
- Sufficient disk space for output files

---

## Future GUI Integration Ideas
- **Host picker** (file/AD OU) and credential prompt
- **Checkboxes** for TPM / SecureBoot / BitLocker / Updates
- **Filters** for vendor/name/min version with instant preview
- **Export "bundles"** (CSV + JSONL) per run
- **Progress visualization** with real-time status updates
- **Scheduling interface** for automated inventory collection
- **Dashboard integration** with live inventory status
- **Report generation** with customizable templates