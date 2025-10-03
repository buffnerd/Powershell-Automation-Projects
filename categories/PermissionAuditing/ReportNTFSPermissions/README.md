# ReportNTFSPermissions - NTFS Permission Inventory & Risk Analysis

## Overview
Comprehensive PowerShell script for inventorying NTFS permissions across file systems with built-in risk detection and multiple export formats. Designed for security auditing, compliance reporting, and permission cleanup initiatives.

## Key Features
- **Multi-path Scanning**: Process multiple file system roots simultaneously
- **Risk Detection**: Automatic flagging of dangerous permission patterns
- **Flexible Depth Control**: Configurable recursion with depth limits
- **SID Resolution**: Optional name translation for improved readability
- **Multiple Outputs**: CSV, JSONL, and error logging capabilities
- **Performance Optimized**: Efficient scanning with error handling

## Risk Indicators

### Broad High Permissions
- **Everyone/Authenticated Users/Domain Users** with **Modify** or **FullControl**
- Configurable broad principal list via `-BroadPrincipals` parameter
- Configurable high rights threshold via `-HighRights` parameter

### Access Control Anomalies
- **Explicit Deny ACEs**: Potentially problematic deny entries
- **Inheritance Issues**: Disabled inheritance detection
- **Orphaned Accounts**: Unresolved SIDs from deleted accounts
- **Owner Anomalies**: Unusual ownership patterns

## Usage Examples

### Basic Permission Inventory
```powershell
# Single folder scan with basic output
.\ReportNTFSPermissions.ps1 -Path "D:\Data" -OutputCsv .\permissions.csv

# Multi-path scanning
.\ReportNTFSPermissions.ps1 -Path @("\\server1\share1", "\\server2\share2") -OutputCsv .\multi_scan.csv
```

### Comprehensive Analysis
```powershell
# Deep recursive scan with SID resolution
.\ReportNTFSPermissions.ps1 -Path "\\fs01\Projects" -Recurse -MaxDepth 4 -ResolveSIDs -OutputCsv .\ntfs_projects.csv -Verbose

# Include files in analysis (use with caution on large file systems)
.\ReportNTFSPermissions.ps1 -Path "D:\Shares" -Recurse -IncludeFiles -MaxDepth 2 -OutputJsonl .\detailed_scan.jsonl
```

### Risk-Focused Scanning
```powershell
# Custom risk parameters for specific environment
.\ReportNTFSPermissions.ps1 -Path "\\corp-fs\sensitive" -Recurse -BroadPrincipals @("Everyone","Domain Users","Authenticated Users","CORP\AllUsers") -HighRights @("Modify","FullControl") -OutputCsv .\risk_analysis.csv -ErrorLog .\scan_errors.log
```

## Parameters

### Core Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `Path` | String[] | Root paths to scan (UNC or local) | **Required** |
| `Recurse` | Switch | Enable recursive scanning | False |
| `MaxDepth` | Int | Maximum recursion depth (1-64) | 5 |
| `IncludeFiles` | Switch | Include file-level ACLs | False |

### Identity Resolution
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ResolveSIDs` | Switch | Resolve SIDs to account names | False |

### Risk Configuration
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `BroadPrincipals` | String[] | Principals considered "broad access" | Everyone, Authenticated Users, Domain Users |
| `HighRights` | String[] | Rights considered "high privilege" | Modify, FullControl |

### Output Options
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `OutputCsv` | String | CSV output file path | None |
| `OutputJsonl` | String | JSONL output file path | None |
| `ErrorLog` | String | Error log file path | None |

## Output Schema

### CSV/JSONL Fields
- **Path**: Full file system path
- **Owner**: Object owner (resolved or SID)
- **Principal**: Account with permissions (resolved or SID)
- **Rights**: Simplified permission level (Read, Write, Modify, FullControl, etc.)
- **AccessType**: Allow or Deny
- **InheritanceFlags**: Folder/file inheritance settings
- **PropagationFlags**: Inheritance propagation settings
- **IsInherited**: Whether permission is inherited
- **InheritanceOn**: Whether inheritance is enabled
- **Risk_BroadHigh**: Boolean flag for broad principals with high rights
- **Risk_Deny**: Boolean flag for Deny ACEs
- **Risk_Unresolved**: Boolean flag for unresolved SIDs

## Performance Considerations

### Scanning Strategy
- **Start Small**: Begin with single folders to validate performance
- **Depth Limits**: Use `-MaxDepth` to control scan scope and time
- **File Inclusion**: Avoid `-IncludeFiles` on large file systems initially
- **Network Impact**: Consider bandwidth when scanning UNC paths

### Memory Usage
- Large file systems generate substantial output data
- Monitor memory consumption during extensive scans
- Use file outputs rather than console display for large datasets

### SID Resolution Impact
- `-ResolveSIDs` can significantly slow scanning in large domains
- Test performance impact before large-scale operations
- Consider network latency to domain controllers

## Error Handling
- **Access Denied**: Gracefully handled with verbose logging
- **Path Not Found**: Continues with remaining paths
- **Network Issues**: Timeout handling for UNC paths
- **Permission Errors**: Detailed error logging when `-ErrorLog` specified

## Integration Examples

### Security Compliance
```powershell
# Monthly compliance scan
.\ReportNTFSPermissions.ps1 -Path (Get-Content .\corporate_shares.txt) -Recurse -MaxDepth 3 -ResolveSIDs -OutputCsv ".\compliance\ntfs_$(Get-Date -Format 'yyyyMM').csv" -ErrorLog ".\compliance\errors_$(Get-Date -Format 'yyyyMM').log"
```

### SIEM Integration
```powershell
# Daily SIEM feed
.\ReportNTFSPermissions.ps1 -Path @("\\fs01\finance","\\fs02\hr","\\fs03\legal") -Recurse -OutputJsonl "\\siem-server\logs\ntfs_permissions_$(Get-Date -Format 'yyyyMMdd').jsonl"
```

### Risk Assessment
```powershell
# High-risk area scan
.\ReportNTFSPermissions.ps1 -Path "\\finance-server\sensitive" -Recurse -BroadPrincipals @("Everyone","Authenticated Users","Domain Users","Finance\AllUsers") -HighRights @("Write","Modify","FullControl") -ResolveSIDs -OutputCsv .\finance_risks.csv
```

## Best Practices

### Security
- Run with least privilege necessary for the scan scope
- Secure storage of output files (contain sensitive security data)
- Consider encryption for permission reports
- Audit scanning activities

### Operational
- Coordinate large scans with system administrators
- Schedule intensive scans during off-peak hours
- Implement retry logic for network-dependent operations
- Monitor disk space for output files

### Analysis
- Start with risk-flagged items for immediate attention
- Cross-reference with business requirements
- Document approved exceptions to reduce false positives
- Establish regular scanning schedules

## Troubleshooting

### Common Issues
- **Access Denied**: Verify administrative privileges and network access
- **Slow Performance**: Reduce depth, disable SID resolution, or exclude files
- **Large Output**: Implement filtering or break into smaller scans
- **Network Timeouts**: Check connectivity and consider local scanning

### Optimization Tips
- Use `-Verbose` for detailed progress information
- Implement depth limits based on file system structure
- Consider parallel scanning of different root paths
- Cache results for repeated analysis

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- Administrative privileges for comprehensive ACL reading
- Network access for UNC path scanning
- Sufficient disk space for output files
- Domain connectivity for SID resolution (if enabled)