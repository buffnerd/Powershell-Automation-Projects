<#
.SYNOPSIS
  Create a quick health report per computer (uptime, CPU/mem snapshot, disk low space, services).

.DESCRIPTION
  - Gathers OS info, uptime, quick CPU/mem snapshot, disk space alerts.
  - Optionally checks for pending reboot indicators.
  - Optionally checks status of critical services.
  - Output as HTML (with basic styling) or CSV.

.PARAMETER ComputerName
  One or more computers. Default local.

.PARAMETER Credential
  Optional credential for remote queries.

.PARAMETER CpuWarnPercent
  Warn threshold for CPU snapshot.

.PARAMETER MinAvailMB
  Warn threshold for memory snapshot.

.PARAMETER MinFreePercent
  Disk free % threshold for alerts.

.PARAMETER MinFreeGB
  Disk free GB threshold for alerts.

.PARAMETER CriticalServices
  One or more service names to verify running (e.g., 'LanmanServer','Dnscache').

.PARAMETER OutputHtml
  Path for HTML report.

.PARAMETER OutputCsv
  Path for CSV report.

.EXAMPLES
  PS> .\HealthReport.ps1 -ComputerName server01,server02 -CriticalServices 'LanmanServer','Dnscache' -OutputHtml .\health.html
  PS> .\HealthReport.ps1 -ComputerName (gc .\servers.txt) -OutputCsv .\health.csv -MinFreePercent 15 -MinFreeGB 10

.REQUIREMENTS
  - CIM/WinRM open for remote queries.
  - Rights to read system information & services.

.NOTES (Environment adjustments & future GUI prompts)
  - Target selection: list/file/AD (GUI).
  - Thresholds: inputs (GUI).
  - Service picker: multi-select (GUI).
  - Output format: radio (HTML/CSV) + Save As (GUI).
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [ValidateRange(1,100)]
  [int]$CpuWarnPercent = 85,

  [Parameter()]
  [int]$MinAvailMB = 1024,

  [Parameter()]
  [ValidateRange(1,100)]
  [int]$MinFreePercent = 10,

  [Parameter()]
  [int]$MinFreeGB = 5,

  [Parameter()]
  [string[]]$CriticalServices = @('LanmanServer','Dnscache'),

  [Parameter()]
  [string]$OutputHtml,

  [Parameter()]
  [string]$OutputCsv
)

begin {
  $rows = New-Object System.Collections.Generic.List[Object]
  $sessions = @{}
}

