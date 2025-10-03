# DiskSpaceCheck.ps1 ✅ **IMPLEMENTED**

Scan one or more Windows hosts and flag volumes that fall below **free %** or **free GB** thresholds. Supports include/exclude drive letters, remote computers via CIM sessions, and CSV export.

## Features

- **Multi-computer support**: Query local or remote Windows computers
- **Flexible thresholds**: Set minimum free percentage and/or GB limits
- **Drive filtering**: Include/exclude specific drive letters
- **Remote credentials**: Support for cross-domain or workgroup scenarios
- **Alert-only mode**: Show only volumes breaching thresholds
- **CSV export**: Generate reports for documentation or further analysis
- **Safe execution**: Proper session cleanup and error handling

## Usage Examples

```powershell
# Local machine with defaults (10% free, 5GB minimum)
.\DiskSpaceCheck.ps1

# Multiple servers with stricter thresholds, only show alerts
.\DiskSpaceCheck.ps1 -ComputerName server01,server02 -MinFreePercent 15 -MinFreeGB 10 -AlertOnly -OutputCsv .\disk_alerts.csv

# Use credentials and only check specific drives
.\DiskSpaceCheck.ps1 -ComputerName server01 -Credential (Get-Credential) -IncludeDrives 'C','E'

# Check servers from file with verbose output
.\DiskSpaceCheck.ps1 -ComputerName (Get-Content .\servers.txt) -Verbose
```

## Environment Adjustments

- **Target list**: Modify `-ComputerName` for your server inventory
- **Credentials**: Use `-Credential` for cross-domain or workgroup targets
- **Thresholds**: Adjust `-MinFreePercent` and `-MinFreeGB` per your policies
- **Drive scope**: Use `-IncludeDrives` or `-ExcludeDrives` for specific requirements
- **Output location**: Set `-OutputCsv` path for automated reporting

## Requirements

- PowerShell 5+ with CIM cmdlets
- WinRM/CIM enabled on remote hosts
- Firewall allows remote management ports
- Appropriate permissions to query WMI/CIM remotely
- DNS resolution to target computers

**Status**: Fully implemented with comprehensive disk space monitoring capabilities.