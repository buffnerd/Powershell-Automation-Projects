# ExportAppliedGPOs

## Overview
Generate Resultant Set of Policy (RSoP) reports for computers and optionally for specific users, with remote execution capabilities and local copy-back functionality.

## Scripts
- **ExportAppliedGPOs.ps1** - Main script for generating RSoP reports in HTML and/or XML format

## Key Features
- **Remote Execution**: Runs gpresult.exe on target machines for accurate scoping and permissions
- **Dual Format Support**: Generate both HTML (human-readable) and XML (machine-readable) reports
- **User Scope Option**: Include specific user RSoP data alongside computer scope
- **Automatic Copy-back**: Optional local folder copying with per-computer organization
- **Batch Processing**: Support for multiple computers via pipeline or array input
- **Credential Support**: Cross-domain and workgroup authentication capabilities

## Environment Customization
- **Computer Selection**: Manual list, file input, or AD query integration for GUI
- **User Specification**: Domain\username or UPN with validation for GUI
- **Credential Management**: Secure credential prompt integration for GUI
- **Path Configuration**: Folder picker dialogs for remote and local paths
- **Overwrite Policy**: Checkbox with warning confirmation for GUI

## Usage Examples

### Local Computer Report
```powershell
.\ExportAppliedGPOs.ps1 -ExportHtml -ExportXml -CopyBackTo .\RSoP -Verbose
```

### Remote Computer with User Scope
```powershell
$cred = Get-Credential
.\ExportAppliedGPOs.ps1 -ComputerName 'PC-001' -User 'CONTOSO\jdoe' -Credential $cred -ExportHtml -CopyBackTo .\RSoP -Verbose
```

### Bulk Processing from File
```powershell
.\ExportAppliedGPOs.ps1 -ComputerName (Get-Content .\hosts.txt) -ExportXml -Verbose
```

### Pipeline Input
```powershell
Get-ADComputer -Filter "OperatingSystem -like '*Windows 10*'" | Select-Object -ExpandProperty Name | .\ExportAppliedGPOs.ps1 -ExportHtml -CopyBackTo .\RSoP
```

## Parameters
- **ComputerName**: Target computer(s), defaults to local machine
- **User**: Optional domain\username or UPN for user scope RSoP
- **Credential**: PSCredential for remote authentication
- **RemoteReportFolder**: Target folder path (default: C:\Windows\Temp\RSoP)
- **CopyBackTo**: Local folder for report copying with computer subfolders
- **ExportHtml**: Generate HTML report (human-readable)
- **ExportXml**: Generate XML report (machine-readable)
- **Force**: Overwrite existing reports on target

## Common Use Cases
1. **Audit Compliance** - Generate comprehensive policy reports for compliance reviews
2. **Change Review** - Document current policy state before and after changes
3. **Incident Response** - Capture policy configuration during security incidents
4. **Troubleshooting** - Diagnose policy application issues on specific computers
5. **Documentation** - Create policy documentation for change management

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- gpresult.exe available on target computers (Windows default)
- Local administrator rights on target computers (recommended)
- PowerShell Remoting (WinRM) enabled for remote execution
- Network access to target computers

## Security Considerations
- Uses PowerShell remoting for secure remote execution
- Credentials handled through secure PowerShell credential objects
- Reports stored in Windows temp directory on target by default
- Administrative share access required for copy-back functionality
- Comprehensive error handling for failed operations

## Error Handling
- Individual computer failures don't stop batch processing
- Detailed error reporting in results output
- Warning messages for copy-back failures
- Graceful handling of authentication failures
- Comprehensive logging with -Verbose support

## Output Format
Results table includes:
- **ComputerName**: Target computer processed
- **RemoteFiles**: Generated report file paths on target
- **CopiedTo**: Local destination folder (if copy-back enabled)
- **Status**: Operation result (OK/Error)
- **Message**: Error details for failed operations

## File Naming Convention
Reports use the format: `RSoP_COMPUTERNAME_[USERNAME_]TIMESTAMP.html/xml`
- Computer scope only: `RSoP_PC001_20251002_143022.html`
- With user scope: `RSoP_PC001_CONTOSO_jdoe_20251002_143022.html`