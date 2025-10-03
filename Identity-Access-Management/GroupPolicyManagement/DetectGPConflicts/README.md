# DetectGPConflicts

## Overview
Analyze Group Policy Objects linked to an OU and detect registry-backed policy conflicts where the same registry key/value is configured differently across multiple GPOs.

## Scripts
- **DetectGPConflicts.ps1** - Main script for detecting and reporting GPO policy conflicts

## Key Features
- **Inheritance Chain Analysis**: Builds effective link order for complete OU inheritance
- **Registry Policy Extraction**: Parses GPO XML reports for Administrative Template settings
- **Conflict Detection**: Identifies same key/value pairs with different data across GPOs
- **Precedence Analysis**: Determines winning GPO based on link order and enforcement
- **Dual Export Formats**: CSV for data analysis and HTML for human-readable reports
- **Scope Filtering**: Separate analysis for Computer and User configurations

## Environment Customization
- **OU Selection**: Distinguished Name picker with tree view for GUI
- **Domain Selection**: Dropdown list of available domains for GUI
- **Scope Toggles**: Checkboxes for Computer/User configuration inclusion
- **Enforcement Filter**: Checkbox for enforced-only link analysis
- **Export Destinations**: File save dialogs for CSV and HTML output

## Usage Examples

### Full Conflict Analysis with Exports
```powershell
.\DetectGPConflicts.ps1 -TargetOU "OU=Workstations,OU=Corp,DC=contoso,DC=com" -OutputCsv .\gpo_conflicts.csv -OutputHtml .\gpo_conflicts.html -Verbose
```

### User Configuration Only
```powershell
.\DetectGPConflicts.ps1 -TargetOU "OU=Sales,DC=contoso,DC=com" -IncludeComputer:$false -IncludeUser:$true -Verbose
```

### Cross-Domain Analysis
```powershell
.\DetectGPConflicts.ps1 -TargetOU "OU=Servers,DC=subsidiary,DC=com" -Domain "subsidiary.com" -OutputHtml .\conflicts.html
```

### Enforced Links Only
```powershell
.\DetectGPConflicts.ps1 -TargetOU "OU=Kiosks,DC=contoso,DC=com" -IncludeEnforcedOnly -Verbose
```

## Parameters
- **TargetOU**: Distinguished Name of the OU to analyze (required)
- **Domain**: Optional AD domain DNS name (defaults to current domain)
- **IncludeEnforcedOnly**: Filter to only enforced links (rare usage)
- **IncludeComputer**: Include Computer Configuration analysis (default: true)
- **IncludeUser**: Include User Configuration analysis (default: true)
- **OutputCsv**: Path for CSV export of conflicts
- **OutputHtml**: Path for HTML export with styling

## Common Use Cases
1. **Pre-Change Analysis** - Identify conflicts before GPO modifications
2. **Policy Cleanup** - Find redundant or conflicting policy configurations
3. **Troubleshooting** - Determine why policies aren't applying as expected
4. **Compliance Review** - Document policy conflicts for audit purposes
5. **Change Management** - Validate policy precedence after OU restructuring

## Prerequisites
- PowerShell 5.0+ or PowerShell 7+
- RSAT Group Policy Management Console (GPMC) PowerShell module
- GroupPolicy PowerShell module (`Import-Module GroupPolicy`)
- Read permissions on GPOs and OU link information
- Active Directory domain access

## Analysis Scope
- **Registry Policies**: Administrative Template settings (Computer/User)
- **Link Order**: Respects OU inheritance and link precedence
- **Enforcement**: Considers enforced/non-enforced link status
- **Multiple Values**: Detects different data for same registry location

## Limitations & Extensions
- **Current Focus**: Registry-backed Administrative Template policies only
- **Potential Extensions**:
  - Security Policy conflicts (Local Security Policy settings)
  - Group Policy Preferences (GPP) conflicts
  - Script policy conflicts
  - Site and Domain level inheritance (currently OU-focused)

## Output Format

### CSV Export
Contains columns:
- **Scope**: Computer or User configuration
- **Hive**: Registry hive (HKLM, HKCU, etc.)
- **Key**: Registry key path
- **ValueName**: Registry value name
- **ValueData**: Configured value data
- **GPO**: GPO display name
- **Enforced**: Link enforcement status
- **LinkOrder**: Processing order
- **WinnerGPO**: GPO that wins precedence
- **WinnerData**: Winning value data
- **Conflict**: Boolean indicating if this entry conflicts

### HTML Export
Styled report with:
- Professional formatting with CSS styling
- Sortable conflict data
- Color coding for conflict highlighting
- Report metadata (target OU, generation time)
- Responsive design for various screen sizes

## Error Handling
- Graceful module dependency checking
- Individual GPO analysis failures don't stop processing
- Comprehensive error messages with context
- Warning notifications for missing data
- Validation of input parameters

## Performance Considerations
- XML parsing can be intensive for large GPOs
- Link order analysis scales with OU inheritance depth
- Memory usage increases with GPO count and policy complexity
- Consider batching for very large environments

## Security Considerations
- Requires AD read permissions only
- No modification capabilities reduce risk
- XML processing handles malformed GPO reports gracefully
- Credential requirements match standard GPMC access