# Group Policy Management

Tools to export **applied GPOs (RSoP)** and to **detect policy conflicts** across an OU's inheritance chain.

---

## Prerequisites
- **RSAT – Group Policy Management** (GPMC) PowerShell module installed
- Permissions to read GPOs and, for RSoP, local admin on target computers (recommended)
- PowerShell Remoting (WinRM) enabled for remote execution

---

## Scripts

### 1) ExportAppliedGPOs.ps1
Generate **RSoP reports** (HTML/XML) for computers and optionally for a specific user on those machines. Runs **gpresult on the target** for accuracy, and can copy the reports back to a local folder.

**Examples**
```powershell
# Local machine (computer-scope) → HTML + XML → copy back to .\RSoP
.\ExportAppliedGPOs.ps1 -ExportHtml -ExportXml -CopyBackTo .\RSoP -Verbose

# Remote machine with user scope
$cred = Get-Credential
.\ExportAppliedGPOs.ps1 -ComputerName PC-001 -User CONTOSO\jdoe -Credential $cred -ExportHtml -CopyBackTo .\RSoP -Verbose
```

**Adjust for your environment**
- Target set: `-ComputerName` (or file/AD-driven list)
- User scope: `-User` (domain\sam or UPN)
- Credentials: `-Credential` for cross-domain/workgroup hosts
- Paths: `-RemoteReportFolder` and `-CopyBackTo`
- Overwrite behavior: `-Force`

### 2) DetectGPConflicts.ps1
Analyze an OU's linked GPOs and flag registry-backed policy conflicts (same key/value set differently). Reports the winning GPO by link precedence and exports to CSV/HTML.

**Examples**
```powershell
# Full conflict scan with exports
.\DetectGPConflicts.ps1 -TargetOU "OU=Workstations,OU=Corp,DC=contoso,DC=com" -OutputCsv .\gpo_conflicts.csv -OutputHtml .\gpo_conflicts.html -Verbose

# User-config only
.\DetectGPConflicts.ps1 -TargetOU "OU=Sales,DC=contoso,DC=com" -IncludeComputer:$false -IncludeUser:$true -Verbose
```

**Adjust for your environment**
- OU DN: `-TargetOU` (use an OU picker in the GUI)
- Domain (optional): `-Domain`
- Scope toggles: `-IncludeComputer`, `-IncludeUser`
- Enforced filter (rare): `-IncludeEnforcedOnly`
- Exports: `-OutputCsv`, `-OutputHtml`

---

## Common Workflows

### Policy Auditing & Compliance
1. **Generate RSoP Reports**: Use `ExportAppliedGPOs.ps1` to capture current applied policies
2. **Detect Conflicts**: Run `DetectGPConflicts.ps1` to identify policy conflicts in inheritance chain
3. **Documentation**: Export both HTML reports for compliance documentation
4. **Remediation**: Use conflict analysis to clean up redundant or conflicting policies

### Change Management
1. **Pre-Change Baseline**: Export RSoP reports before policy changes
2. **Conflict Analysis**: Identify potential conflicts before implementing new policies
3. **Post-Change Validation**: Generate new RSoP reports to verify changes
4. **Impact Assessment**: Compare before/after reports to document changes

### Troubleshooting
1. **Problem Identification**: Use RSoP to see what policies are actually applied
2. **Conflict Resolution**: Identify conflicting policies causing unexpected behavior
3. **Scope Verification**: Confirm user vs computer policy application
4. **Precedence Analysis**: Understand which GPOs are winning in conflicts

---

## Tips & Best Practices

### RSoP Generation
- Use `ExportAppliedGPOs` to validate what a specific computer/user is actually receiving before remediating conflicts
- Always run gpresult on the target machine for accurate scoping and permissions
- Copy reports back locally for easier analysis and archival
- Include both HTML (human-readable) and XML (machine-readable) formats

### Conflict Detection
- Run `DetectGPConflicts` regularly as part of policy maintenance
- Focus on registry-backed Administrative Template policies (most common conflicts)
- Use enforced links sparingly to avoid complex precedence scenarios
- Export to both CSV (for data analysis) and HTML (for stakeholder reports)

### Environment Integration
- If you need site or domain linked GPOs included, extend the conflict script to merge inheritance from Site → Domain → OU
- For Security Settings or Group Policy Preferences (GPP) conflict checks, extend XML parsing beyond Registry policy sections
- Consider automation for regular conflict scanning in large environments
- Integrate with change management processes for policy validation

### GUI Development Considerations
Both scripts are designed for easy GUI integration with:
- **OU/Computer Pickers**: Tree view controls for AD object selection
- **Credential Management**: Secure credential prompt dialogs
- **File Operations**: Folder picker dialogs for input/output paths
- **Progress Indicators**: Long-running operations with progress feedback
- **Results Display**: Tabular data with export capabilities

---

## Security & Permissions

### Required Permissions
- **RSoP Generation**: Local administrator on target computers (recommended)
- **Conflict Detection**: Read access to GPOs and OU inheritance information
- **Remote Operations**: PowerShell remoting enabled (WinRM)
- **Cross-Domain**: Appropriate trust relationships and credentials

### Security Considerations
- RSoP reports contain sensitive policy configuration information
- Store exported reports securely and limit access appropriately
- Use secure credential handling for cross-domain operations
- Consider encryption for reports containing sensitive configuration data

---

## Future Enhancements

### Extended Conflict Detection
- **Security Policy Conflicts**: Local Security Policy settings analysis
- **Group Policy Preferences**: GPP conflicts and precedence
- **Script Policy Conflicts**: Startup/shutdown/logon/logoff scripts
- **Site/Domain Inheritance**: Full inheritance chain analysis

### Advanced RSoP Features
- **WMI Filter Analysis**: Include WMI filter evaluation results
- **Security Group Filtering**: Analyze security group policy filtering
- **Loopback Processing**: Handle loopback policy scenarios
- **Cross-Forest Scenarios**: Multi-forest policy analysis

### Automation & Integration
- **Scheduled Scanning**: Automated conflict detection workflows
- **Change Detection**: Alert on new conflicts after policy changes
- **Baseline Comparison**: Compare current state against approved baselines
- **Integration APIs**: REST endpoints for enterprise integration