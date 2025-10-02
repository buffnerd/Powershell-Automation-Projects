# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# ------------------Script by Aaron Voborny---------------------------
# Automation Script that Restores a SQL Database from a backup file

try {
    # Check for the existence of a database named ClientDB
    $sqlServer = ".\SQLEXPRESS"
    $databaseName = "ClientDB"

    $sqlQuery = "SELECT COUNT(*) FROM sys.databases WHERE name = '$databaseName'"
    $databaseExistsResult = Invoke-Sqlcmd -Query $sqlQuery -ServerInstance $sqlServer
    $databaseExists = $databaseExistsResult | Select-Object -ExpandProperty Column1

    if ($databaseExists -ne $null -and $databaseExists -gt 0) {
        try {
            # Database exists, delete it
            $sqlQuery = "DROP DATABASE $databaseName"
            Invoke-Sqlcmd -Query $sqlQuery -ServerInstance $sqlServer
            Write-Host "The '$databaseName' database already existed and has been deleted."
        } catch {
            Write-Host "Error occurred while deleting the '$databaseName' database: $_"
        }
    } else {
        Write-Host "The '$databaseName' database does not exist."
    }

    # Create a new database named "ClientDB"
    $sqlQuery = "CREATE DATABASE $databaseName"
    Invoke-Sqlcmd -Query $sqlQuery -ServerInstance $sqlServer
    Write-Host "The '$databaseName' database has been created."

    # create the database and import records
    $servername = ".\SQLEXPRESS"
    $databasename = "ClientDB"

    Invoke-Sqlcmd -ServerInstance $servername -InputFile $PSScriptRoot\DBCreate.sql -Verbose
    Invoke-Sqlcmd -ServerInstance $servername -Database $databasename -InputFile $PSScriptRoot\Client_A_Contacts.sql -Verbose
    Invoke-Sqlcmd -ServerInstance $servername -Database $databasename -InputFile $PSScriptRoot\import.sql -Variable mypath="'$PSScriptroot\NewClientData.csv'" -Verbose

    # Generate output file for submission
    Invoke-Sqlcmd -Database $databaseName -ServerInstance $sqlServer -Query "SELECT * FROM dbo.Client_A_Contacts" > "$PSScriptRoot\SqlResults.txt"
} catch {
    Write-Host "Error: $_"
}