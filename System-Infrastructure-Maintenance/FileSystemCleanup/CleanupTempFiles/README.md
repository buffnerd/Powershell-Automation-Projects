# CleanupTempFiles

Safe and comprehensive temporary file cleanup with quarantine capabilities and detailed reporting.

## Overview

This PowerShell script provides enterprise-grade temporary file cleanup with intelligent filtering, safety mechanisms, and comprehensive reporting. It's designed to reclaim disk space while protecting critical files through configurable filters and optional quarantine functionality.

## Key Features

### Smart File Detection
- **Age-Based Filtering**: Target files older than specified days (1-3650 days)
- **Size Thresholds**: Focus on files above minimum size to maximize space recovery
- **Pattern Matching**: Include/exclude files using flexible wildcard patterns
- **System Protection**: Automatically excludes hidden and system files by default

### Safety Mechanisms
- **Dry Run Mode**: Preview operations without making changes
- **WhatIf Support**: PowerShell's built-in confirmation prompting
- **Quarantine Option**: Move files instead of deleting for safe recovery
- **Path Exclusions**: Skip protected directories with wildcard filters

### Comprehensive Reporting
- **CSV Manifest**: Detailed per-file action log with timestamps and results
- **Error Logging**: Separate error log for troubleshooting and auditing
- **Space Recovery**: Accurate reporting of bytes and MB freed
- **Success Tracking**: Clear indication of successful vs failed operations

## Script Parameters

### Path Configuration
- **Path**: Custom directories to scan (supports UNC and local paths)
- **IncludeSystemTemp**: Include standard Windows temp locations ($env:TEMP, C:\Windows\Temp)

### Filtering Options
- **AgeDays**: Minimum age in days for file candidates (default: 14, range: 1-3650)
- **MinSizeMB**: Minimum file size in MB (default: 1, range: 0-1048576)
- **IncludePatterns**: Wildcard patterns for files to include (e.g., "*.tmp", "*.log")
- **ExcludePatterns**: Wildcard patterns for files to exclude (e.g., "*.dmp", "*.evtx")
- **ExcludePathLike**: Directory path exclusions using wildcards

### Safety Controls
- **IncludeHiddenSystem**: Include hidden/system files (not recommended)
- **QuarantinePath**: Destination for quarantined files instead of deletion
- **DryRun**: Preview mode - no actual changes made
- **WhatIf**: PowerShell confirmation prompting

### Output Options
- **OutputCsv**: CSV file path for detailed action manifest
- **ErrorLog**: Text file path for error and warning messages

## Usage Examples

### Basic System Cleanup
```powershell
# Clean standard temp folders, files older than 14 days, minimum 5MB
.\CleanupTempFiles.ps1 -IncludeSystemTemp -MinSizeMB 5 -OutputCsv .\cleanup_results.csv -Verbose
```

### Custom Path Cleanup with Quarantine
```powershell
# Clean custom cache locations with quarantine safety
.\CleanupTempFiles.ps1 -Path "\\fileserver\Cache","D:\Build\_temp" -AgeDays 30 -ExcludePathLike "*\Protected\*" -QuarantinePath "E:\Quarantine\TempFiles" -OutputCsv .\cleanup_log.csv -Verbose
```

### Targeted File Type Cleanup
```powershell
# Clean only specific file types with preview
.\CleanupTempFiles.ps1 -Path "D:\ApplicationData" -IncludePatterns "*.tmp","*.log","*.bak" -ExcludePatterns "*.current" -DryRun -OutputCsv .\preview_results.csv
```

### Enterprise Bulk Cleanup
```powershell
# Large-scale cleanup with comprehensive logging
.\CleanupTempFiles.ps1 -Path "\\server1\temp","\\server2\cache","D:\TempData" -AgeDays 7 -MinSizeMB 10 -QuarantinePath "\\backup\quarantine\temp_cleanup" -OutputCsv ".\cleanup_$(Get-Date -Format 'yyyyMMdd').csv" -ErrorLog ".\cleanup_errors.log" -Verbose
```

