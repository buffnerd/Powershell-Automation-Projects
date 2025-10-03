<#
.SYNOPSIS
  Collect Windows event logs from one or more computers for a time window, channels, and (optional) Event IDs/providers.

.DESCRIPTION
  Uses Get-WinEvent with FilterHashtable to query logs on remote or local machines, filters by:
    - TimeCreated range (StartTime / EndTime)
    - LogName (channels), e.g., 'System','Application','Security'
    - Id (event ID list)
    - ProviderName (source list)
  Exports to CSV and/or JSONL; optionally also exports raw .evtx files using wevtutil (pulls them back to a local folder).

.PARAMETER ComputerName
  One or more computers. Default is local machine.

.PARAMETER Credential
  Optional PSCredential for remote collection.

.PARAMETER Channels
  One or more event channels (log names). Default: 'System','Application'.

.PARAMETER EventId
  Optional one or more event IDs to include (e.g., 4624,4625).

.PARAMETER Provider
  Optional one or more provider names to include (e.g., 'Microsoft-Windows-Security-Auditing').

.PARAMETER StartTime
  Inclusive start time (default: (Get-Date).AddDays(-1)).

.PARAMETER EndTime
  Exclusive end time (default: now).

.PARAMETER MaxEventsPerHost
  Soft cap per host (0 = unlimited). Helpful to keep exports manageable.

.PARAMETER OutputCsv
  Optional path for CSV output.

.PARAMETER OutputJsonl
  Optional path for JSONL (one JSON object per line).

.PARAMETER ExportEvtx
  If set, also export raw EVTX files for each channel from each host for offline forensics.

.PARAMETER EvtxOutputFolder
  Local folder to place fetched EVTX files (default: .\evtx).

.PARAMETER ThrottleLimit
  Max concurrent remoting operations (default 6).

