<#
.SYNOPSIS
  Monitor CPU and memory over a time window and report averages/peaks.

.DESCRIPTION
  Uses Get-Counter to sample:
    - \Processor(_Total)\% Processor Time
    - \Memory\Available MBytes
  Calculates average and maximum CPU%; average and minimum Available MB.
  Thresholds can be provided to flag warnings.

.PARAMETER ComputerName
  One or more computers to sample. Default local machine.

.PARAMETER DurationSeconds
  Total duration to monitor (default: 60 seconds).

.PARAMETER SampleIntervalSeconds
  Interval between samples (default: 5 seconds).

.PARAMETER CpuWarnPercent
  If average CPU exceeds this %, flag warning.

.PARAMETER MinAvailMB
  If average available memory falls below this MB, flag warning.

.PARAMETER Credential
  Optional credential for remote sampling.

.PARAMETER OutputCsv
  Optional CSV output for results.

.EXAMPLES
  PS> .\MemoryCpuMonitor.ps1 -ComputerName server01 -DurationSeconds 120 -SampleIntervalSeconds 5 -CpuWarnPercent 80 -MinAvailMB 1024 -Verbose
  PS> .\MemoryCpuMonitor.ps1 -ComputerName (Get-Content .\servers.txt) -DurationSeconds 30 -SampleIntervalSeconds 2 -OutputCsv .\perf.csv

.REQUIREMENTS
  - Performance counters enabled/available.
  - Remote permissions and firewall rules if using remote hosts.

.NOTES (Environment adjustments & future GUI prompts)
  - Targets: list/file/AD query (GUI).
  - Interval/duration: numeric inputs (GUI).
  - Thresholds: sliders (GUI).
  - Credential prompt when needed (GUI).
  - Export path picker (GUI).
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [ValidateRange(5, 3600)]
  [int]$DurationSeconds = 60,

  [Parameter()]
  [ValidateRange(1, 60)]
  [int]$SampleIntervalSeconds = 5,

  [Parameter()]
  [ValidateRange(1,100)]
  [int]$CpuWarnPercent = 85,

  [Parameter()]
  [int]$MinAvailMB = 1024,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string]$OutputCsv
)

begin {
  $results = New-Object System.Collections.Generic.List[Object]
  $cpuPath = '\Processor(_Total)\% Processor Time'
  $memPath = '\Memory\Available MBytes'
}

process {
  foreach ($cn in $ComputerName) {
    $samples = [math]::Ceiling($DurationSeconds / $SampleIntervalSeconds)
    Write-Verbose "Sampling $cn for $DurationSeconds sec ($samples samples every $SampleIntervalSeconds sec)."

    $cpuVals = New-Object System.Collections.Generic.List[double]
    $memVals = New-Object System.Collections.Generic.List[double]

    for ($i=1; $i -le $samples; $i++) {
      try {
        if ($Credential) {
          $cpu = Get-Counter -Counter $cpuPath -ComputerName $cn -Credential $Credential -ErrorAction Stop | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
          $mem = Get-Counter -Counter $memPath -ComputerName $cn -Credential $Credential -ErrorAction Stop | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
        } else {
          $cpu = Get-Counter -Counter $cpuPath -ComputerName $cn -ErrorAction Stop | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
          $mem = Get-Counter -Counter $memPath -ComputerName $cn -ErrorAction Stop | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
        }

        $cpuVals.Add([double]$cpu)
        $memVals.Add([double]$mem)
      } catch {
        Write-Warning "Failed to sample $cn at iteration $i`: $($_.Exception.Message)"
      }

      if ($i -lt $samples) { Start-Sleep -Seconds $SampleIntervalSeconds }
    }

    if ($cpuVals.Count -eq 0 -or $memVals.Count -eq 0) {
      Write-Warning "No samples collected for $cn."
      continue
    }

    $cpuAvg = [math]::Round(($cpuVals | Measure-Object -Average).Average,2)
    $cpuMax = [math]::Round(($cpuVals | Measure-Object -Maximum).Maximum,2)
    $memAvg = [math]::Round(($memVals | Measure-Object -Average).Average,2)
    $memMin = [math]::Round(($memVals | Measure-Object -Minimum).Minimum,2)

    $warnCPU = ($cpuAvg -ge $CpuWarnPercent)
    $warnMEM = ($memAvg -lt $MinAvailMB)

    $row = [pscustomobject]@{
      ComputerName  = $cn
      Samples       = $cpuVals.Count
      CpuAvgPercent = $cpuAvg
      CpuMaxPercent = $cpuMax
      MemAvgMB      = $memAvg
      MemMinMB      = $memMin
      CpuWarnThresh = $CpuWarnPercent
      MemWarnThresh = $MinAvailMB
      CpuWarning    = $warnCPU
      MemWarning    = $warnMEM
    }
    $results.Add($row)
  }
}

end {
  if ($OutputCsv) {
    try {
      $results | Export-Csv -Path $OutputCsv -NoTypeInformation
      Write-Verbose "Wrote CSV '$OutputCsv'."
    } catch {
      Write-Warning "Failed to write CSV '$OutputCsv': $($_.Exception.Message)"
    }
  }
  $results | Sort-Object ComputerName | Format-Table -AutoSize
}