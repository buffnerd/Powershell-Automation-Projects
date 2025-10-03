# CollectEventLogs - Comprehensive Event Log Collection

## Overview
Enterprise-grade PowerShell script for collecting Windows event logs from multiple systems with advanced filtering, parallel processing, and multiple export formats including raw EVTX files for forensic analysis.

## Key Features
- **Multi-system Collection**: Parallel event log gathering from multiple computers
- **Advanced Filtering**: Time-based, event ID, and provider-based filtering
- **Multiple Export Formats**: CSV, JSONL, and raw EVTX file export
- **Throttled Parallelism**: Configurable concurrent connection limits
- **Forensic Support**: Raw EVTX file extraction for offline analysis
- **Enterprise Scale**: Handles large-scale log collection efficiently

## Usage Examples

### Basic Log Collection
```powershell
# Collect last 24 hours of Security events for specific event IDs
.\CollectEventLogs.ps1 -ComputerName DC01,App01 -Channels Security -EventId 4624,4625 -OutputCsv .\auth.csv -Verbose

# Multi-channel collection from server list
.\CollectEventLogs.ps1 -ComputerName (Get-Content .\servers.txt) -Channels Application,System,Security -OutputJsonl .\enterprise_logs.jsonl
```

### Forensic Collection
```powershell
# Complete forensic collection with EVTX files
.\CollectEventLogs.ps1 -ComputerName (Get-Content .\hosts.txt) -Channels Application,System -StartTime (Get-Date).AddDays(-7) -OutputJsonl .\logs.jsonl -ExportEvtx -EvtxOutputFolder .\forensic_evtx -Verbose

# Security-focused forensic collection
.\CollectEventLogs.ps1 -ComputerName SUSPECT-PC01 -Channels Security -Provider "Microsoft-Windows-Security-Auditing" -ExportEvtx -EvtxOutputFolder .\incident_evtx
```

### Large-Scale Enterprise Collection
```powershell
# Enterprise-wide collection with throttling
.\CollectEventLogs.ps1 -ComputerName (Get-Content .\all_servers.txt) -Channels System,Application -MaxEventsPerHost 1000 -ThrottleLimit 10 -OutputCsv .\enterprise_health.csv

# Targeted provider collection
.\CollectEventLogs.ps1 -ComputerName @("Web01","Web02","Web03") -Channels Application -Provider "IIS-APPL","ASP.NET" -StartTime (Get-Date).AddHours(-4) -OutputJsonl .\web_logs.jsonl
```

## Parameters

### Core Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ComputerName` | String[] | Target computers for log collection | Local computer |
| `Credential` | PSCredential | Authentication for remote access | Current user |
| `Channels` | String[] | Event log channels to collect | System, Application |
| `EventId` | Int[] | Specific event IDs to include | All events |
| `Provider` | String[] | Event providers to include | All providers |

### Time Window Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `StartTime` | DateTime | Collection window start | 24 hours ago |
| `EndTime` | DateTime | Collection window end | Current time |

### Output Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `OutputCsv` | String | CSV output file path | .\events.csv (if no output specified) |
| `OutputJsonl` | String | JSONL output file path | None |
| `ExportEvtx` | Switch | Enable EVTX file export | False |
| `EvtxOutputFolder` | String | EVTX files destination folder | .\evtx |

### Performance Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `MaxEventsPerHost` | Int | Event limit per computer (0=unlimited) | 0 |
| `ThrottleLimit` | Int | Max concurrent connections | 6 |

## Channel Reference

### Standard Windows Channels
- **System**: Hardware, driver, and system service events
- **Application**: Application-specific events and errors
- **Security**: Authentication, authorization, and audit events
- **Setup**: Installation and update events

### Common Provider Examples
- **Microsoft-Windows-Security-Auditing**: Security audit events
- **Microsoft-Windows-Kernel-General**: Kernel-level events
- **IIS-APPL**: IIS application events
- **ASP.NET**: ASP.NET application events
- **Microsoft-Windows-TaskScheduler**: Scheduled task events

## Output Formats

### CSV Export
Structured tabular format with columns:
- ComputerName
- Channel
- RecordId
- TimeCreated
- Id (Event ID)
- Provider
- LevelDisplayName
- TaskDisplayName
- KeywordsDisplay
- Message

### JSONL Export
JSON Lines format with one JSON object per line, suitable for:
- SIEM ingestion
- Big data analytics
- Log management platforms
- Custom parsing tools

### EVTX Export
Raw Windows Event Log files for:
- Forensic analysis tools
- Offline investigation
- Evidence preservation
- Advanced analysis software

## Performance Considerations

### Throttling
- Default throttle limit of 6 concurrent connections
- Adjust based on network capacity and target system load
- Higher throttle limits increase speed but may impact performance

### Event Limits
- `MaxEventsPerHost` prevents overwhelming output
- Consider system resources when setting high limits
- Use time windows to control collection scope

### Network Impact
- EVTX export requires administrative shares access
- Large collections generate significant network traffic
- Consider bandwidth limitations in distributed environments

## Error Handling
- Comprehensive error logging for failed connections
- Individual computer failures don't stop overall collection
- Network timeouts and access denials are gracefully handled
- Failed EVTX exports logged as warnings

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- WinRM enabled for remote collection
- Administrative privileges for EVTX export
- Network connectivity to target systems
- Sufficient disk space for output files

## GUI Integration Points
Future GUI implementation will include:
- Computer list management (add/remove/import from file)
- Channel multi-select with descriptions
- Event ID and Provider selection dialogs
- Time range pickers with presets
- Output format selection and folder pickers
- Progress bars with per-computer status
- Throttle limit slider with performance guidance
- Real-time log preview and filtering

## Security Considerations
- Credential handling for remote access
- Secure storage of collected sensitive logs
- Network encryption for log transport
- Access control for output files
- Audit trail for collection activities

## Integration Examples

### SIEM Integration
```powershell
# Daily SIEM feed generation
.\CollectEventLogs.ps1 -ComputerName (Get-ADComputer -Filter * | Select-Object -ExpandProperty Name) -Channels Security,System -StartTime (Get-Date).AddDays(-1) -OutputJsonl "\\siem-server\logs\daily_$(Get-Date -Format 'yyyyMMdd').jsonl"
```

### Incident Response
```powershell
# Rapid incident collection
.\CollectEventLogs.ps1 -ComputerName $SuspectComputers -Channels Security,System,Application -EventId 4624,4625,4648,4672 -StartTime $IncidentStart -EndTime $IncidentEnd -ExportEvtx -EvtxOutputFolder "\\forensic-server\cases\$CaseNumber\evtx"
```