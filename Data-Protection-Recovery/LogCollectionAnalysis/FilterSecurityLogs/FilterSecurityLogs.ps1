<#
.SYNOPSIS
  Focused Security event log analysis with filtering for common attack patterns, anomalies, and administrative activities.

.DESCRIPTION
  Analyzes Windows Security logs (often 4624,4625,4648,4720,4740,etc.) with presets for:
    - Brute-force detection (multiple 4625s from same IP/user)
    - Privilege escalation (4672,4673,4674)
    - Account management (4720,4722,4724,4726,4738,4740)
    - Logon analysis (4624,4634,4647,4648 patterns)
    - Timeline reconstruction for specific user/computer/IP
  Outputs detailed CSV/JSON reports + summary statistics.

.PARAMETER ComputerName
  One or more computers to analyze. Default is local.

.PARAMETER Credential
  PSCredential for remote access.

.PARAMETER StartTime
  Analysis window start (default: last 7 days).

.PARAMETER EndTime
  Analysis window end (default: now).

.PARAMETER AnalysisType
  What to analyze:
    - 'BruteForce': Failed logon patterns (4625)
    - 'PrivilegeEscalation': Special privilege use (4672,4673,4674)
    - 'AccountManagement': User/group changes (4720-4740 range)
    - 'LogonAnalysis': All logon/logoff events (4624,4634,4647,4648)
    - 'Timeline': Full security event timeline for specific target
    - 'All': Run all analyses

.PARAMETER TargetUser
  Filter for specific username (Timeline mode or general filtering).

.PARAMETER TargetComputer
  Filter for specific computer name (Timeline mode).

.PARAMETER TargetIP
  Filter for specific source IP (Timeline mode or network logons).

.PARAMETER BruteForceThreshold
  Min failed attempts to flag as brute-force (default: 10).

.PARAMETER TimeWindow
  Window in minutes for grouping related events (default: 60).

.PARAMETER OutputCsv
  CSV output path for detailed events.

.PARAMETER OutputSummaryJson
  JSON output path for summary statistics and findings.

.PARAMETER OutputTimeline
  Special timeline CSV with chronological ordering and context.

