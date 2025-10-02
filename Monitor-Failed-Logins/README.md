```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
Security Event Monitoring for Failed Login Detection and Analysis
```

# 🔍 Monitor Failed Logins

A comprehensive PowerShell solution for monitoring and analyzing failed user login attempts on domain controllers with real-time security event analysis.

## 🎯 Project Overview

This project provides a step-by-step approach to monitoring failed login attempts across Active Directory environments, enabling security teams to identify potential threats and unauthorized access attempts.

## 📁 Project Files

- **`01-Connect.ps1`** - Establishes connection to Domain Controller
- **`02-Query.ps1`** - Queries Security Event Log for failed logins
- **`03-Extract.ps1`** - Extracts relevant information from events
- **`04-Export.ps1`** - Exports results to CSV format
- **`Full-Script.ps1`** - Complete integrated monitoring solution

## 📋 Prerequisites

### **Required Software**
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Active Directory PowerShell Module** (RSAT Tools)
- **Windows Server** with Domain Controller access
- **Event Log access** to Security logs

### **Required Permissions**
- **Domain Admin** or **Event Log Reader** privileges
- **Security audit permissions** for Event ID 4625 access
- **Network access** to Domain Controllers
- **Read permissions** on Security Event Logs

### **Module Installation**
```powershell
# Check if ActiveDirectory module is available
Get-Module -ListAvailable | Where-Object {$_.Name -eq "ActiveDirectory"}

# Install RSAT Tools if not present
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

# Install ActiveDirectory module if needed
Install-Module -Name ActiveDirectory -Force

# Import the module
Import-Module ActiveDirectory
```

### **Environment Requirements**
- **Domain Controller access** for event log queries
- **Network connectivity** to target domain controllers
- **Administrative privileges** for security event access
- **PowerShell execution policy** configured for script execution