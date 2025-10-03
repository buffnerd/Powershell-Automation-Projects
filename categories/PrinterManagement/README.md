# Printer Management

Automate **deployment** and **cleanup/repair** of shared network printers across Windows endpoints. Scripts support **per-machine (all users)** or **per-user** operation and are parameterized for future GUI integration.

---

## Prerequisites
- Targets can access the print server (DNS + firewall + permissions)
- For per-machine operations: local admin rights and Print Spooler service
- PowerShell Remoting (WinRM) for remote actions

---

## Scripts

### 1) DeployNetworkPrinters.ps1
Deploy one or more shared printers to target computers:
- **Per-machine** (`/ga`) — appears for all users (spooler restart recommended)
- **Per-user** (`Add-Printer`) — installs for the current user context
- Optional **default printer** setting (per-user mode)
- Reachability pre-check and CSV results

**Examples**
```powershell
# Per-machine deployment with spooler restart
.\DeployNetworkPrinters.ps1 -ComputerName (gc .\hosts.txt) `
  -Printers '\\print01\HR-1stFloor','\\print01\Ops-2ndFloor' `
  -PerMachine -RestartSpooler -ValidateReachability -Verbose

# Per-user deployment and set default
.\DeployNetworkPrinters.ps1 -ComputerName PC-007 `
  -Printers '\\print01\HR-1stFloor' -SetDefault '\\print01\HR-1stFloor' -Verbose
```

**Adjust for your environment**
- Printer queues: \\server\queue
- Per-machine vs per-user
- Default printer (per-user)
- Spooler restart policy
- Credentials for remote execution

### 2) CleanupOfflinePrinters.ps1
Detect and repair or remove offline/stale printer connections:
- **Repair** = remove + reinstall + verify
- **Remove stale** when servers/queues no longer exist
- **Allow-list servers** to touch for safety

**Examples**
```powershell
# Identify & remove stale printers from print01 only
.\CleanupOfflinePrinters.ps1 -ComputerName (gc .\hosts.txt) -Servers print01 -RemoveStale -Verbose

# Attempt repair for broken queues (per-user mode)
.\CleanupOfflinePrinters.ps1 -ComputerName PC-007 -ReinstallIfBroken -Verbose

