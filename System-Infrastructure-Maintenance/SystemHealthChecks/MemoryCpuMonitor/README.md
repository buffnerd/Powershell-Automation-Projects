# MemoryCpuMonitor.ps1 ✅ **IMPLEMENTED**

Sample CPU and Available Memory over time, compute averages and peaks, and show warnings when thresholds are breached. Perfect for performance baseline tracking and capacity planning.

## Features

- **Time-based sampling**: Configure duration and interval for flexible monitoring windows
- **Multi-computer support**: Monitor multiple servers simultaneously
- **Statistical analysis**: Calculate averages, minimums, and maximums
- **Warning thresholds**: Customizable CPU and memory alert levels
- **Remote credentials**: Support for cross-domain monitoring
- **CSV export**: Generate reports for trend analysis and documentation
- **Verbose logging**: Detailed progress tracking during monitoring

## Usage Examples

```powershell
# Quick 30-second sample across multiple servers
.\MemoryCpuMonitor.ps1 -ComputerName (Get-Content .\servers.txt) -DurationSeconds 30 -SampleIntervalSeconds 2

# Detailed monitoring with stricter thresholds and CSV export
.\MemoryCpuMonitor.ps1 -ComputerName server01 -DurationSeconds 120 -CpuWarnPercent 80 -MinAvailMB 2048 -OutputCsv .\perf.csv

# Remote monitoring with credentials
.\MemoryCpuMonitor.ps1 -ComputerName server01,server02 -Credential (Get-Credential) -DurationSeconds 60 -Verbose
```

## Environment Adjustments

- **Sampling parameters**: Adjust `-DurationSeconds` and `-SampleIntervalSeconds` based on your monitoring needs
- **Thresholds**: Set `-CpuWarnPercent` and `-MinAvailMB` according to your performance baselines
- **Target scope**: Modify `-ComputerName` for your server inventory
- **Credentials**: Use `-Credential` for remote access as needed
- **Output location**: Configure `-OutputCsv` path for automated reporting

## Requirements

- PowerShell 5+ with performance counter access
- Performance counter services enabled on target systems
- Remote permissions and firewall rules for cross-computer monitoring
- Adequate rights to query performance counters remotely

## Output

The script provides comprehensive performance data including:
- Average and maximum CPU utilization percentages
- Average and minimum available memory in MB
- Warning flags when thresholds are exceeded
- Sample count and monitoring duration for reference

**Status**: Fully implemented with enterprise-grade performance monitoring capabilities.onitor

**Summary:** Provides real-time monitoring of system memory and CPU utilization with configurable alerting thresholds. This script helps identify performance bottlenecks and resource constraints before they impact system availability, making it essential for proactive system administration.

## Status
Placeholder only. Script implementation is planned.

## Usage (future)
```powershell
# Example usage once implemented:
# .\MemoryCpuMonitor.ps1 -ComputerName "Server1" -CpuThreshold 85 -MemoryThreshold 90
```