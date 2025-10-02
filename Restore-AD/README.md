```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
Active Directory Disaster Recovery and Organizational Unit Restoration
```

# 🔄 Restore Active Directory

PowerShell automation script for Active Directory disaster recovery, providing systematic OU restoration with user data import from backup files.

## 🎯 Project Overview

This script automates the complete restoration process for Active Directory Organizational Units, including user account recreation from CSV backup data, ensuring business continuity during disaster recovery scenarios.

## 📁 Project Files

- **`Restore-AD.ps1`** - Complete AD OU restoration automation script
- **`financePersonnel.csv`** - Sample backup data file (place in same directory)

## 📋 Prerequisites

### **Required Software**
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Active Directory PowerShell Module** (RSAT Tools)
- **Windows Server** with Active Directory Domain Services
- **Administrative PowerShell session** (Run as Administrator)

### **Active Directory Requirements**
- **Domain Controller access** with full administrative privileges
- **Active Directory Domain Services** running and accessible
- **Target domain** (script uses "consultingfirm.com" - modify as needed)
- **Schema permissions** for OU and user object creation

### **Required Permissions**
- **Domain Admin** privileges or equivalent delegated permissions
- **Full control** over target domain and OU creation
- **User creation permissions** in Active Directory
- **ProtectedFromAccidentalDeletion** modification rights

### **Module Installation**
```powershell
# Install RSAT Tools for Active Directory module
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

# Import Active Directory module
Import-Module ActiveDirectory

# Verify Domain Controller connectivity
Get-ADDomain
```

### **Data Requirements**
- **CSV backup file** (`financePersonnel.csv`) in same directory as script
- **Proper CSV format** with columns: First_Name, Last_Name, PostalCode, OfficePhone, MobilePhone
- **Valid user data** for account creation
- **Backup verification** before running restoration

### **Environment Setup**
- **Network connectivity** to Domain Controllers
- **PowerShell execution policy** configured for script execution
- **Administrative credentials** for AD operations
- **Test environment** recommended before production use

## ⚠️ Important Safety Notes

This script will **DELETE existing OUs** if they exist before recreation. Ensure you have proper backups and test in a non-production environment first. The sample data included is fake data for demonstration purposes only.

This PowerShell script automates several tasks related to Active Directory management. Here's a comprehensive explanation of what each part of the script does:

1 - Check for Existence of Organizational Unit (OU): The script uses the Get-ADOrganizationalUnit cmdlet to check for the existence of an OU named "Finance" in the Active Directory. If the OU exists, the script proceeds to deactivate the protection from accidental deletion.

2 - Deactivate Protection from Accidental Deletion (if applicable): If the "Finance" OU exists, the script checks whether it is protected from accidental deletion. If protection is enabled, the script temporarily deactivates it by setting the ProtectedFromAccidentalDeletion property to $false.

3 - Delete Existing OU (if applicable): After deactivating protection, the script attempts to delete the "Finance" OU using the Remove-ADOrganizationalUnit cmdlet. It catches any errors that occur during the deletion process and displays an error message.

4 - Create New OU: If the "Finance" OU does not exist or after deleting the existing one, the script creates a new OU named "Finance" using the New-ADOrganizationalUnit cmdlet.

5 - Import Data into Active Directory: The script imports data from a CSV file named "financePersonnel.csv" into the Active Directory domain. It iterates through each row in the CSV file and creates a new user account for each entry using the New-ADUser cmdlet. The user accounts are created within the "Finance" OU.

6 - Reactivate Protection from Accidental Deletion: After completing the tasks, the script reactivates protection from accidental deletion for the "Finance" OU by setting the ProtectedFromAccidentalDeletion property to $true.

7 - Generate Output File: Finally, the script retrieves user information from the "Finance" OU using the Get-ADUser cmdlet. It filters the results to include all users and retrieves additional properties such as display name, postal code, office phone, and mobile phone. The user information is then exported to a text file named "AdResults.txt" located in the same directory as the PowerShell script.

Overall, this script streamlines the process of managing Active Directory by checking for the existence of an OU, creating or deleting the OU as needed, importing user data from a CSV file, and generating an output file with user information for submission or further analysis. Additionally, it ensures that the OU's protection from accidental deletion is properly managed throughout the process.