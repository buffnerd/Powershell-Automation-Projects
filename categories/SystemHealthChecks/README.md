# System Health Checks

Scripts to monitor **disk capacity**, **CPU/memory utilization**, and generate a **quick health report** across one or more Windows computers. These scripts are safe to run repeatedly and are designed for easy future GUI integration (all environment-specific settings are parameters).

---

## Prerequisites

- Windows PowerShell 5+ (or PowerShell 7 with compatibility)
- Remote hosts must allow **WinRM/CIM** queries (firewall + permissions)
- DNS name resolution to target computers
- Optional: Domain or local admin rights for service and registry checks

---

## Scripts

### 1) [DiskSpaceCheck.ps1](./DiskSpaceCheck/) ✅ **IMPLEMENTED**
Scan one or more hosts and flag volumes that fall below **free %** or **free GB** thresholds. Supports include/exclude drive letters and CSV export.

**Examples**
```powershell
# Local machine with defaults
.\DiskSpaceCheck.ps1

# Multiple servers with stricter thresholds, only show alerts, export to CSV
.\DiskSpaceCheck.ps1 -ComputerName server01,server02 -MinFreePercent 15 -MinFreeGB 10 -AlertOnly -OutputCsv .\disk_alerts.csv

# Use credentials and only check specific drives
.\DiskSpaceCheck.ps1 -ComputerName server01 -Credential (Get-Credential) -IncludeDrives 'C','E'
```

**Adjust for your environment:**
- `-ComputerName` list or file-based list
- `-Credential` for cross-domain or workgroup targets
- Thresholds: `-MinFreePercent`, `-MinFreeGB`
- `-IncludeDrives` / `-ExcludeDrives`
- Output path: `-OutputCsv`

### 2) [MemoryCpuMonitor.ps1](./MemoryCpuMonitor/) ✅ **IMPLEMENTED**
Sample CPU and Available Memory over time, compute averages and peaks, and show warnings when thresholds are breached.

**Examples**
```powershell
# Quick 30-second sample across many servers
.\MemoryCpuMonitor.ps1 -ComputerName (gc .\servers.txt) -DurationSeconds 30 -SampleIntervalSeconds 2

# Stricter thresholds with CSV export
.\MemoryCpuMonitor.ps1 -ComputerName server01 -DurationSeconds 120 -CpuWarnPercent 80 -MinAvailMB 2048 -OutputCsv .\perf.csv
```

**Adjust for your environment:**
- Sampling window: `-DurationSeconds`, `-SampleIntervalSeconds`
- Thresholds: `-CpuWarnPercent`, `-MinAvailMB`
- Credentials for remote sampling
- Output path: `-OutputCsv`

### 3) [HealthReport.ps1](./HealthReport/) ✅ **IMPLEMENTED**
One-stop system snapshot: OS, uptime, CPU/memory snapshot, disk alerts, pending reboot, and critical service state. Output to HTML or CSV.

**Examples**
```powershell
# HTML dashboard for a couple servers
.\HealthReport.ps1 -ComputerName server01,server02 -CriticalServices 'LanmanServer','Dnscache' -OutputHtml .\health.html

# CSV for a large fleet
.\HealthReport.ps1 -ComputerName (gc .\servers.txt) -OutputCsv .\health.csv -MinFreePercent 15 -MinFreeGB 10
```

**Adjust for your environment:**
- Target list: `-ComputerName` (array or file)
- Thresholds: `-CpuWarnPercent`, `-MinAvailMB`, `-MinFreePercent`, `-MinFreeGB`
- Services to check: `-CriticalServices`
- Output format/paths: `-OutputHtml`, `-OutputCsv`
- Credentials for remote hosts: `-Credential`

---

## Tips

- Start with a small target set to validate connectivity and permissions.
- Store server lists in plain text: `servers.txt` with one host per line → `-ComputerName (gc .\servers.txt)`.
- For cross-domain or workgroup machines, use `-Credential (Get-Credential)`.
- Consider a scheduled task to run `HealthReport.ps1` daily and drop the HTML to a share.

---

## Future GUI Integration Ideas

- Target picker (AD search, DNS validate)
- Threshold sliders
- Credential vault integration
- Export destinations (SharePoint, S3 via AWS Tools for PowerShell)
- Email alerts when warnings are present