.EXAMPLES
  # Detect brute-force attempts on domain controller
  .\FilterSecurityLogs.ps1 -ComputerName DC01 -AnalysisType BruteForce -BruteForceThreshold 5 -OutputCsv .\bruteforce.csv

  # User timeline for incident response
  .\FilterSecurityLogs.ps1 -AnalysisType Timeline -TargetUser jdoe -StartTime (Get-Date).AddDays(-3) -OutputTimeline .\jdoe_timeline.csv

  # Full analysis last 24h across multiple servers
  .\FilterSecurityLogs.ps1 -ComputerName (Get-Content .\servers.txt) -AnalysisType All -StartTime (Get-Date).AddDays(-1) `
    -OutputCsv .\security_analysis.csv -OutputSummaryJson .\security_summary.json

.NOTES (GUI integration points)
  - Analysis type radio buttons/dropdown.
  - User/computer/IP target text boxes with validation.
  - Threshold sliders for brute-force detection.
  - Time window selection and date/time pickers.
  - Progress bars for multi-computer analysis.
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline)]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [datetime]$StartTime = (Get-Date).AddDays(-7),

  [Parameter()]
  [datetime]$EndTime = (Get-Date),

  [Parameter()]
  [ValidateSet('BruteForce','PrivilegeEscalation','AccountManagement','LogonAnalysis','Timeline','All')]
  [string]$AnalysisType = 'All',

  [Parameter()]
  [string]$TargetUser,

  [Parameter()]
  [string]$TargetComputer,

  [Parameter()]
  [string]$TargetIP,

  [Parameter()]
  [int]$BruteForceThreshold = 10,

  [Parameter()]
  [int]$TimeWindow = 60,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputSummaryJson,

  [Parameter()]
  [string]$OutputTimeline
)

# Event ID mappings for security analysis
$SecurityEvents = @{
  'BruteForce' = @(4625)  # Failed logon
  'PrivilegeEscalation' = @(4672,4673,4674)  # Special privileges assigned/used
  'AccountManagement' = @(4720,4722,4724,4726,4738,4740,4767,4781)  # User/group management
  'LogonAnalysis' = @(4624,4634,4647,4648)  # Logon/logoff patterns
  'Timeline' = @(4624,4625,4634,4647,4648,4672,4673,4674,4720,4722,4724,4726,4738,4740,4767,4781,4688,4689,4697,4698,4702)
}

function Get-SecurityEvents {
  param([string]$Computer, [int[]]$EventIds, [datetime]$Start, [datetime]$End, [pscredential]$Cred)
  
  $filter = @{
    LogName = 'Security'
    Id = $EventIds
    StartTime = $Start
    EndTime = $End
  }
  
  try {
    if ($Cred) {
      Get-WinEvent -FilterHashtable $filter -ComputerName $Computer -Credential $Cred -ErrorAction Stop
    } else {
      Get-WinEvent -FilterHashtable $filter -ComputerName $Computer -ErrorAction Stop
    }
  } catch {
    Write-Warning "Failed to collect from ${Computer}: $($_.Exception.Message)"
    return @()
  }
}

function Analyze-BruteForce {
  param([array]$Events, [int]$Threshold)
  
  Write-Verbose "Analyzing brute-force patterns (threshold: $Threshold)..."
  $groups = $Events | Where-Object Id -eq 4625 | Group-Object @{Expression={ 
    "$($_.Properties[1].Value)_$($_.Properties[19].Value)" # TargetUserName_IpAddress
  }}
  
  $bruteForceFindings = @()
  foreach ($g in $groups) {
    if ($g.Count -ge $Threshold) {
      $userIP = $g.Name -split '_'
      $times = $g.Group | ForEach-Object { $_.TimeCreated } | Sort-Object
      $bruteForceFindings += [pscustomobject]@{
        TargetUser = $userIP[0]
        SourceIP = $userIP[1]
        FailedAttempts = $g.Count
        FirstAttempt = $times[0]
        LastAttempt = $times[-1]
        Duration = ($times[-1] - $times[0]).TotalMinutes
        Events = $g.Group
      }
    }
  }
  return $bruteForceFindings
}

function Analyze-PrivilegeEscalation {
  param([array]$Events)
  
  Write-Verbose "Analyzing privilege escalation events..."
  $privEvents = $Events | Where-Object Id -in @(4672,4673,4674)
  $findings = @()
  
  foreach ($event in $privEvents) {
    $findings += [pscustomobject]@{
      EventId = $event.Id
      TimeCreated = $event.TimeCreated
      Computer = $event.MachineName
      User = $event.Properties[1].Value
      PrivilegesUsed = ($event.Properties[2].Value -split "`r`n" | Where-Object {$_}).Count
      Details = $event.FormatDescription()
    }
  }
  return $findings
}

function Analyze-AccountManagement {
  param([array]$Events)
  
  Write-Verbose "Analyzing account management events..."
  $acctEvents = $Events | Where-Object Id -in @(4720,4722,4724,4726,4738,4740,4767,4781)
  $findings = @()
  
  foreach ($event in $acctEvents) {
    $eventType = switch ($event.Id) {
      4720 { "User Created" }
      4722 { "User Enabled" }
      4724 { "Password Reset" }
      4726 { "User Deleted" }
      4738 { "User Modified" }
      4740 { "User Locked Out" }
      4767 { "User Unlocked" }
      4781 { "Computer Account Changed" }
    }
    
    $findings += [pscustomobject]@{
      EventType = $eventType
      EventId = $event.Id
      TimeCreated = $event.TimeCreated
      Computer = $event.MachineName
      TargetUser = $event.Properties[0].Value
      SubjectUser = $event.Properties[4].Value
      Details = $event.FormatDescription()
    }
  }
  return $findings
}

function Analyze-LogonPatterns {
  param([array]$Events)
  
  Write-Verbose "Analyzing logon patterns..."
  $logonEvents = $Events | Where-Object Id -in @(4624,4634,4647,4648)
  $patterns = @()
  
  # Group by user and analyze logon behavior
  $userGroups = $logonEvents | Group-Object @{Expression={$_.Properties[5].Value}} # TargetUserName
  
  foreach ($ug in $userGroups) {
    $logons = $ug.Group | Where-Object Id -eq 4624
    $logoffs = $ug.Group | Where-Object Id -in @(4634,4647)
    
    if ($logons.Count -gt 0) {
      $patterns += [pscustomobject]@{
        User = $ug.Name
        LogonCount = $logons.Count
        LogoffCount = $logoffs.Count
        FirstLogon = ($logons | Sort-Object TimeCreated)[0].TimeCreated
        LastLogon = ($logons | Sort-Object TimeCreated)[-1].TimeCreated
        UniqueComputers = ($logons | ForEach-Object {$_.MachineName} | Sort-Object -Unique).Count
        LogonTypes = ($logons | ForEach-Object {$_.Properties[8].Value} | Sort-Object -Unique) -join ';'
      }
    }
  }
  return $patterns
}

function Build-Timeline {
  param([array]$Events, [string]$User, [string]$Computer, [string]$IP)
  
  Write-Verbose "Building security event timeline..."
  $filtered = $Events
  
  if ($User) { $filtered = $filtered | Where-Object { $_.FormatDescription() -like "*$User*" } }
  if ($Computer) { $filtered = $filtered | Where-Object MachineName -like "*$Computer*" }
  if ($IP) { $filtered = $filtered | Where-Object { $_.FormatDescription() -like "*$IP*" } }
  
  $timeline = @()
  foreach ($event in $filtered | Sort-Object TimeCreated) {
    $eventType = switch ($event.Id) {
      4624 { "Successful Logon" }
      4625 { "Failed Logon" }
      4634 { "Logoff" }
      4647 { "User Initiated Logoff" }
      4648 { "Explicit Credential Logon" }
      4672 { "Special Privileges Assigned" }
      4720 { "User Account Created" }
      4740 { "User Account Locked" }
      default { "Security Event $($event.Id)" }
    }
    
    $timeline += [pscustomobject]@{
      TimeCreated = $event.TimeCreated
      Computer = $event.MachineName
      EventId = $event.Id
      EventType = $eventType
      User = if ($event.Properties.Count -gt 5) { $event.Properties[5].Value } else { "N/A" }
      Details = $event.FormatDescription()
      RecordId = $event.RecordId
    }
  }
  return $timeline
}

# Main execution
function Invoke-FilterSecurityLogs {
  [CmdletBinding()]
  param()

  begin {
    $allEvents = @()
    $analysisResults = @{
      BruteForce = @()
      PrivilegeEscalation = @()
      AccountManagement = @()
      LogonPatterns = @()
      Timeline = @()
    }
    
    # Determine which event IDs to collect based on analysis type
    $eventIds = if ($AnalysisType -eq 'All') {
      $SecurityEvents.Values | ForEach-Object { $_ } | Sort-Object -Unique
    } else {
      $SecurityEvents[$AnalysisType]
    }
    
    Write-Verbose "Collecting Event IDs: $($eventIds -join ',')"
  }

  process {
    foreach ($computer in $ComputerName) {
      Write-Verbose "Collecting security events from $computer..."
      $events = Get-SecurityEvents -Computer $computer -EventIds $eventIds -Start $StartTime -End $EndTime -Cred $Credential
      $allEvents += $events
      Write-Verbose "Collected $($events.Count) events from $computer"
    }
  }

  end {
    if ($allEvents.Count -eq 0) {
      Write-Warning "No security events collected in the specified time range."
      return
    }
    
    Write-Verbose "Analyzing $($allEvents.Count) security events..."
    
    # Run analyses based on type
    if ($AnalysisType -in @('BruteForce','All')) {
      $analysisResults.BruteForce = Analyze-BruteForce -Events $allEvents -Threshold $BruteForceThreshold
    }
    
    if ($AnalysisType -in @('PrivilegeEscalation','All')) {
      $analysisResults.PrivilegeEscalation = Analyze-PrivilegeEscalation -Events $allEvents
    }
    
    if ($AnalysisType -in @('AccountManagement','All')) {
      $analysisResults.AccountManagement = Analyze-AccountManagement -Events $allEvents
    }
    
    if ($AnalysisType -in @('LogonAnalysis','All')) {
      $analysisResults.LogonPatterns = Analyze-LogonPatterns -Events $allEvents
    }
    
    if ($AnalysisType -in @('Timeline','All')) {
      $analysisResults.Timeline = Build-Timeline -Events $allEvents -User $TargetUser -Computer $TargetComputer -IP $TargetIP
    }
    
    # Output results
    if ($OutputCsv) {
      $allEvents | Select-Object TimeCreated,Id,MachineName,@{n='Description';e={$_.FormatDescription()}} | 
        Export-Csv -Path $OutputCsv -NoTypeInformation
      Write-Host "Detailed events exported to: $OutputCsv" -ForegroundColor Green
    }
    
    if ($OutputTimeline -and $analysisResults.Timeline) {
      $analysisResults.Timeline | Export-Csv -Path $OutputTimeline -NoTypeInformation
      Write-Host "Timeline exported to: $OutputTimeline" -ForegroundColor Green
    }
    
    if ($OutputSummaryJson) {
      $summary = @{
        AnalysisType = $AnalysisType
        TimeRange = @{ Start=$StartTime; End=$EndTime }
        TotalEvents = $allEvents.Count
        BruteForceFindings = $analysisResults.BruteForce.Count
        PrivilegeEscalationEvents = $analysisResults.PrivilegeEscalation.Count
        AccountManagementEvents = $analysisResults.AccountManagement.Count
        TimelineEvents = $analysisResults.Timeline.Count
        Findings = $analysisResults
      }
      $summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputSummaryJson -Encoding UTF8
      Write-Host "Summary analysis exported to: $OutputSummaryJson" -ForegroundColor Green
    }
    
    # Console output summary
    Write-Host "`n=== SECURITY LOG ANALYSIS SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Analysis Period: $StartTime to $EndTime" -ForegroundColor Yellow
    Write-Host "Total Security Events: $($allEvents.Count)" -ForegroundColor Yellow
    
    if ($analysisResults.BruteForce) {
      Write-Host "`nBrute Force Attempts Detected: $($analysisResults.BruteForce.Count)" -ForegroundColor Red
      $analysisResults.BruteForce | Format-Table TargetUser,SourceIP,FailedAttempts,Duration -AutoSize
    }
    
    if ($analysisResults.PrivilegeEscalation) {
      Write-Host "`nPrivilege Escalation Events: $($analysisResults.PrivilegeEscalation.Count)" -ForegroundColor Magenta
      $analysisResults.PrivilegeEscalation | Select-Object TimeCreated,User,EventId | Format-Table -AutoSize
    }
    
    if ($analysisResults.AccountManagement) {
      Write-Host "`nAccount Management Activities: $($analysisResults.AccountManagement.Count)" -ForegroundColor Blue
      $analysisResults.AccountManagement | Select-Object TimeCreated,EventType,TargetUser,SubjectUser | Format-Table -AutoSize
    }
    
    if ($analysisResults.LogonPatterns) {
      Write-Host "`nLogon Pattern Analysis:" -ForegroundColor Green
      $analysisResults.LogonPatterns | Format-Table User,LogonCount,LogoffCount,UniqueComputers -AutoSize
    }
  }
}

Invoke-FilterSecurityLogs