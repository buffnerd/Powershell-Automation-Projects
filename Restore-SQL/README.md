```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
SQL Server Database Restoration and Automated Management Script
```

# Restore-SQL
PowerShell automation script that checks for an existing SQL database and restores it with backup data. The script provides automated database management capabilities including existence checking, deletion, creation, and data import.

## Prerequisites

### Software Requirements
- **PowerShell 5.1+** or **PowerShell 7+**
- **SQL Server Express** (or full SQL Server instance)
- **SQL Server Management Tools** (SQLCMD)
- **SqlServer PowerShell Module** or **SQLPS Module**

### Permissions Required
- **SQL Server Administrator** privileges or **db_owner** role
- **Windows Authentication** configured for SQL Server access
- **File system permissions** to read/write in script directory

### Module Installation
```powershell
# Install SqlServer module (recommended)
Install-Module -Name SqlServer -Force -AllowClobber

# Or use legacy SQLPS module if SqlServer module unavailable
Import-Module SQLPS -DisableNameChecking
```

### Data Requirements
- **Backup SQL files** (.sql) in same directory as script
- **CSV data files** referenced by SQL scripts
- **Proper file permissions** for PowerShell to access all files
- **Consistent file naming** as referenced in SQL scripts

### Network Configuration
- **SQL Server instance** accessible (default: `.\SQLEXPRESS`)
- **TCP/IP protocols enabled** for SQL Server
- **Firewall exceptions** for SQL Server ports if needed

### Safety Notes
⚠️ **WARNING**: This script will **DROP existing databases** if they exist
⚠️ **BACKUP**: Always backup existing databases before running
⚠️ **TEST**: Run in development environment first
⚠️ **VERIFY**: Confirm SQL scripts and CSV files are correct before execution

**NOTE**: There are 3 .sql files included which are dependencies for the script to work. The 3rd dependency "Client_A_Contacts.sql" calls an existing backup .csv file from within the same directory. If you are using this for your own implementation, you may need to change some pathing in the .sql file and .csv file as well as rename them according to suit your needs.

This PowerShell script performs a series of actions related to Microsoft SQL Server database management. Here's a comprehensive explanation of what each part of the script does:

1 - Check for Database Existence: The script first checks if a database named "ClientDB" exists on the SQL Server instance named ".\SQLEXPRESS". It uses a SQL query to count the number of databases with the specified name. If the count is greater than zero, it means the database exists.

2 - Delete Existing Database (if applicable): If the database exists, the script attempts to delete it using the DROP DATABASE SQL command. It catches any errors that occur during the deletion process and displays an error message.

3 - Create New Database: Regardless of whether the database existed previously, the script proceeds to create a new database named "ClientDB" using the CREATE DATABASE SQL command.

4 - Import Data into Database: After creating the database, the script imports data into it. It invokes the Invoke-Sqlcmd cmdlet to execute SQL scripts that create tables and import data. The script expects the SQL scripts to be present in the same directory as the PowerShell script.

5 - Generate Output File: Finally, the script executes a SQL query to select all records from the "Client_A_Contacts" table within the "ClientDB" database. The query results are redirected to a text file named "SqlResults.txt" located in the same directory as the PowerShell script.

6 - Exception Handling: The entire script is enclosed within a try-catch block to handle any errors that may occur during execution. If an error occurs, it is caught by the catch block, and an error message is displayed to the console.

Overall, this script automates the process of managing a SQL Server database, including checking for existence, deleting if necessary, creating a new database, importing data, and generating an output file with query results.