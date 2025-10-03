<#
.SYNOPSIS
  Verify recent backup success across one or more machines for several backup engines.

.DESCRIPTION
  For each target computer and for each requested "engine" (WSB, Veeam, AzureBackup, GenericPath),
  the script determines whether backups have succeeded within a given time window and collects
  basic health indicators. Designed to run quickly with minimal privileges (read logs, query services).

  Engines supported:
   - WSB           : Windows Server Backup via 'Microsoft-Windows-Backup' event log and wbadmin.
   - Veeam         : Veeam Agent / Veeam B&R via services & event log sources ('Veeam Agent', 'Veeam Backup').
   - AzureBackup   : Microsoft Azure Recovery Services Agent (MARS) via service presence & event log.
   - GenericPath   : Validate a backup repository folder has new/updated files within the time window.

.PARAMETER ComputerName
  One or more computers (default: local).

.PARAMETER Credential
  Optional PS credential for remote queries.

.PARAMETER Engines
  One or more engines to check: WSB, Veeam, AzureBackup, GenericPath.

.PARAMETER LookbackHours
  Time window for "recent success" checks (default: 26).

.PARAMETER GenericPath
  For 'GenericPath' engine: path to a folder to verify (UNC or local on target).

.PARAMETER GenericMinGrowthMB
  (GenericPath) Minimum total new/updated bytes over the window to consider Healthy (default: 10 MB).

.PARAMETER OutputCsv
  Optional CSV path for results.

.PARAMETER OutputHtml
  Optional HTML report path.

.PARAMETER FailNonZeroExit
  Exit 1 if any row is Unhealthy or NotProtected (good for schedulers/CI).

.EXAMPLES
  # Quick check for Windows Server Backup in the last 24–26 hours on two hosts
  .\CheckBackupStatus.ps1 -ComputerName FS01,APP02 -Engines WSB -LookbackHours 26 -OutputCsv .\backup_status.csv

  # Veeam + Azure MARS check across a fleet, HTML report
  .\CheckBackupStatus.ps1 -ComputerName (gc .\hosts.txt) -Engines Veeam,AzureBackup -OutputHtml .\backup.html

  # Generic NAS target freshness (expect at least 500 MB growth)
  .\CheckBackupStatus.ps1 -ComputerName BKP-PROXY -Engines GenericPath -GenericPath '\\nas01\backups\APP02' -GenericMinGrowthMB 500

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Engine selection: -Engines WSB,Veeam,AzureBackup,GenericPath (checkboxes)
  - Time window: -LookbackHours (slider)
  - Generic path freshness: -GenericPath (folder picker), -GenericMinGrowthMB (numeric)
  - Targets: -ComputerName (textbox/file/AD OU picker)
  - Credentials: -Credential
  - Exports: -OutputCsv, -OutputHtml
  - CI/Scheduler: -FailNonZeroExit checkbox
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter(Mandatory)]
  [ValidateSet('WSB','Veeam','AzureBackup','GenericPath')]
  [string[]]$Engines,

  [Parameter()]
  [ValidateRange(1, 168)]
  [int]$LookbackHours = 26,

  [Parameter()]
  [string]$GenericPath,

  [Parameter()]
  [int]$GenericMinGrowthMB = 10,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputHtml,

  [Parameter()]
  [switch]$FailNonZeroExit
)