# Per-machine cleanup on a VDI pool
.\CleanupOfflinePrinters.ps1 -ComputerName VDI-01,VDI-02 -PerMachine -ReinstallIfBroken -Verbose
```

**Adjust for your environment**
- Server allow-list: `-Servers`
- Repair vs remove policy: `-ReinstallIfBroken`, `-RemoveStale`
- Mode: `-PerMachine` vs per-user
- Credentials and CSV output

---

## Common Workflows

### Initial Printer Deployment
1. **Plan Deployment**: Identify target computers and required printers
2. **Validate Connectivity**: Use `-ValidateReachability` to test printer access
3. **Deploy Printers**: Run `DeployNetworkPrinters.ps1` with appropriate mode
4. **Set Defaults**: Configure default printers for user convenience
5. **Verify Installation**: Check deployment results and troubleshoot failures

### Printer Server Migration
1. **Document Current State**: Export current printer connections
2. **Deploy New Connections**: Install printers pointing to new server
3. **Cleanup Old Connections**: Use `CleanupOfflinePrinters.ps1` to remove old server references
4. **Validate Migration**: Confirm all users have access to required printers
5. **Monitor Usage**: Track adoption and resolve any remaining issues

### Regular Maintenance
1. **Detect Issues**: Use cleanup script to identify broken connections
2. **Repair Connections**: Attempt automatic repair of broken printers
3. **Remove Stale Entries**: Clean up connections to decommissioned servers
4. **Update Documentation**: Maintain current printer deployment records
5. **User Communication**: Notify users of changes and new printer locations

### VDI/Terminal Server Management
1. **Per-Machine Focus**: Use `-PerMachine` for shared terminal environments
2. **Regular Cleanup**: Schedule automated cleanup of stale connections
3. **Standardized Deployment**: Deploy standard printer sets for all users
4. **Performance Optimization**: Minimize per-user printer proliferation
5. **Session Management**: Consider printer mapping in logon scripts

---

## Installation Methods Comparison

| Feature | Per-Machine (/ga) | Per-User (Add-Printer) |
|---------|-------------------|-------------------------|
| **Scope** | All users on computer | Current user only |
| **Permissions** | Local admin required | User context sufficient |
| **Availability** | After spooler restart/logon | Immediate |
| **Default Setting** | Manual per user | Automatic during install |
| **Persistence** | System-wide | User profile |
| **Best For** | Shared workstations, kiosks | Personal workstations |

---

## Environment Integration

### GUI Development Considerations
Both scripts are designed for easy GUI integration:

**Deployment Script:**
- **Printer Selection**: Multi-select picker populated from print server enumeration
- **Mode Toggle**: Radio buttons for per-machine vs per-user operation
- **Default Printer**: Dropdown populated from selected printers (per-user mode)
- **Options**: Checkboxes for validation, spooler restart, and other settings
- **Progress Tracking**: Progress bars for bulk deployment operations

**Cleanup Script:**
- **Server Allow-list**: Multi-select with safety confirmation
- **Operation Mode**: Checkboxes for repair vs remove operations
- **Target Selection**: Computer picker with AD integration
- **Advanced Options**: Retry settings and filtering options
- **Results Display**: Tabular results with export capabilities

### Automation Integration
- **Configuration Management**: Store standard printer lists in CSV/JSON
- **Scheduling**: Use Windows Task Scheduler for regular maintenance
- **Monitoring**: Integrate with existing monitoring systems
- **Reporting**: Export results to centralized logging systems
- **Change Management**: Track printer deployment changes over time

---

## Tips & Best Practices

### Deployment Best Practices
- For per-machine deployment, a **Spooler restart** or a logon refresh helps connections appear for all users promptly
- Keep a simple list of standard queues per site/department to drive both scripts (CSV or JSON)
- If you use **GPO-deployed printers** in production, use these scripts for ad-hoc remediation and onboarding
- Use `-WhatIf` parameter for testing before production deployment
- Consider **batch processing** for large environments to manage network load

### Maintenance Best Practices
- Implement **regular cleanup schedules** to prevent accumulation of stale connections
- Use **server allow-lists** to prevent accidental modification of production printers
- **Document printer standards** for each department or location
- Monitor **deployment success rates** and investigate failures
- Maintain **rollback procedures** for problematic deployments

### Security Best Practices
- Use **service accounts** with minimal required permissions for automation
- Implement **change approval** processes for printer deployment modifications
- **Log all operations** for audit trail and troubleshooting
- Test scripts in **isolated environments** before production use
- Regularly **review and update** server allow-lists

### Performance Optimization
- **Batch operations** by geographic location or network segment
- Use **parallel processing** for large computer lists where appropriate
- Implement **timeout controls** for network operations
- **Cache printer server connectivity** tests to avoid redundant checks
- Consider **off-peak scheduling** for large deployment operations

---

## Future GUI Integration Ideas

### Deployment Interface
- **Queue picker** auto-populated from one or more print servers
- **Mode toggle** (per-machine vs per-user)
- **Default printer dropdown**
- **Bulk import** from CSV files
- **Preview deployment** with validation results

### Cleanup Interface
- **Dashboard view** of printer health across the environment
- **One-click "repair all broken queues"** with summary report export
- **Server management** interface for allow-list maintenance
- **Scheduled cleanup** configuration and monitoring
- **Historical reporting** of cleanup operations

### Unified Management Console
- **Combined deployment and maintenance** workflows
- **Printer server discovery** and enumeration
- **Template management** for standard printer sets
- **User self-service** portal for printer requests
- **Integration** with existing IT service management tools

---

## Troubleshooting Guide

### Common Issues
- **Access Denied**: Verify user has local admin rights for per-machine operations
- **Printer Not Found**: Check DNS resolution and firewall rules for print server
- **Spooler Errors**: Ensure Print Spooler service is running and responsive
- **Slow Operations**: Network latency or unreachable servers causing timeouts
- **Permission Errors**: Cross-domain scenarios requiring specific credentials

### Diagnostic Steps
1. **Test Network Connectivity**: Verify UNC path accessibility
2. **Check Service Status**: Confirm Print Spooler service is running
3. **Validate Credentials**: Test authentication to target computers
4. **Review Logs**: Examine Windows Event Logs for spooler errors
5. **Incremental Testing**: Start with single computer/printer combinations

### Recovery Procedures
- **Failed Deployments**: Use cleanup script to remove partial installations
- **Corrupted Connections**: Remove and redeploy affected printers
- **Service Issues**: Restart Print Spooler service on affected computers
- **Network Problems**: Verify DNS resolution and firewall configurations
- **Permission Issues**: Review and update service account permissions