.EXAMPLES
  # Last 24h Security events 4625/4624 from two servers → CSV
  .\CollectEventLogs.ps1 -ComputerName DC01,App01 -Channels Security -EventId 4624,4625 -OutputCsv .\auth.csv -Verbose

  # Application/System last 7 days, any provider, JSONL + EVTX for offline
  .\CollectEventLogs.ps1 -ComputerName (gc .\hosts.txt) -Channels Application,System -StartTime (Get-Date).AddDays(-7) `
    -OutputJsonl .\logs.jsonl -ExportEvtx -EvtxOutputFolder .\evtx -Verbose

.REQUIREMENTS
  - WinRM enabled for remote collection OR run locally.
  - Rights to read event logs remotely.
  - For EVTX export: remote admin rights (uses wevtutil and admin share copy).

.NOTES (Environment adjustments & future GUI prompts)
  - Time range pickers; channel multi-select; IDs/providers multi-select.
  - Output format switches and folder pickers.
  - ThrottleLimit slider when querying many hosts.
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string[]]$Channels = @('System','Application'),

  [Parameter()]
  [int[]]$EventId,

  [Parameter()]
  [string[]]$Provider,

  [Parameter()]
  [datetime]$StartTime = (Get-Date).AddDays(-1),

  [Parameter()]
  [datetime]$EndTime = (Get-Date),

  [Parameter()]
  [int]$MaxEventsPerHost = 0,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputJsonl,

  [Parameter()]
  [switch]$ExportEvtx,

  [Parameter()]
  [string]$EvtxOutputFolder = ".\evtx",

  [Parameter()]
  [ValidateRange(1,64)]
  [int]$ThrottleLimit = 6
)

function New-FilterHash {
  param($Channel,$IDs,$Providers,$Start,$End)
  $fh = @{ LogName = $Channel; StartTime = $Start; EndTime = $End }
  if ($IDs) { $fh['Id'] = $IDs }
  if ($Providers) { $fh['ProviderName'] = $Providers }
  return $fh
}

function Export-RemoteEvtx {
  param([string]$Computer,[string]$Channel,[pscredential]$Cred,[string]$LocalFolder)
  # Creates a backup EVTX on remote using wevtutil and copy back over admin share.
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $remoteTemp = "C:\Windows\Temp\${($Channel -replace '[\\/:\*\?""\<\>\| ]','_')}_$stamp.evtx"
  $sharePath  = "\\$Computer\C$\Windows\Temp\$(Split-Path $remoteTemp -Leaf)"
  $localDir   = Join-Path $LocalFolder $Computer
  if (-not (Test-Path $localDir)) { New-Item -Path $localDir -ItemType Directory -Force | Out-Null }

  $sb = {
    param($ch,$file)
    wevtutil epl $ch $file /ow:true
    return (Test-Path $file)
  }

  try {
    if ($Cred) {
      Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock $sb -ArgumentList $Channel,$remoteTemp -ErrorAction Stop | Out-Null
    } else {
      Invoke-Command -ComputerName $Computer -ScriptBlock $sb -ArgumentList $Channel,$remoteTemp -ErrorAction Stop | Out-Null
    }
    Copy-Item -Path $sharePath -Destination (Join-Path $localDir (Split-Path $remoteTemp -Leaf)) -Force
  } catch {
    Write-Warning "EVTX export failed for $Computer:$Channel — $($_.Exception.Message)"
  }
}

begin {
  if (-not $OutputCsv -and -not $OutputJsonl -and -not $ExportEvtx) {
    Write-Verbose "No output path provided; defaulting to CSV: .\events.csv"
    $OutputCsv = ".\events.csv"
  }
  if ($ExportEvtx -and -not (Test-Path $EvtxOutputFolder)) {
    New-Item -Path $EvtxOutputFolder -ItemType Directory -Force | Out-Null
  }
  $allRows = New-Object System.Collections.Concurrent.ConcurrentBag[object]
}

process {
  $jobs = @()
  foreach ($cn in $ComputerName) {
    $jobs += [powershell]::Create().AddScript({
      param($cn,$cred,$channels,$ids,$providers,$start,$end,$limit)
      $rows = New-Object System.Collections.Generic.List[Object]
      foreach ($ch in $channels) {
        $filter = @{ LogName=$ch; StartTime=$start; EndTime=$end }
        if ($ids)       { $filter['Id'] = $ids }
        if ($providers) { $filter['ProviderName'] = $providers }

        try {
          $filterArgs = @{ FilterHashtable=$filter; ErrorAction='Stop'; MaxEvents=$null }
          if ($limit -gt 0) { $filterArgs['MaxEvents'] = $limit }
          if ($cred) {
            $ev = Get-WinEvent @filterArgs -ComputerName $cn -Credential $cred
          } else {
            $ev = Get-WinEvent @filterArgs -ComputerName $cn
          }
        } catch {
          $rows.Add([pscustomobject]@{
            ComputerName = $cn; Channel=$ch; RecordId=$null; TimeCreated=$null; Id=$null; Provider=$null;
            LevelDisplayName=$null; Message="Error: $($_.Exception.Message)"
          })
          continue
        }

        foreach ($e in $ev) {
          $rows.Add([pscustomobject]@{
            ComputerName      = $cn
            Channel           = $ch
            RecordId          = $e.RecordId
            TimeCreated       = $e.TimeCreated
            Id                = $e.Id
            Provider          = $e.ProviderName
            LevelDisplayName  = $e.LevelDisplayName
            TaskDisplayName   = $e.TaskDisplayName
            KeywordsDisplay   = ($e.KeywordsDisplayNames -join '; ')
            Message           = $e.FormatDescription()
          })
        }
      }
      return ,$rows
    }).AddArgument($cn).AddArgument($Credential).AddArgument($Channels).AddArgument($EventId).AddArgument($Provider).AddArgument($StartTime).AddArgument($EndTime).AddArgument($MaxEventsPerHost)
  }

  # Throttled parallelism
  $running = @()
  foreach ($ps in $jobs) {
    $ps.BeginInvoke() | Out-Null
    $running += $ps
    while ($running.Count -ge $ThrottleLimit) {
      Start-Sleep -Milliseconds 300
      $running = $running | Where-Object { -not $_.InvocationStateInfo.State.ToString().EndsWith('Completed') }
    }
  }

  # Wait for completion and collect
  foreach ($ps in $jobs) {
    while ($ps.InvocationStateInfo.State -notin 'Completed','Failed') { Start-Sleep -Milliseconds 200 }
    try {
      $out = $ps.EndInvoke($null)
      foreach ($row in $out) { $allRows.Add($row) }
    } catch {
      Write-Warning "Collection pipeline failed: $($_.Exception.Message)"
    } finally {
      $ps.Dispose()
    }
  }

  # EVTX export after logical collection completes
  if ($ExportEvtx) {
    foreach ($cn in $ComputerName) {
      foreach ($ch in $Channels) {
        Export-RemoteEvtx -Computer $cn -Channel $ch -Cred $Credential -LocalFolder $EvtxOutputFolder
      }
    }
  }
}

end {
  $final = $allRows.ToArray() | Sort-Object ComputerName, Channel, TimeCreated, RecordId

  if ($OutputCsv) {
    try { $final | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
  }
  if ($OutputJsonl) {
    try { $final | ForEach-Object { $_ | ConvertTo-Json -Depth 6 -Compress } | Out-File -FilePath $OutputJsonl -Encoding UTF8 } catch { Write-Warning "JSONL export failed: $($_.Exception.Message)" }
  }
  $final | Select-Object ComputerName,Channel,TimeCreated,Id,Provider,LevelDisplayName,Message | Format-Table -AutoSize
}