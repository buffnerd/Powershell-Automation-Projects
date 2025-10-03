# PowerShell Automation Portfolio

This repository showcases a comprehensive collection of PowerShell automation scripts designed for IT administration and security hardening in enterprise environments.

## 🎯 Project Overview

Each project demonstrates practical PowerShell solutions for real-world IT challenges, following industry best practices and security standards.

## 📁 Project Structure

```
powershell-automation-portfolio/
├─ Identity-Access-Management/          # User accounts, permissions, Group Policy
│  ├─ UserAccountManagement/            # AD user lifecycle management
│  ├─ PermissionAuditing/               # NTFS and access rights analysis
│  └─ GroupPolicyManagement/            # GPO management and reporting
├─ System-Infrastructure-Maintenance/   # System health and maintenance
│  ├─ SystemHealthChecks/               # Performance monitoring
│  ├─ ServiceMonitoring/                # Service monitoring and restart
│  ├─ SoftwareManagement/               # Software installation and updates
│  └─ FileSystemCleanup/                # Cleanup and archival processes
├─ Networking-Resources/                # Network infrastructure management
│  ├─ NetworkDriveManagement/           # Drive mapping automation
│  └─ PrinterManagement/                # Network printer deployment
├─ Data-Protection-Recovery/            # Backup and log analysis
│  ├─ BackupVerification/               # Backup integrity and restoration
│  └─ LogCollectionAnalysis/            # Security event analysis and SIEM
├─ Security-Compliance/                 # Security auditing and compliance
│  ├─ SecurityComplianceChecks/         # Security auditing and TLS hardening
│  ├─ InventoryAssetReporting/          # Hardware and software inventory
│  ├─ RemoteComputerManagement/         # Remote administration
│  └─ OutlookExchangeAutomation/        # Email system automation
├─ categories/AzureAutomation/          # Cloud infrastructure automation
├─ scripts/                             # Shared utilities
├─ docs/                                # Documentation
└─ .github/workflows/                   # CI/CD automation
```

## 🚀 Featured Projects

### Identity & Access Management
- **UserAccountManagement**: AD user lifecycle, bulk operations, password management
- **PermissionAuditing**: NTFS permissions and access rights analysis
- **GroupPolicyManagement**: GPO analysis, export, and conflict detection

### System & Infrastructure Maintenance
- **SystemHealthChecks**: Performance monitoring, resource tracking, health reporting
- **ServiceMonitoring**: Critical service monitoring and automated restart
- **SoftwareManagement**: Automated installation, updates, and patch compliance
- **FileSystemCleanup**: Automated cleanup and archival processes

### Security & Compliance
- **SecurityComplianceChecks**: Security auditing, TLS hardening, Sysmon configurations
- **InventoryAssetReporting**: Hardware and software inventory automation
- **RemoteComputerManagement**: Remote administration and firewall configuration

### Data Protection & Recovery
- **BackupVerification**: Backup integrity validation and restoration testing
- **LogCollectionAnalysis**: Security event analysis and Azure Sentinel SIEM integration

## 🛠️ Development Standards

- **Error Handling**: Comprehensive try-catch blocks and logging
- **Documentation**: Comment-based help for all functions
- **Testing**: Isolated environment validation before production
- **Code Quality**: PSScriptAnalyzer compliance
- **Security**: Secure coding practices and credential management

## 📋 Prerequisites

- PowerShell 5.1 or later
- Appropriate module dependencies (documented per project)
- Administrative privileges where required
- Azure PowerShell module (for cloud projects)

## 🤝 Contributing

See [how-to-contribute.md](docs/how-to-contribute.md) for guidelines on contributing to this portfolio.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.