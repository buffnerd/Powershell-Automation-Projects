# FilterSecurityLogs - Security Event Log Analysis

## Overview
Advanced PowerShell script for analyzing Windows Security event logs with focus on attack pattern detection, anomaly identification, and forensic timeline reconstruction.

## Key Features
- **Brute-force Detection**: Identifies failed logon patterns indicating potential attacks
- **Privilege Escalation Analysis**: Monitors special privilege usage (Event IDs 4672, 4673, 4674)
- **Account Management Tracking**: Audits user/group creation, modification, and deletion activities
- **Logon Pattern Analysis**: Comprehensive logon/logoff behavior analysis
- **Timeline Reconstruction**: Chronological security event sequencing for incident response
- **Multi-computer Support**: Concurrent analysis across multiple systems

## Usage Examples

### Brute-force Attack Detection
```powershell
# Detect brute-force attempts on domain controller with 5+ failed attempts
.\FilterSecurityLogs.ps1 -ComputerName DC01 -AnalysisType BruteForce -BruteForceThreshold 5 -OutputCsv .\bruteforce.csv

# Monitor multiple servers for brute-force activity
.\FilterSecurityLogs.ps1 -ComputerName @("DC01","DC02","Web01") -AnalysisType BruteForce -StartTime (Get-Date).AddHours(-24)
```

### Incident Response Timeline
```powershell
# Create detailed timeline for specific user investigation
.\FilterSecurityLogs.ps1 -AnalysisType Timeline -TargetUser "jdoe" -StartTime (Get-Date).AddDays(-3) -OutputTimeline .\jdoe_timeline.csv

# Computer-focused timeline for compromised system
.\FilterSecurityLogs.ps1 -AnalysisType Timeline -TargetComputer "WORKSTATION01" -OutputTimeline .\workstation_timeline.csv

# IP-based analysis for external attack investigation
.\FilterSecurityLogs.ps1 -AnalysisType Timeline -TargetIP "192.168.1.100" -OutputCsv .\ip_investigation.csv
```

### Comprehensive Security Analysis
```powershell
# Full analysis across infrastructure
.\FilterSecurityLogs.ps1 -ComputerName (Get-Content .\servers.txt) -AnalysisType All -StartTime (Get-Date).AddDays(-1) -OutputCsv .\security_analysis.csv -OutputSummaryJson .\security_summary.json

# Privilege escalation monitoring
.\FilterSecurityLogs.ps1 -AnalysisType PrivilegeEscalation -StartTime (Get-Date).AddHours(-12) -Verbose
```

## Analysis Types

### BruteForce
- Monitors Event ID 4625 (Failed logon attempts)
- Groups attempts by user/IP combination
- Configurable threshold for attack detection
- Reports attempt frequency, duration, and patterns

### PrivilegeEscalation
- Tracks Event IDs 4672, 4673, 4674 (Special privilege usage)
- Identifies unusual privilege assignments
- Monitors administrative privilege escalation

### AccountManagement
- Monitors Event IDs 4720-4781 (User/group management)
- Tracks account creation, modification, deletion
- Identifies unauthorized administrative activities

### LogonAnalysis
- Analyzes Event IDs 4624, 4634, 4647, 4648 (Logon/logoff patterns)
- Identifies unusual logon behaviors
- Maps user access patterns and frequency

### Timeline
- Comprehensive chronological event reconstruction
- Supports user, computer, or IP-based filtering
- Essential for incident response and forensic analysis

## Output Formats

### CSV Export (`-OutputCsv`)
Detailed event listing with timestamps, descriptions, and metadata for further analysis in Excel or other tools.

### JSON Summary (`-OutputSummaryJson`)
Structured summary with statistics, findings, and detailed analysis results suitable for SIEM integration.

### Timeline CSV (`-OutputTimeline`)
Chronologically ordered events with contextual information optimized for incident reconstruction.

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ComputerName` | String[] | Target computers for analysis | Local computer |
| `Credential` | PSCredential | Authentication for remote access | Current user |
| `StartTime` | DateTime | Analysis window start | 7 days ago |
| `EndTime` | DateTime | Analysis window end | Current time |
| `AnalysisType` | String | Type of analysis to perform | All |
| `TargetUser` | String | Specific user to focus analysis | None |
| `TargetComputer` | String | Specific computer to analyze | None |
| `TargetIP` | String | Specific IP address to investigate | None |
| `BruteForceThreshold` | Int | Minimum failed attempts for brute-force detection | 10 |
| `TimeWindow` | Int | Event grouping window in minutes | 60 |

## Event ID Reference

| Event ID | Description | Analysis Type |
|----------|-------------|---------------|
| 4624 | Successful logon | LogonAnalysis, Timeline |
| 4625 | Failed logon | BruteForce, Timeline |
| 4634 | Logoff | LogonAnalysis, Timeline |
| 4647 | User initiated logoff | LogonAnalysis, Timeline |
| 4648 | Explicit credential logon | LogonAnalysis, Timeline |
| 4672 | Special privileges assigned | PrivilegeEscalation, Timeline |
| 4673 | Privileged service called | PrivilegeEscalation, Timeline |
| 4674 | Operation attempted on privileged object | PrivilegeEscalation, Timeline |
| 4720 | User account created | AccountManagement, Timeline |
| 4722 | User account enabled | AccountManagement, Timeline |
| 4724 | Password reset attempt | AccountManagement, Timeline |
| 4726 | User account deleted | AccountManagement, Timeline |
| 4738 | User account changed | AccountManagement, Timeline |
| 4740 | User account locked out | AccountManagement, Timeline |

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- Administrative privileges for remote event log access
- WinRM enabled for remote computer analysis
- Appropriate NTFS permissions on target systems

## GUI Integration Points
Future GUI implementation will include:
- Analysis type selection (radio buttons/dropdown)
- Target specification (user/computer/IP input fields)
- Threshold configuration (sliders)
- Time range selection (date/time pickers)
- Progress indicators for multi-system analysis
- Real-time result visualization

## Security Considerations
- Requires appropriate privileges for event log access
- Consider impact of large-scale log queries on system performance
- Sensitive security data handling - ensure secure output storage
- Network traffic implications for remote log collection