### Development Environment Cleanup
```powershell
# Clean build artifacts and temporary files
.\CleanupTempFiles.ps1 -Path "D:\Source\ProjectA\bin","D:\Source\ProjectB\obj" -IncludePatterns "*.pdb","*.obj","*.tmp" -AgeDays 1 -MinSizeMB 0 -DryRun
```

## Filtering Logic

### Age Calculation
- Uses `LastWriteTime` property for age determination
- Configurable lookback period from 1 day to 10 years
- UTC-aware calculations for consistent behavior across time zones

### Size Thresholds
- Minimum size filtering to focus on impactful files
- Configurable from 0 MB (all files) to 1TB
- Helps avoid processing thousands of tiny files

### Pattern Matching
- **Include Patterns**: If specified, only files matching these patterns are considered
- **Exclude Patterns**: Files matching these patterns are always excluded
- **Path Exclusions**: Entire directory trees can be excluded using wildcards
- **System File Protection**: Hidden and system files excluded by default

## Safety and Recovery

### Quarantine Functionality
When `QuarantinePath` is specified:
- Files are moved instead of deleted
- Original directory structure is preserved under quarantine root
- Drive letters are preserved (e.g., C:\temp\file.txt → Quarantine\C\temp\file.txt)
- Enables complete recovery if needed

### Dry Run Capabilities
- **DryRun Parameter**: Independent preview mode
- **WhatIf Support**: PowerShell's built-in confirmation system
- **Candidate Preview**: See exactly what would be affected before execution
- **Impact Assessment**: Understand space recovery potential before execution

### Error Handling
- **Graceful Failures**: Individual file failures don't stop batch processing
- **Detailed Error Logging**: Specific error messages for troubleshooting
- **Enumeration Protection**: Continues processing even if directory access fails
- **Permission Handling**: Clear error reporting for access denied scenarios

## Output and Reporting

### CSV Manifest
Detailed per-file log including:
- **Path**: Full file path
- **SizeBytes**: Exact file size in bytes
- **LastWriteTime**: File's last modification timestamp
- **Action**: Operation performed (Delete, Quarantine, or DRYRUN variants)
- **Success**: Boolean success indicator
- **Message**: Error message if operation failed
- **QuarantinedTo**: Destination path if quarantined

### Summary Statistics
- **ItemsConsidered**: Total files evaluated
- **ItemsAffected**: Files successfully processed
- **BytesFreed**: Exact bytes recovered
- **MBFreed**: Megabytes recovered (rounded to 2 decimals)

### Error Logging
Separate error log captures:
- Timestamp of each error
- Detailed error messages
- Directory enumeration failures
- File operation failures

## Prerequisites

### System Requirements
- **PowerShell 3.0+**: Required for advanced cmdlets and file operations
- **File System Access**: Read/write permissions to target directories
- **Administrative Rights**: May be required for system temp directories
- **Disk Space**: Sufficient space for quarantine operations if used

### Permission Requirements
- **Read Access**: All target directories and their contents
- **Write Access**: Target directories for file deletion
- **Quarantine Access**: Write permissions to quarantine destination
- **Log File Access**: Write permissions for CSV and error log locations

## Performance Considerations

### Large Directory Optimization
- **Recursive Enumeration**: Efficient traversal of deep directory structures
- **Memory Management**: Streaming file processing to handle large datasets
- **Filter Early**: Pattern and age filtering applied during enumeration
- **Batch Operations**: Grouped file operations for improved performance

### Network Path Handling
- **UNC Support**: Full support for network paths and shares
- **Connection Reuse**: Efficient handling of network connections
- **Timeout Handling**: Graceful handling of network timeouts
- **Bandwidth Consideration**: Quarantine operations respect network limitations

## Security Considerations

### Access Control
- **Least Privilege**: Operates with minimum required permissions
- **Audit Trail**: Comprehensive logging of all operations
- **Safe Defaults**: Conservative settings to prevent accidental data loss
- **System Protection**: Automatic exclusion of critical system files