# -------------------------------
# Helpers that run on the TARGET
# -------------------------------
$sbCheck = {
  param($engines,$windowHours,$genericPath,$genericMinGrowthMB)

  function Get-RecentWinEvents {
    param([string[]]$LogNames,[int[]]$Ids)
    $start = (Get-Date).AddHours(-1 * $windowHours)
    $fh = @{ StartTime = $start; EndTime = (Get-Date) }
    $all = @()
    foreach ($log in $LogNames) {
      $flt = $fh.Clone()
      $flt['LogName'] = $log
      if ($Ids) { $flt['Id'] = $Ids }
      try { $all += Get-WinEvent -FilterHashtable $flt -ErrorAction Stop } catch { }
    }
    return $all
  }

  function Invoke-SafeCommand {
    param([scriptblock]$Code)
    try { & $Code } catch { $null }
  }

  $rows = New-Object System.Collections.Generic.List[Object]

  foreach ($engine in $engines) {
    switch ($engine) {

      'WSB' {
        # Windows Server Backup: look for Success event 4 in Microsoft-Windows-Backup/Operational
        # Also scan for Error 5/9/546 to flag failures.
        $events = Get-RecentWinEvents -LogNames @('Microsoft-Windows-Backup') -Ids @(4,5,9,546,547)
        $lastSuccess = $events | Where-Object { $_.Id -eq 4 } | Sort-Object TimeCreated -Descending | Select-Object -First 1
        $lastError   = $events | Where-Object { $_.Id -in 5,9,546,547 } | Sort-Object TimeCreated -Descending | Select-Object -First 1

        # wbadmin sanity (optional): get latest version timestamp
        $wb = Invoke-SafeCommand { wbadmin get versions | Out-String }
        $wbLatest = $null
        if ($wb -and ($wb -match 'Version identifier:\s*(.*)')) {
          # best effort parse; not all locales format the same
          $wbLatest = (Get-Date) 2>$null
        }

        $status = if ($lastSuccess -and ($lastSuccess.TimeCreated -ge (Get-Date).AddHours(-1 * $windowHours))) {
          'Healthy'
        } elseif ($lastError) { 'Unhealthy' } else { 'NotProtected' }

        $rows.Add([pscustomobject]@{
          ComputerName    = $env:COMPUTERNAME
          Engine          = 'WSB'
          LastSuccessUtc  = if ($lastSuccess) { $lastSuccess.TimeCreated.ToUniversalTime() } else { $null }
          LastErrorUtc    = if ($lastError) { $lastError.TimeCreated.ToUniversalTime() } else { $null }
          Status          = $status
          Note            = if ($lastError) { $lastError.FormatDescription() } else { $null }
        })
      }

      'Veeam' {
        # Veeam Agent / B&R: look for info/success and error events from Veeam logs in Application
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Veeam' }
        $events = Get-RecentWinEvents -LogNames @('Application') -Ids @() | Where-Object {
          $_.ProviderName -like 'Veeam*'
        }
        $ok  = $events | Where-Object { $_.LevelDisplayName -in 'Information','Informational' -and $_.Message -match 'succeeded|completed' } |
               Sort-Object TimeCreated -Descending | Select-Object -First 1
        $err = $events | Where-Object { $_.LevelDisplayName -in 'Error','Warning' -and $_.Message -match 'fail|error|warning' } |
               Sort-Object TimeCreated -Descending | Select-Object -First 1

        $status = if ($ok -and ($ok.TimeCreated -ge (Get-Date).AddHours(-1 * $windowHours))) {
          'Healthy'
        } elseif ($svc) {
          if ($err) { 'Unhealthy' } else { 'Unknown' }
        } else {
          'NotProtected'
        }

        $rows.Add([pscustomobject]@{
          ComputerName    = $env:COMPUTERNAME
          Engine          = 'Veeam'
          LastSuccessUtc  = if ($ok) { $ok.TimeCreated.ToUniversalTime() } else { $null }
          LastErrorUtc    = if ($err) { $err.TimeCreated.ToUniversalTime() } else { $null }
          Status          = $status
          Note            = if ($err) { $err.Message } else { ($svc ? 'Services present' : 'No Veeam services detected') }
        })
      }

      'AzureBackup' {
        # MARS Agent: service 'OBEngine' + events from 'Azure Backup' providers in Application
        $svc = Get-Service -Name 'OBEngine' -ErrorAction SilentlyContinue
        $events = Get-RecentWinEvents -LogNames @('Application') -Ids @() | Where-Object {
          $_.ProviderName -like 'Azure*Backup*' -or $_.ProviderName -like 'OBengine*'
        }
        $ok = $events | Where-Object { $_.Message -match 'completed|succeeded' } |
              Sort-Object TimeCreated -Descending | Select-Object -First 1
        $err= $events | Where-Object { $_.LevelDisplayName -in 'Error','Warning' -and $_.Message -match 'fail|error|warning' } |
              Sort-Object TimeCreated -Descending | Select-Object -First 1

        $status = if ($ok -and ($ok.TimeCreated -ge (Get-Date).AddHours(-1 * $windowHours))) {
          'Healthy'
        } elseif ($svc) {
          if ($err) { 'Unhealthy' } else { 'Unknown' }
        } else {
          'NotProtected'
        }

        $rows.Add([pscustomobject]@{
          ComputerName    = $env:COMPUTERNAME
          Engine          = 'AzureBackup'
          LastSuccessUtc  = if ($ok) { $ok.TimeCreated.ToUniversalTime() } else { $null }
          LastErrorUtc    = if ($err) { $err.TimeCreated.ToUniversalTime() } else { $null }
          Status          = $status
          Note            = if ($err) { $err.Message } else { ($svc ? 'OBEngine present' : 'No MARS agent detected') }
        })
      }

      'GenericPath' {
        # Validate a backup target folder has had activity (new or updated bytes) within the window.
        if (-not $genericPath) {
          $rows.Add([pscustomobject]@{
            ComputerName=$env:COMPUTERNAME; Engine='GenericPath'; LastSuccessUtc=$null; LastErrorUtc=$null; Status='Unknown'; Note='GenericPath parameter required'
          })
          continue
        }

        $start = (Get-Date).AddHours(-1 * $windowHours)
        $files = Get-ChildItem -LiteralPath $genericPath -Recurse -ErrorAction SilentlyContinue
        if (-not $files) {
          $rows.Add([pscustomobject]@{
            ComputerName=$env:COMPUTERNAME; Engine='GenericPath'; LastSuccessUtc=$null; LastErrorUtc=$null; Status='NotProtected'; Note='No files enumerated'
          })
          continue
        }

        $recent = $files | Where-Object { $_.LastWriteTime -ge $start }
        $growth = ($recent | Measure-Object -Property Length -Sum).Sum
        $status = if ($growth -ge ($genericMinGrowthMB * 1MB)) { 'Healthy' } else { 'Unhealthy' }

        $rows.Add([pscustomobject]@{
          ComputerName   = $env:COMPUTERNAME
          Engine         = 'GenericPath'
          LastSuccessUtc = if ($recent) { ($recent | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToUniversalTime() } else { $null }
          LastErrorUtc   = $null
          Status         = $status
          Note           = "Recent growth: {0:N0} MB" -f ($growth/1MB)
        })
      }
    }
  }

  return $rows
}

function Invoke-RemoteCommand {
  param([string]$Computer,[pscredential]$Cred,[scriptblock]$Block,[object[]]$ArgumentList)
  if ($Cred) { Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock $Block -ArgumentList $ArgumentList -ErrorAction Stop }
  else       { Invoke-Command -ComputerName $Computer               -ScriptBlock $Block -ArgumentList $ArgumentList -ErrorAction Stop }
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($cn in $ComputerName) {
  try {
    $rows = Invoke-RemoteCommand -Computer $cn -Cred $Credential -Block $sbCheck -ArgumentList @($Engines,$LookbackHours,$GenericPath,$GenericMinGrowthMB)
    foreach ($r in $rows) { $results.Add($r) }
  } catch {
    $results.Add([pscustomobject]@{
      ComputerName = $cn
      Engine       = ($Engines -join ',')
      LastSuccessUtc = $null
      LastErrorUtc = $null
      Status       = 'Unknown'
      Note         = $_.Exception.Message
    })
  }
}

# Output targets
$results | Sort-Object ComputerName, Engine | Format-Table -AutoSize

# Optional exports
if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}
if ($OutputHtml) {
  $style = @"
<style>
table { border-collapse: collapse; font-family: Segoe UI, Arial, sans-serif; font-size: 12px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; }
th { background: #f4f4f4; text-align: left; }
tr.bad { background: #fff5f5; }
tr.warn { background: #fffaf0; }
</style>
"@
  $html = $results | ConvertTo-Html -Title "Backup Verification" -Head $style -PreContent "<h2>Backup Verification</h2><p>Generated: $(Get-Date)</p>"
  try { $html | Out-File -FilePath $OutputHtml -Encoding UTF8 } catch { Write-Warning "HTML export failed: $($_.Exception.Message)" }
}

# Exit code for schedulers
if ($FailNonZeroExit) {
  if ($results.Status -contains 'Unhealthy' -or $results.Status -contains 'NotProtected') { exit 1 } else { exit 0 }
}