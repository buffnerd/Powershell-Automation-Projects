<#
.SYNOPSIS
  Monitor critical Windows services across one or more computers and report issues.

.DESCRIPTION
  - Checks that required services are Running (and optionally set to Automatic/Automatic (Delayed)).
  - Optional: validate dependent services are also Running.
  - Optional: continuous mode (poll at interval for a duration).
  - Emits a structured table and optional CSV for dashboards/SIEM ingestion.
  - Safe for large fleets; uses Get-Service remotely (WinRM) with optional credentials.

.PARAMETER ComputerName
  One or more computers to check. Defaults to local machine.

.PARAMETER Services
  One or more service names (ServiceName, not DisplayName), e.g. 'Spooler','LanmanServer'.

.PARAMETER Credential
  Optional PSCredential for remote hosts (cross-domain/workgroup).

.PARAMETER RequireAutomaticStart
  If set, service StartupType must be Automatic or AutomaticDelayed.

.PARAMETER CheckDependencies
  If set, also verify that required dependent services are Running.

.PARAMETER IntervalSeconds
  In continuous mode, seconds between polls (default 30).

.PARAMETER DurationSeconds
  If > 0, run for this many seconds (continuous mode). If 0, run once and exit (default: 0).

.PARAMETER OutputCsv
  Optional path to export results each cycle. If in continuous mode, appends per cycle with timestamp.

.PARAMETER FailNonZeroExit
  If set, script exits with code 1 when any monitored service is not healthy (useful for pipelines).

.EXAMPLES
  # One-shot check on two servers
  .\MonitorCriticalServices.ps1 -ComputerName app01,app02 -Services 'W3SVC','Schedule' -RequireAutomaticStart -Verbose

  # Continuous 15-minute monitor every 60s and log to CSV
  .\MonitorCriticalServices.ps1 -ComputerName (gc .\servers.txt) -Services 'Spooler','LanmanServer' `
    -CheckDependencies -DurationSeconds 900 -IntervalSeconds 60 -OutputCsv .\svc_health.csv

.REQUIREMENTS
  - PowerShell Remoting enabled on targets (WinRM) OR run locally.
  - Permissions to query services remotely.
  - For StartupType checks, queries registry via CIM/WMI.

.NOTES (Environment adjustments & future GUI prompts)
  - Target selection (list/file/AD OU) → GUI picker.
  - Service list (chips/multi-select) → GUI control.
  - Interval & duration → numeric inputs (with "run once" toggle).
  - Exports → Save As path.
  - Credential prompt for cross-domain/workgroup.
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter(Mandatory)]
  [string[]]$Services,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [switch]$RequireAutomaticStart,

  [Parameter()]
  [switch]$CheckDependencies,

  [Parameter()]
  [ValidateRange(5, 3600)]
  [int]$IntervalSeconds = 30,

  [Parameter()]
  [ValidateRange(0, 86400)]
  [int]$DurationSeconds = 0,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [switch]$FailNonZeroExit
)

# Helper: get StartupType via WMI/CIM (more reliable than Get-Service for this property)
function Get-StartupType {
  param([string]$Computer,[string]$Name,[pscredential]$Cred)
  $sb = {
    param($svc)
    try {
      $wmi = Get-WmiObject -Class Win32_Service -Filter ("Name='{0}'" -f $svc) -ErrorAction Stop
      # Map Win32_Service.StartMode -> human-friendly
      switch ($wmi.StartMode) {
        'Auto'          { return 'Automatic' }
        'Manual'        { return 'Manual' }
        'Disabled'      { return 'Disabled' }
        default         { return $wmi.StartMode }
      }
    } catch { return $null }
  }
  try {
    if ($Cred) { return Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock $sb -ArgumentList $Name -ErrorAction Stop }
    else       { return Invoke-Command -ComputerName $Computer -ScriptBlock $sb -ArgumentList $Name -ErrorAction Stop }
  } catch { return $null }
}

# Helper: check a single computer's services
function Test-ComputerServices {
  param([string]$Computer,[string[]]$SvcList,[pscredential]$Cred,[bool]$NeedAuto,[bool]$Deps)
  $rows = New-Object System.Collections.Generic.List[Object]

  foreach ($svc in $SvcList) {
    try {
      $s = if ($Cred) { Get-Service -ComputerName $Computer -Name $svc -ErrorAction Stop }
           else       { Get-Service -ComputerName $Computer -Name $svc -ErrorAction Stop }

      $startup = $null
      if ($NeedAuto) { $startup = Get-StartupType -Computer $Computer -Name $svc -Cred $Cred }

      $depIssues = $null
      if ($Deps -and $s.ServicesDependedOn) {
        $bad = @()
        foreach ($d in $s.ServicesDependedOn) {
          try {
            $ds = if ($Cred) { Get-Service -ComputerName $Computer -Name $d.Name -ErrorAction Stop }
                  else       { Get-Service -ComputerName $Computer -Name $d.Name -ErrorAction Stop }
            if ($ds.Status -ne 'Running') { $bad += "$($d.Name):$($ds.Status)" }
          } catch { $bad += "$($d.Name):Unknown" }
        }
        if ($bad.Count -gt 0) { $depIssues = ($bad -join '; ') }
      }

      $autoOk = $true
      if ($NeedAuto) { $autoOk = ($startup -eq 'Automatic' -or $startup -eq 'Automatic (Delayed Start)' -or $startup -eq 'AutomaticDelayed') }

      $healthy = ($s.Status -eq 'Running') -and $autoOk -and (-not $depIssues)
      $rows.Add([pscustomobject]@{
        ComputerName     = $Computer
        ServiceName      = $s.Name
        DisplayName      = $s.DisplayName
        Status           = $s.Status
        StartupType      = $startup
        RequiresAuto     = $NeedAuto
        AutoCompliant    = $autoOk
        DependencyIssues = $depIssues
        Healthy          = $healthy
        CheckedAt        = (Get-Date)
      })

    } catch {
      $rows.Add([pscustomobject]@{
        ComputerName     = $Computer
        ServiceName      = $svc
        DisplayName      = $null
        Status           = 'Unknown'
        StartupType      = $null
        RequiresAuto     = $NeedAuto
        AutoCompliant    = $false
        DependencyIssues = 'QueryError'
        Healthy          = $false
        CheckedAt        = (Get-Date)
      })
    }
  }

  return $rows
}

$results = New-Object System.Collections.Generic.List[Object]
$endAt   = if ($DurationSeconds -gt 0) { (Get-Date).AddSeconds($DurationSeconds) } else { Get-Date }  # run once if duration = 0

do {
  foreach ($cn in $ComputerName) {
    $rows = Test-ComputerServices -Computer $cn -SvcList $Services -Cred $Credential -NeedAuto:$RequireAutomaticStart.IsPresent -Deps:$CheckDependencies.IsPresent
    $results.AddRange($rows)
  }

  # Emit to screen
  $cycle = $results | Sort-Object ComputerName, ServiceName | Select-Object ComputerName,ServiceName,Status,StartupType,AutoCompliant,DependencyIssues,Healthy,CheckedAt
  $cycle | Format-Table -AutoSize

  # CSV (append with timestamp)
  if ($OutputCsv) {
    try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Append -Force } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
  }

  # Continuous mode sleep
  if ($DurationSeconds -gt 0 -and (Get-Date) -lt $endAt) {
    Start-Sleep -Seconds $IntervalSeconds
    $results.Clear() | Out-Null
  } else {
    break
  }
} while ($true)

if ($FailNonZeroExit) {
  if ($cycle | Where-Object { -not $_.Healthy }) { exit 1 } else { exit 0 }
}