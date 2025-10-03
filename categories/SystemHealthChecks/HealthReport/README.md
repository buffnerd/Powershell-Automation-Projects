# HealthReport.ps1 ✅ **IMPLEMENTED**

Generate a comprehensive health snapshot per computer including OS info, uptime, CPU/memory snapshot, disk alerts, pending reboot status, and critical service checks. Output to HTML dashboard or CSV for analysis.

## Features

- **Complete system overview**: OS, version, manufacturer, model, and uptime
- **Performance snapshot**: Current CPU and memory utilization
- **Disk space monitoring**: Integrated alerts for low disk space
- **Reboot detection**: Check for pending reboot indicators
- **Service monitoring**: Verify status of critical services
- **Flexible output**: HTML dashboard with styling or CSV for data analysis
- **Multi-computer support**: Monitor entire server fleets
- **Remote credentials**: Cross-domain and workgroup support

## Usage Examples

```powershell
# HTML dashboard for key servers with critical service checks
.\HealthReport.ps1 -ComputerName server01,server02 -CriticalServices 'LanmanServer','Dnscache' -OutputHtml .\health.html

# CSV report for large fleet with custom thresholds
.\HealthReport.ps1 -ComputerName (Get-Content .\servers.txt) -OutputCsv .\health.csv -MinFreePercent 15 -MinFreeGB 10

# Quick local system check with verbose output
.\HealthReport.ps1 -Verbose

# Remote monitoring with credentials and custom service list
.\HealthReport.ps1 -ComputerName server01 -Credential (Get-Credential) -CriticalServices 'MSSQLSERVER','IIS' -OutputHtml .\sql_health.html
```

## Environment Adjustments

- **Target inventory**: Configure `-ComputerName` with your server lists or AD queries
- **Service monitoring**: Customize `-CriticalServices` for your environment (e.g., 'MSSQLSERVER', 'IIS', 'Spooler')
- **Performance thresholds**: Set `-CpuWarnPercent` and `-MinAvailMB` based on your baselines
- **Disk thresholds**: Adjust `-MinFreePercent` and `-MinFreeGB` per your policies
- **Output formats**: Use `-OutputHtml` for dashboards, `-OutputCsv` for data analysis
- **Credentials**: Configure `-Credential` for cross-domain access

## Report Contents

### System Information
- Computer name, OS, version, manufacturer, model
- Uptime in days and last boot time

### Performance Metrics
- Current CPU utilization percentage
- Available memory in MB
- Warning flags for threshold breaches

### Health Indicators
- Disk space alerts with drive details
- Pending reboot status
- Critical service status (running/stopped/not found)

### Output Formats
- **HTML**: Styled dashboard with tables and visual indicators
- **CSV**: Structured data for analysis and trending
- **Console**: Formatted table output for immediate review

## Requirements

- PowerShell 5+ with CIM and performance counter access
- WinRM/CIM enabled for remote computers
- Appropriate permissions for system information and service queries
- Rights to access remote registry for reboot detection

**Status**: Fully implemented with comprehensive system health reporting capabilities.rt

**Summary:** Creates detailed system health reports that aggregate performance metrics, system diagnostics, and status information into comprehensive HTML or CSV reports. This script provides a holistic view of system health for documentation, troubleshooting, and capacity planning purposes.

## Status
Placeholder only. Script implementation is planned.

## Usage (future)
```powershell
# Example usage once implemented:
# .\HealthReport.ps1 -ComputerName "Server1" -ReportPath "C:\Reports\SystemHealth.html"
```