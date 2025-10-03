# Archive Old Logs - Automated Log File Compression

## Overview
The `ArchiveOldLogs.ps1` script provides a robust solution for compressing old log files into ZIP archives while maintaining source directory structure. It's designed for enterprise environments where log files accumulate rapidly and need systematic archival with proper controls and reporting.

## Features
- **Intelligent File Discovery**: Scans multiple root paths with customizable age thresholds and file patterns
- **Flexible Archive Structure**: Choose between per-folder archives or date-bucketed organization
- **Size Management**: Optional ZIP size limits with automatic rollover to prevent oversized archives
- **Safety Controls**: Dry-run mode, optional original file deletion, comprehensive error handling
- **Detailed Reporting**: CSV manifest of all operations and structured console output
- **Performance Optimized**: Efficient compression using .NET System.IO.Compression

## Parameters

### Path Configuration
- **`-Path`** (Required): One or more root directories to scan for log files
- **`-DestinationRoot`** (Required): Base directory where ZIP archives will be created

### File Selection
- **`-AgeDays`** (Default: 14): Only process files older than this many days
- **`-IncludePatterns`** (Default: "*.log","*.txt","*.etl","*.evtx"): File patterns to include
- **`-ExcludePatterns`**: File patterns to exclude (e.g., "*.current","*.lck")
- **`-ExcludePathLike`**: Directory path patterns to skip entirely

### Archive Organization
- **`-PerFolderZip`**: Create one ZIP per source folder (default behavior)
- **`-MaxZipSizeMB`** (Default: 0=unlimited): Maximum ZIP size before creating additional volumes

### Operations
- **`-DeleteOriginals`**: Remove source files after successful compression (OFF by default)
- **`-DryRun`**: Preview mode - shows what would be done without making changes

### Reporting
- **`-OutputCsv`**: Path to save detailed operation manifest
- **`-ErrorLog`**: Path to save error and warning messages

## Usage Examples

### Basic Archive Operation
```powershell
# Archive logs older than 30 days from multiple sources
.\ArchiveOldLogs.ps1 -Path "D:\Apps\Logs","\\fs01\Web\Logs" -AgeDays 30 -DestinationRoot "\\nas\archives" -Verbose
```

### Size-Controlled with Deletion
```powershell
# Create 500MB max archives and delete originals after compression
.\ArchiveOldLogs.ps1 -Path "D:\Logs" -AgeDays 7 -DestinationRoot "E:\LogArchive" -MaxZipSizeMB 500 -DeleteOriginals
```

### Comprehensive Preview
```powershell
# Preview with extended file types and path exclusions
.\ArchiveOldLogs.ps1 -Path "D:\Logs" -IncludePatterns "*.log","*.txt","*.evtx" -ExcludePathLike "*\active\*" -DryRun -OutputCsv "preview.csv"
```

### Date-Bucketed Archives
```powershell
# Organize archives by year-month instead of source folder
.\ArchiveOldLogs.ps1 -Path "D:\Logs" -DestinationRoot "E:\Archive" -AgeDays 14 -OutputCsv "manifest.csv"
```

## Archive Structure

### Per-Folder Mode (Default)
```
DestinationRoot\
├── Apps\Logs\
│   └── archive.zip
├── Web\Logs\
│   └── archive.zip
└── System\Events\
    └── archive.zip
```

### Date-Bucket Mode
```
DestinationRoot\
├── Apps\Logs\
│   ├── 2024-01\
│   │   └── archive_2024-01.zip
│   └── 2024-02\
│       └── archive_2024-02.zip
```

## Safety Features

### Dry-Run Protection
Always test with `-DryRun` first to verify file selection and archive structure:
```powershell
.\ArchiveOldLogs.ps1 -Path "D:\Logs" -DestinationRoot "E:\Archive" -DryRun -Verbose
```

### Gradual Deployment
1. Start without `-DeleteOriginals` to verify compression
2. Test with small `-AgeDays` values first
3. Use `-MaxZipSizeMB` to prevent oversized archives
4. Monitor `-OutputCsv` for operation details

### Error Handling
- Continues processing if individual files/folders fail
- Logs all errors to specified `-ErrorLog` file
- Uses `-ErrorAction SilentlyContinue` for robust enumeration
- Validates destination paths and creates as needed

## Performance Considerations
- **Large Directories**: Script handles thousands of files efficiently
- **Network Paths**: Works with UNC paths but consider network bandwidth
- **Compression**: Uses optimal compression level for best space savings
- **Memory Usage**: Processes files individually to minimize memory footprint

## GUI Integration Notes
Future GUI implementation considerations:
- **Path Selection**: Multi-select folder browser for source paths
- **Destination Picker**: Single folder browser with validation
- **Age Slider**: Numeric input with reasonable min/max (1-365 days)
- **Pattern Lists**: Editable include/exclude pattern collections
- **Archive Options**: Radio buttons for per-folder vs date-bucket organization
- **Size Control**: Numeric input for ZIP size limits
- **Safety Toggles**: Checkboxes for dry-run and delete-originals
- **Progress Display**: Real-time file count and compression progress
- **Results Grid**: Sortable display of manifest data

## Troubleshooting

### Common Issues
- **Access Denied**: Ensure script runs with appropriate file system permissions
- **Path Not Found**: Verify source paths exist and are accessible
- **Compression Failures**: Check disk space in destination and file locks
- **Large Memory Usage**: Use `-MaxZipSizeMB` to limit archive sizes

### Validation Commands
```powershell
# Check file selections before archiving
Get-ChildItem -Path "D:\Logs" -Recurse -File | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-14)} | Measure-Object

# Verify archive integrity
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::OpenRead("path\to\archive.zip").Entries | Measure-Object
```

## Related Scripts
This script complements other FileSystemCleanup category tools:
- **CleanupTempFiles.ps1**: For temporary file removal
- Future disk space management utilities
- Log rotation and retention policies