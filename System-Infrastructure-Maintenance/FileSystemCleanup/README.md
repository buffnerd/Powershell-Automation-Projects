# FileSystemCleanup

## Overview
The FileSystemCleanup category provides comprehensive solutions for maintaining clean and efficient file systems in enterprise environments. These scripts help automate the removal of unnecessary files, archive old logs, and maintain optimal disk space usage while providing detailed reporting and safety mechanisms.

## Scripts

### CleanupTempFiles
**Purpose**: Safely remove temporary files from common Windows temp locations with advanced filtering and quarantine capabilities.

**Key Features**:
- Multi-location temp file scanning (Windows Temp, User profiles, IIS temp)
- Age and size-based filtering with customizable thresholds
- Quarantine functionality instead of immediate deletion
- Pattern-based inclusion/exclusion for precise control
- Comprehensive CSV reporting of all operations
- Dry-run mode for safe testing

**Typical Use Cases**:
- Daily maintenance of web servers and workstations
- Pre-deployment disk space cleanup
- Troubleshooting disk space issues
- Automated maintenance scheduling

### ArchiveOldLogs
**Purpose**: Compress old log files into organized ZIP archives while maintaining directory structure and providing size management.

**Key Features**:
- Intelligent log file discovery across multiple root paths
- Flexible archive organization (per-folder or date-bucketed)
- ZIP size management with automatic rollover
- Optional original file deletion after successful compression
- Detailed operation manifest and error logging
- Support for various log file formats (*.log, *.txt, *.etl, *.evtx)

**Typical Use Cases**:
- Automated log retention management
- Disk space optimization for log-heavy applications
- Compliance archival with structured organization
- Long-term log storage preparation

## Common Features Across Scripts

### Safety Mechanisms
- **Dry-Run Mode**: All scripts support preview functionality
- **Detailed Logging**: Comprehensive operation tracking and error reporting
- **Gradual Implementation**: Start with conservative settings and expand
- **Validation Checks**: Path verification and permission validation

### Enterprise Integration
- **CSV Reporting**: Structured output for audit trails and analysis
- **Error Handling**: Robust error management with detailed logging
- **Performance Optimization**: Efficient processing for large file sets
- **GUI Readiness**: Parameter structure designed for future GUI implementation

### Flexible Configuration
- **Pattern Matching**: Include/exclude patterns for precise file selection
- **Multi-Path Support**: Process multiple directories in single operations
- **Threshold Controls**: Age, size, and count-based filtering options
- **Network Path Support**: Works with UNC paths and remote locations

## Implementation Strategy

### Phase 1: Testing and Validation
1. **Start with Dry-Run**: Always use `-DryRun` parameter for initial testing
2. **Small Scope**: Begin with limited paths and conservative age thresholds
3. **Review Output**: Examine CSV reports and console output carefully
4. **Validate Results**: Confirm expected files are selected for processing

### Phase 2: Gradual Deployment
1. **Controlled Environment**: Test in non-production environments first
2. **Monitor Resources**: Watch disk space and system performance
3. **Incremental Settings**: Gradually expand scope and reduce age thresholds
4. **Backup Verification**: Ensure backup systems are functioning before cleanup

### Phase 3: Automation Integration
1. **Scheduled Tasks**: Integrate with Windows Task Scheduler
2. **Monitoring Integration**: Connect to existing monitoring systems
3. **Alert Configuration**: Set up notifications for unusual conditions
4. **Performance Tuning**: Optimize parameters based on actual usage patterns

## Best Practices

### File Selection
- **Conservative Ages**: Start with longer age thresholds (30+ days)
- **Pattern Testing**: Test include/exclude patterns thoroughly
- **Path Validation**: Verify all target paths exist and are accessible
- **Exception Handling**: Plan for locked files and permission issues

### Storage Management
- **Quarantine Space**: Ensure adequate space for quarantine operations
- **Archive Destinations**: Use separate volumes for archive storage
- **Network Considerations**: Account for bandwidth when using UNC paths
- **Cleanup Scheduling**: Avoid peak usage periods

### Monitoring and Reporting
- **Regular Reviews**: Examine operation reports for trends and issues
- **Threshold Monitoring**: Watch for unusual file accumulation patterns
- **Error Tracking**: Monitor error logs for systematic problems
- **Capacity Planning**: Use reports for future storage planning

## Future Enhancements

### GUI Development
All scripts are designed with future GUI implementation in mind:
- Parameter structures suitable for form controls
- Detailed help text for tooltip integration
- Validation logic for real-time feedback
- Progress reporting for user interface updates

### Additional Scripts
Planned additions to this category:
- **DiskSpaceAnalysis**: Detailed space usage reporting and analysis
- **DuplicateFileDetection**: Find and manage duplicate files
- **LargeFileReporting**: Identify unusually large files for review
- **SymlinkManagement**: Clean up broken symbolic links and junctions

### Integration Features
- **Central Configuration**: Shared configuration files for consistent settings
- **Database Logging**: Enhanced reporting with database integration
- **API Integration**: REST API for external system integration
- **PowerShell DSC**: Desired State Configuration for automated maintenance

## Troubleshooting

### Common Issues
- **Access Denied**: Ensure appropriate file system permissions
- **Path Not Found**: Verify network connectivity for UNC paths
- **Insufficient Space**: Check available disk space for quarantine/archive operations
- **Long Execution Times**: Consider reducing scope or adding progress reporting

### Diagnostic Commands
```powershell
# Check temp file accumulation
Get-ChildItem -Path $env:TEMP -Recurse -File | Measure-Object -Property Length -Sum

# Verify log file patterns
Get-ChildItem -Path "D:\Logs" -Include "*.log" -Recurse | Group-Object Directory

# Test path accessibility
Test-Path "\\server\share\logs" -PathType Container
```

### Performance Optimization
- Use `-MaxZipSizeMB` for large archive operations
- Implement file count limits for very large directories
- Consider breaking large operations into smaller batches
- Monitor system resources during execution

This category provides essential file system maintenance capabilities while maintaining enterprise-grade safety and reporting standards.