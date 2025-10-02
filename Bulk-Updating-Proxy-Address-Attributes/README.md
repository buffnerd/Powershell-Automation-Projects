```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
Bulk Active Directory Proxy Address Attribute Management Scripts
```
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░

# 📧 Bulk Updating Proxy Address Attributes

PowerShell automation for mass updating proxy address attributes in Active Directory, enabling efficient management of large-scale email address modifications.

## 🎯 Project Overview

This project provides a systematic approach to bulk updating proxy addresses in Active Directory using CSV-driven automation, essential for Exchange and Office 365 migrations.

## 📁 Project Files

- **`1st-script.ps1`** - Queries Active Directory users from specified OU
- **`2nd-script.ps1`** - Performs bulk proxy address updates from CSV data

## 📋 Prerequisites

### **Required Software**
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Active Directory PowerShell Module** (RSAT Tools)
- **Microsoft Excel** or CSV editor for data preparation
- **Administrative PowerShell session** (Run as Administrator)

### **Active Directory Requirements**
- **Domain Controller access** for user queries and updates
- **Active Directory Domain Services** environment
- **Exchange Schema** (if working with Exchange attributes)
- **Target Organizational Unit** properly configured

### **Required Permissions**
- **Domain Admin** or **delegated permissions** for user attribute modification
- **Write access** to proxyAddresses attribute in target OU
- **Read permissions** for Active Directory user objects
- **Administrative rights** on workstation running scripts

### **Module Installation**
```powershell
# Install RSAT Tools for Active Directory module
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

# Import Active Directory module
Import-Module ActiveDirectory

# Verify module is available
Get-Module -ListAvailable ActiveDirectory
```

### **Data Preparation Requirements**
- **CSV file** with proper LDAP attribute column names
- **Unique identifier column** (samAccountName recommended)
- **proxyAddresses column** with comma-separated values
- **Backup of existing data** before making changes

### **Environment Setup**
- **Network connectivity** to Domain Controllers
- **PowerShell execution policy** configured for script execution
- **Test environment** for validation before production use

## ⚠️ Critical Safety Notes

**ALWAYS test on small groups first!** Making mistakes on bulk updates can cause unnecessary rework and tie up critical resources. **MEASURE TWICE, CUT ONCE!**

Step 1.)  Pull a .csv report from Active Directory that includes:
              a.)  One unique identifier (such as an employee number, or SAM Account Name)
              b.)  At least one field you want to update (in this case, the proxyAddresses attribute)
              c.)  To make your life easier, pull the e-mail address attribute as well.
              
Step 2.)  Change the .csv to include the additional attribute values you want to update.  For the proxyAddresses attribute, you can speed this up by
          running a formula in excel to make changes to the attribute information in question.  If you are adding SIP to many accounts, you'll want
          to run a formula such as ="SIP:"&B2 (where B2 is the email address in the second row of the second column) and hit enter.  Next, highlight
          all the rows in the column that you want to update and press CTRL+D.  Once this is done, make sure you paste the new values into a new 
          column as values to remove formatting and then delete the formatted column.
          
          NOTE:  It is also important that you make sure to name the columns as their appropriate LDAP attribute title. 
          
Step 3.)  Store the .csv in a known location and note the file path.

Step 4.)  Using the 'Get' cmdlet in an elevated PowerShell Prompt, run the following command:

          Get-ADUser -Filter * -SearchBase "OU=Knowledge,OU=Users,DC=companydomain,DC=com"
          
          NOTE:  It is important to change the information in quotations to match an OU that exists in your organization's Active Directory Environment.

Step 5.)  In your elevated PowerShell Prompt, run a command which pulls the .csv and triggers the proxyAddresses attribute to be
          updated with the information in the proxyAddresses column in your CSV for users in the selected OU based on their 
          SAM Account Name for the unique identifier.  That command will look something like this:
          
          Import-Csv "C:\Users\adminaccount\scripts\bulk-update-proxy-addresses.csv" | foreach {Set-ADUser -Identity 
          $_.samaccountname -add @{Proxyaddresses=$_.Proxyaddresses -split ","}}
          
          NOTE:  It is important to change the information in quotations to match a file path that exists in your environment.
  
          Extra information:  The "," just before the final two brackets in the final script tells the domain controller to
          add multiple fields, delimiting them by commas.  This can be useful for attributes such as Proxy Addresses and
          Direct Reports where you may need to make multiple entries.
          
          A FRIENDLY REMINDER:  Always make sure to run scripts like this on small test groups first to verify it functions as
          intended.  Making mistakes on bulk updates can cause uneccessary rework and tie up critical resources.  MEASURE TWICE,
          CUT ONCE!!!!!