### Data Protection
- **Quarantine Safety**: Non-destructive option for uncertain scenarios
- **Recovery Capability**: Full recovery possible with quarantine option
- **Verification**: Success verification before considering files processed
- **Rollback**: Quarantine enables complete operation rollback

## Integration Scenarios

### Automated Maintenance
- **Task Scheduler**: Windows Task Scheduler for regular cleanup
- **SCCM Integration**: System Center Configuration Manager deployment
- **PowerShell DSC**: Desired State Configuration for ongoing maintenance
- **Group Policy**: Startup/shutdown script integration

### Monitoring Integration
- **CSV Analysis**: Results suitable for monitoring system ingestion
- **Error Alerting**: Error logs can trigger automated alerts
- **Space Tracking**: Recovery metrics support capacity management
- **Compliance Reporting**: Detailed logs support audit requirements

### Enterprise Deployment
- **Bulk Operations**: Efficient processing of multiple servers
- **Central Logging**: Centralized collection of cleanup results
- **Policy Enforcement**: Standardized cleanup policies across environment
- **Change Management**: Audit trails support change control processes

## Troubleshooting

### Common Issues
- **Access Denied**: Insufficient permissions to target directories
- **Path Not Found**: Invalid or inaccessible network paths
- **Quarantine Failures**: Insufficient space or permissions in quarantine location
- **Pattern Conflicts**: Include/exclude pattern interactions

### Diagnostic Steps
1. **Permission Testing**: Verify read/write access to all target paths
2. **Path Validation**: Confirm all specified paths exist and are accessible
3. **Space Verification**: Ensure adequate space for quarantine operations
4. **Pattern Testing**: Test include/exclude patterns with small datasets

### Resolution Strategies
- **Permission Elevation**: Run with appropriate administrative privileges
- **Path Correction**: Verify and correct invalid path specifications
- **Space Management**: Ensure adequate disk space for operations
- **Pattern Refinement**: Adjust filtering patterns based on test results

## Best Practices

### Planning and Testing
1. **Always Use Dry Run**: Test with -DryRun before actual execution
2. **Start Small**: Begin with limited scope and expand gradually
3. **Review Patterns**: Carefully design include/exclude patterns
4. **Verify Quarantine**: Ensure quarantine location has adequate space

### Operational Guidelines
1. **Regular Scheduling**: Implement consistent cleanup schedules
2. **Monitor Results**: Review cleanup logs and space recovery metrics
3. **Adjust Thresholds**: Tune age and size thresholds based on results
4. **Maintain Quarantine**: Regularly clean old quarantined files

### Risk Mitigation
1. **Use Quarantine**: Prefer quarantine over deletion for uncertain scenarios
2. **Backup Critical Data**: Ensure important data is properly backed up
3. **Test Patterns**: Thoroughly test filtering patterns before deployment
4. **Monitor Performance**: Watch for performance impact on busy systems

## GUI Development Readiness

The script architecture supports comprehensive GUI development:

### File and Path Management
- **Multi-Path Selector**: Checkbox list or tree view for path selection
- **Pattern Builder**: Visual pattern editor with preview functionality
- **Quarantine Browser**: Folder picker with space validation
- **Path Validation**: Real-time path existence and permission checking

### Filtering Configuration
- **Age Slider**: Intuitive age threshold selection with preview
- **Size Controls**: Numeric input with unit selection (KB/MB/GB)
- **Pattern Editor**: Syntax-highlighted pattern editor with validation
- **Exclusion Manager**: Visual exclusion rule builder and tester

### Safety and Preview
- **Dry Run Toggle**: Prominent dry run mode selector
- **Impact Preview**: Real-time preview of affected files and space recovery
- **Safety Warnings**: Visual indicators for potentially risky operations
- **Confirmation Dialogs**: Multi-level confirmation for destructive operations

### Results and Monitoring
- **Progress Tracking**: Real-time progress bars and status updates
- **Results Viewer**: Sortable, filterable results grid with export options
- **Error Display**: Integrated error viewer with resolution suggestions
- **Summary Dashboard**: Visual summary of operations and space recovery