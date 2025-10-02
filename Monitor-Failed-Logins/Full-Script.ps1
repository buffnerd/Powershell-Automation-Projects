<#
.SYNOPSIS
    Monitor Failed Login Attempts on Domain Controller
.DESCRIPTION
    This script connects to a domain controller and monitors failed login attempts (Event ID 4625),
    extracts relevant information, and exports the results to a CSV file.
.NOTES
    Prerequisites:
    - Access to a domain controller
    - ActiveDirectory module installed
    - Appropriate permissions to read Security Event Log
.EXAMPLE
    .\Full-Script.ps1
#>

# Step 1: Connect to the Domain Controller
Write-Host "Step 1: Connecting to Domain Controller..." -ForegroundColor Green
try {
    $domainController = Get-ADDomainController -Discover
    Write-Host "Connected to Domain Controller: $($domainController.HostName)" -ForegroundColor Yellow
}
catch {
    Write-Error "Failed to connect to Domain Controller: $($_.Exception.Message)"
    exit 1
}

# Step 2: Query the Security Event Log for Failed Login Events
Write-Host "Step 2: Querying Security Event Log for Failed Login Events..." -ForegroundColor Green
try {
    $failedLogins = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625} -ComputerName $domainController.HostName
    Write-Host "Found $($failedLogins.Count) failed login events" -ForegroundColor Yellow
}
catch {
    Write-Error "Failed to query Security Event Log: $($_.Exception.Message)"
    exit 1
}

# Step 3: Extract Relevant Information from the Events
Write-Host "Step 3: Extracting relevant information from events..." -ForegroundColor Green
$extractedData = $failedLogins | ForEach-Object {
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        UserName = ($_.Properties[5].Value -split '\\')[-1]  # Extract username from domain\username format
        SourceIP = $_.Properties[19].Value
        WorkstationName = $_.Properties[13].Value
        FailureReason = $_.Properties[8].Value
        EventID = $_.Id
    }
}

Write-Host "Extracted data for $($extractedData.Count) events" -ForegroundColor Yellow

# Step 4: Export the Results to a CSV File
Write-Host "Step 4: Exporting results to CSV file..." -ForegroundColor Green
$outputPath = "C:\FailedLogins_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').csv"
try {
    $extractedData | Export-Csv -Path $outputPath -NoTypeInformation
    Write-Host "Results exported to: $outputPath" -ForegroundColor Yellow
    Write-Host "Script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export CSV file: $($_.Exception.Message)"
    exit 1
}