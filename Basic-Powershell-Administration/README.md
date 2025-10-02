```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
Basic PowerShell Administration Scripts for Active Directory
```
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░

# BASIC POWERSHELL ADMINISTRATION

A comprehensive guide on how to create, modify, and delete users in Active Directory using PowerShell.

## 🎯 Project Overview

This project provides foundational Active Directory user management scripts for enterprise environments, demonstrating essential PowerShell techniques for user lifecycle management.

## 📁 Project Files

- **`01-User-Creation.ps1`** - Creates new Active Directory users
- **`02-User-Modification.ps1`** - Modifies existing user properties
- **`03-User-Deletion.ps1`** - Removes users from Active Directory

## 📋 Prerequisites

### **Required Software**
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Active Directory PowerShell Module** (part of RSAT)
- **Windows Server** with Active Directory Domain Services role
- **Domain Controller access** for user management operations

### **Required Permissions**
- **Domain Admin** or **User Admin** privileges
- **Delegated permissions** for user creation/modification in target OUs
- **Read/Write access** to Active Directory user objects

### **Module Installation**
```powershell
# Install RSAT Tools (Windows 10/11)
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

# Import Active Directory Module
Import-Module ActiveDirectory

# Verify module availability
Get-Module -ListAvailable ActiveDirectory
```

### **Environment Setup**
- **Network connectivity** to Domain Controller
- **PowerShell execution policy** configured appropriately
- **Administrative credentials** for Active Directory operations