process {
  foreach ($cn in $ComputerName) {
    try {
      if ($Credential) {
        $sessions[$cn] = New-CimSession -ComputerName $cn -Credential $Credential -ErrorAction Stop
      } else {
        $sessions[$cn] = New-CimSession -ComputerName $cn -ErrorAction Stop
      }
    } catch {
      Write-Warning "Failed CIM session to '$cn': $($_.Exception.Message)"
      continue
    }

    # OS & uptime
    try {
      $os = Get-CimInstance -CimSession $sessions[$cn] -ClassName Win32_OperatingSystem -ErrorAction Stop
      $cs = Get-CimInstance -CimSession $sessions[$cn] -ClassName Win32_ComputerSystem -ErrorAction Stop
      $lastBoot = $os.LastBootUpTime
      $uptime = (Get-Date) - $lastBoot
    } catch {
      Write-Warning "Failed to get OS info on '$cn': $($_.Exception.Message)"
      continue
    }

    # CPU/Memory snapshot (fast)
    try {
      if ($Credential) {
        $cpuCounter = (Get-Counter -ComputerName $cn '\Processor(_Total)\% Processor Time' -Credential $Credential -ErrorAction Stop).CounterSamples.CookedValue | Select-Object -First 1
      } else {
        $cpuCounter = (Get-Counter -ComputerName $cn '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples.CookedValue | Select-Object -First 1
      }
    } catch { $cpuCounter = $null }

    try {
      if ($Credential) {
        $memCounter = (Get-Counter -ComputerName $cn '\Memory\Available MBytes' -Credential $Credential -ErrorAction Stop).CounterSamples.CookedValue | Select-Object -First 1
      } else {
        $memCounter = (Get-Counter -ComputerName $cn '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples.CookedValue | Select-Object -First 1
      }
    } catch { $memCounter = $null }

    $cpuWarn = ($cpuCounter -ne $null -and [double]$cpuCounter -ge $CpuWarnPercent)
    $memWarn = ($memCounter -ne $null -and [double]$memCounter -lt $MinAvailMB)

    # Disk check (reuse logic)
    $diskAlerts = @()
    try {
      $disks = Get-CimInstance -CimSession $sessions[$cn] -ClassName Win32_LogicalDisk -Filter "DriveType=3"
      foreach ($d in $disks) {
        $sizeGB = [math]::Round(($d.Size/1GB),2)
        $freeGB = [math]::Round(($d.FreeSpace/1GB),2)
        $freePC = if ($d.Size -gt 0) { [math]::Round(($d.FreeSpace / $d.Size * 100),2) } else { 0 }
        if (($freePC -lt $MinFreePercent) -or ($freeGB -lt $MinFreeGB)) {
          $diskAlerts += "$($d.DeviceID) ($freePC`% / $freeGB GB free)"
        }
      }
    } catch {
      Write-Warning "Disk query failed on '$cn': $($_.Exception.Message)"
    }

    # Pending reboot indicators (registry checks)
    $pendingReboot = $false
    try {
      $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $cn)
      $paths = @(
        'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
      )
      foreach ($p in $paths) {
        if ($reg.OpenSubKey($p)) { $pendingReboot = $true; break }
      }
      $reg.Close()
    } catch {
      # Non-fatal
    }

    # Critical services
    $svcIssues = @()
    foreach ($svc in $CriticalServices) {
      try {
        $s = Get-Service -ComputerName $cn -Name $svc -ErrorAction Stop
        if ($s.Status -ne 'Running') { $svcIssues += "$svc`:$($s.Status)" }
      } catch {
        $svcIssues += "$svc`:NotFound"
      }
    }

    $rows.Add([pscustomobject]@{
      ComputerName   = $cn
      OS             = $os.Caption
      Version        = $os.Version
      Manufacturer   = $cs.Manufacturer
      Model          = $cs.Model
      UptimeDays     = [int]$uptime.TotalDays
      LastBoot       = $lastBoot
      CpuNowPercent  = if ($cpuCounter -ne $null) { [math]::Round($cpuCounter,2) } else { $null }
      MemAvailMB     = if ($memCounter -ne $null) { [math]::Round($memCounter,0) } else { $null }
      CpuWarnThresh  = $CpuWarnPercent
      MemWarnThresh  = $MinAvailMB
      CpuWarning     = $cpuWarn
      MemWarning     = $memWarn
      DiskAlerts     = ($diskAlerts -join '; ')
      PendingReboot  = $pendingReboot
      ServiceIssues  = ($svcIssues -join '; ')
    })
  }
}

end {
  if ($OutputCsv) {
    try {
      $rows | Export-Csv -Path $OutputCsv -NoTypeInformation
      Write-Verbose "Wrote CSV '$OutputCsv'."
    } catch {
      Write-Warning "Failed to write CSV '$OutputCsv': $($_.Exception.Message)"
    }
  }

  if ($OutputHtml) {
    $style = @"
<style>
table { border-collapse: collapse; font-family: Segoe UI, Arial, sans-serif; font-size: 12px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; }
th { background: #f4f4f4; text-align: left; }
tr:nth-child(even) { background: #fafafa; }
.warn { color: #b30000; font-weight: 600; }
</style>
"@
    $html = $rows | Select-Object ComputerName,OS,Version,Manufacturer,Model,UptimeDays,LastBoot,
      CpuNowPercent,MemAvailMB,CpuWarnThresh,MemWarnThresh,CpuWarning,MemWarning,
      DiskAlerts,PendingReboot,ServiceIssues |
      ConvertTo-Html -Title "System Health Report" -Head $style -PreContent "<h2>System Health Report</h2><p>Generated: $(Get-Date)</p>"
    try {
      $html | Out-File -FilePath $OutputHtml -Encoding UTF8
      Write-Verbose "Wrote HTML '$OutputHtml'."
    } catch {
      Write-Warning "Failed to write HTML '$OutputHtml': $($_.Exception.Message)"
    }
  }

  if (-not $OutputCsv -and -not $OutputHtml) {
    $rows | Sort-Object ComputerName | Format-Table -AutoSize
  }

  foreach ($s in $sessions.Values) { try { $s | Remove-CimSession -ErrorAction SilentlyContinue } catch {} }
}