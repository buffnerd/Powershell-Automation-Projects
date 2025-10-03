# Log Collection & Analysis

## Overview
This category contains PowerShell scripts for collecting, parsing, and analyzing Windows event logs and other system logs for security monitoring, troubleshooting, and compliance reporting.

## Scripts

### CollectEventLogs/
- **Purpose**: Enterprise-grade event log collection from multiple systems
- **Features**: 
  - Multi-system parallel collection with throttling
  - Advanced filtering (time, event IDs, providers)
  - Multiple export formats (CSV, JSONL, raw EVTX)
  - Forensic-ready raw log file extraction
- **Use Cases**: SIEM data feeds, incident response, compliance auditing

### FilterSecurityLogs/
- **Purpose**: Advanced Security event log analysis and threat detection
- **Features**: 
  - Brute-force attack detection with configurable thresholds
  - Privilege escalation monitoring (Event IDs 4672-4674)
  - Account management activity tracking (Event IDs 4720-4781)
  - Logon pattern analysis and timeline reconstruction
  - Multi-computer forensic timeline generation
- **Use Cases**: Security incident response, threat hunting, forensic investigation

### Monitor-Failed-Logins/
- **Purpose**: Specialized failed login monitoring and analysis
- **Features**: Real-time monitoring, alerting, detailed reporting
- **Use Cases**: Brute-force detection, security monitoring

### Sentinel-Lab/
- **Purpose**: Microsoft Sentinel integration and lab environment
- **Features**: Sentinel workspace integration, sample data generation
- **Use Cases**: Security analytics, Sentinel testing, threat simulation

## Analysis Capabilities

### Security Event Analysis
- **Brute-force Detection**: Identify patterns of failed login attempts
- **Privilege Escalation**: Monitor special privilege usage and assignments
- **Account Management**: Track user/group creation, modification, deletion
- **Logon Analysis**: Comprehensive logon/logoff pattern analysis
- **Timeline Reconstruction**: Chronological event sequencing for investigations

### Export Formats
- **CSV**: Structured data for Excel analysis and reporting
- **JSONL**: JSON Lines format for SIEM ingestion and big data analytics
- **EVTX**: Raw Windows Event Log files for forensic tools
- **Timeline CSV**: Chronologically ordered events for incident reconstruction

### Enterprise Features
- **Multi-system Collection**: Concurrent log gathering across infrastructure
- **Throttled Parallelism**: Configurable connection limits for performance
- **Remote Authentication**: Credential support for domain environments
- **Error Handling**: Robust error management for large-scale operations

## Common Use Cases
- **Security Monitoring**: Automated collection and analysis of security events
- **Incident Response**: Rapid log collection and timeline reconstruction
- **Threat Hunting**: Proactive security analysis and pattern detection
- **Compliance Reporting**: Generate reports for regulatory requirements
- **Forensic Analysis**: Preserve and analyze logs for legal investigations
- **SIEM Integration**: Automated data feeds for security platforms

## Requirements
- Windows PowerShell 5.1+ or PowerShell Core 7+
- Administrative privileges for event log access
- WinRM enabled for remote log collection
- Network connectivity to target systems
- Sufficient disk space for log exports

## Performance Considerations
- Use throttling limits to prevent network congestion
- Implement time windows to control collection scope
- Consider MaxEventsPerHost limits for large environments
- Monitor disk space for EVTX exports

## Security Considerations
- Secure credential handling for remote access
- Encrypted transport for log collection
- Access control for sensitive log data
- Audit trails for collection activities

## GUI Integration Points
Future enhancements will include:
- Computer list management interfaces
- Event log channel selection dialogs
- Time range pickers with presets
- Analysis type selection (radio buttons/dropdowns)
- Progress indicators for multi-system operations
- Real-time result visualization and filtering