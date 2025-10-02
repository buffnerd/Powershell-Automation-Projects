```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
Azure Cloud Automation and Security Monitoring Scripts
```
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░

# ☁️ Azure PowerShell Scripts

Comprehensive Azure automation scripts for managing cloud resources, security monitoring, and workflow automation in enterprise environments.

## 🎯 Project Overview

This project provides essential Azure PowerShell scripts for automating common repetitive tasks and implementing security monitoring workflows for cloud security engineers.

## 📁 Project Files

- **`AZ-Automate-Repetitive-Tasks.ps1`** - Automates common Azure resource management tasks
- **`AZ-Create-Alert-Rule.ps1`** - Creates security monitoring and alert rules

## 📋 Prerequisites

### **Required Software**
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Azure PowerShell Module** (Az module)
- **Azure CLI** (optional, for additional functionality)
- **Internet connection** for Azure service access

### **Azure Requirements**
- **Azure Subscription** with appropriate permissions
- **Azure Active Directory** access
- **Resource creation permissions** in target subscription
- **Log Analytics workspace** (for monitoring scripts)

### **Required Permissions**
- **Contributor** or **Owner** role on Azure subscription
- **Security Admin** role for security-related operations
- **Log Analytics Contributor** for monitoring setup
- **Policy Contributor** for Azure Policy operations

### **Module Installation**
```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Import Azure modules
Import-Module Az

# Connect to Azure
Connect-AzAccount

# Verify connection
Get-AzContext
```

### **Environment Setup**
- **Azure subscription ID** configured
- **Resource group** permissions for deployment
- **Network access** to Azure services
- **PowerShell execution policy** configured appropriately

## ⚠️ Important Notes

Keep in mind these are examples and may need to be modified to meet your organization's specific requirements. Parameters like location and resource names should be updated to match your environment. 

These scripts are for demonstration purposes and should not be used in production without thorough testing and validation. Follow Azure security best practices for script storage and credential management.