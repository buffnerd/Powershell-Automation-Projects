<#
.SYNOPSIS
  Detect, repair, or remove offline/stale network printer connections.

.DESCRIPTION
  - Enumerates printers on target machines and identifies network connections.
  - Tests queue reachability and PrinterStatus.
  - Remediates by remove+reinstall (per-user) or /gd (per-machine) as needed.
  - Optionally removes stale printers that can't be restored.

.PARAMETER ComputerName
  One or more target computers.

.PARAMETER Credential
  Optional credential for remote Invoke-Command.

.PARAMETER Servers
  Optional allow-list of print servers to touch (e.g., 'print01','print02').

.PARAMETER RemoveStale
  Remove printers that remain unreachable after repair attempts.

.PARAMETER ReinstallIfBroken
  If set, attempts to remove and re-add a broken connection (per-user mode).

.PARAMETER PerMachine
  If set, treat connections as per-machine (`/gd` removal and `/ga` add); otherwise per-user remediation.

.PARAMETER Printers
  Optional filter to specific queues (array of '\\server\queue'). If omitted, all network printers on targets are evaluated.

.PARAMETER RetryCount
  Number of post-remediation reachability retries (default: 2).

.PARAMETER RetryDelaySeconds
  Delay between retries in seconds (default: 5).

.PARAMETER OutputCsv
  Optional CSV path for results.

.EXAMPLES
  # Identify & remove stale printers from print01 only
  .\CleanupOfflinePrinters.ps1 -ComputerName (gc .\hosts.txt) -Servers print01 -RemoveStale -Verbose

  # Attempt repair (remove+reinstall) for all broken queues
  .\CleanupOfflinePrinters.ps1 -ComputerName PC-007 -ReinstallIfBroken -Verbose

  # Per-machine cleanup on a VDI pool, then reinstall important queues, restarting Spooler
  .\CleanupOfflinePrinters.ps1 -ComputerName VDI-01,VDI-02 -PerMachine -ReinstallIfBroken -Verbose
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string[]]$Servers,

  [Parameter()]
  [switch]$RemoveStale,

  [Parameter()]
  [switch]$ReinstallIfBroken,

  [Parameter()]
  [switch]$PerMachine,

  [Parameter()]
  [string[]]$Printers,

  [Parameter()]
  [ValidateRange(0,10)][int]$RetryCount = 2,

  [Parameter()]
  [ValidateRange(1,60)][int]$RetryDelaySeconds = 5,

  [Parameter()]
  [string]$OutputCsv
)

# Helper: extract \\server from \\server\queue
function Get-ServerFromQueue {
  param([string]$Queue)
  if ($Queue -match '^\\\\([^\\]+)\\') { return $Matches[1] }
  return $null
}

# Helper: quick reachability
function Test-QueueReachable {
  param([string]$Queue)
  try { return [bool](Test-Path $Queue) } catch { return $false }
}

# List network printers on the target
$sbList = {
  param([string[]]$filterQueues)
  $all = Get-Printer -ErrorAction SilentlyContinue
  $rows = @()
  foreach ($p in $all) {
    # Identify network connection printers (have UNC-style Name or ShareName)
    $isConn = ($p.Name -like '\\*') -or ($p.ShareName -and $p.ShareName -like '\\*')
    if (-not $isConn) { continue }
    $q = if ($p.Name -like '\\*') { $p.Name } elseif ($p.ShareName -and $p.ShareName -like '\\*') { $p.ShareName } else { $p.Name }
    if ($filterQueues -and ($q -notin $filterQueues)) { continue }
    $rows += [pscustomobject]@{
      Name          = $p.Name
      Queue         = $q
      PrinterStatus = $p.PrinterStatus
      Default       = $p.Default
    }
  }
  return $rows
}

# Per-user reinstall
$sbReinstallUser = {
  param([string]$queue)
  try {
    if (Get-Printer -Name $queue -ErrorAction SilentlyContinue) {
      Remove-Printer -Name $queue -ErrorAction SilentlyContinue
    }
    Add-Printer -ConnectionName $queue -ErrorAction Stop
    return "Reinstalled"
  } catch { return "Error: $($_.Exception.Message)" }
}

# Per-machine remove/add using PrintUIEntry
$sbPerMachineAction = {
  param([string]$queue,[string]$op) # op: 'add'|'del'
  try {
    $flag = if ($op -eq 'add') { '/ga' } else { '/gd' }
    $printArgs = "$flag /n `"$queue`""
    Start-Process -FilePath "$env:WINDIR\System32\rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry $printArgs" -Wait -WindowStyle Hidden
    if ($op -eq 'add') { Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue }
    return "OK"
  } catch { return "Error: $($_.Exception.Message)" }
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($cn in $ComputerName) {
  try {
    $items = if ($Credential) {
      Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbList -ArgumentList ($Printers) -ErrorAction Stop
    } else {
      Invoke-Command -ComputerName $cn -ScriptBlock $sbList -ArgumentList ($Printers) -ErrorAction Stop
    }
  } catch {
    $results.Add([pscustomobject]@{ ComputerName=$cn; Queue=$null; Action='List'; Result='Error'; Message=$_.Exception.Message })
    continue
  }

  foreach ($it in $items) {
    $queue = $it.Queue
    $server = Get-ServerFromQueue -Queue $queue
    if ($Servers -and $server -and ($Servers -notcontains $server)) {
      $results.Add([pscustomobject]@{ ComputerName=$cn; Queue=$queue; Action='Skip'; Result='ServerFiltered'; Message=$server })
      continue
    }

    $ok = Test-QueueReachable -Queue $queue
    $isHealthy = $ok -and (($it.PrinterStatus -eq 'Normal') -or ($it.PrinterStatus -eq 0) -or (-not $it.PrinterStatus))

    if ($isHealthy) {
      $results.Add([pscustomobject]@{ ComputerName=$cn; Queue=$queue; Action='None'; Result='Healthy'; Message=$null })
      continue
    }

    # Attempt remediation
    if ($ReinstallIfBroken) {
      if ($PerMachine) {
        if ($PSCmdlet.ShouldProcess("$cn", "Per-machine reinstall $queue")) {
          $delRes = if ($Credential) {
            Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbPerMachineAction -ArgumentList $queue,'del' -ErrorAction SilentlyContinue
          } else {
            Invoke-Command -ComputerName $cn -ScriptBlock $sbPerMachineAction -ArgumentList $queue,'del' -ErrorAction SilentlyContinue
          }
          $addRes = if ($Credential) {
            Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbPerMachineAction -ArgumentList $queue,'add' -ErrorAction SilentlyContinue
          } else {
            Invoke-Command -ComputerName $cn -ScriptBlock $sbPerMachineAction -ArgumentList $queue,'add' -ErrorAction SilentlyContinue
          }
          # retry check
          $restored = $false
          for ($i=0; $i -le $RetryCount; $i++) {
            Start-Sleep -Seconds $RetryDelaySeconds
            if (Test-QueueReachable -Queue $queue) { $restored = $true; break }
          }
          $results.Add([pscustomobject]@{
            ComputerName=$cn; Queue=$queue; Action='PerMachineReinstall'; Result=if($restored){'Restored'}else{'Failed'}; Message="$delRes/$addRes"
          })
        }
      } else {
        if ($PSCmdlet.ShouldProcess("$cn", "Per-user reinstall $queue")) {
          $res = if ($Credential) {
            Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbReinstallUser -ArgumentList $queue -ErrorAction SilentlyContinue
          } else {
            Invoke-Command -ComputerName $cn -ScriptBlock $sbReinstallUser -ArgumentList $queue -ErrorAction SilentlyContinue
          }
          # retry
          $restored = $false
          for ($i=0; $i -le $RetryCount; $i++) {
            Start-Sleep -Seconds $RetryDelaySeconds
            if (Test-QueueReachable -Queue $queue) { $restored = $true; break }
          }
          $results.Add([pscustomobject]@{
            ComputerName=$cn; Queue=$queue; Action='PerUserReinstall'; Result=if($restored){'Restored'}else{'Failed'}; Message=$res
          })
        }
      }
    } else {
      # Optionally remove stale
      if ($RemoveStale) {
        if ($PerMachine) {
          if ($PSCmdlet.ShouldProcess("$cn", "Remove per-machine $queue")) {
            $delRes = if ($Credential) {
              Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbPerMachineAction -ArgumentList $queue,'del' -ErrorAction SilentlyContinue
            } else {
              Invoke-Command -ComputerName $cn -ScriptBlock $sbPerMachineAction -ArgumentList $queue,'del' -ErrorAction SilentlyContinue
            }
            $results.Add([pscustomobject]@{ ComputerName=$cn; Queue=$queue; Action='RemovePerMachine'; Result='Removed'; Message=$delRes })
          }
        } else {
          if ($PSCmdlet.ShouldProcess("$cn", "Remove per-user $queue")) {
            $res = if ($Credential) {
              Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock { param($q) Remove-Printer -Name $q -ErrorAction SilentlyContinue; "Removed" } -ArgumentList $queue
            } else {
              Invoke-Command -ComputerName $cn -ScriptBlock { param($q) Remove-Printer -Name $q -ErrorAction SilentlyContinue; "Removed" } -ArgumentList $queue
            }
            $results.Add([pscustomobject]@{ ComputerName=$cn; Queue=$queue; Action='RemovePerUser'; Result='Removed'; Message=$res })
          }
        }
      } else {
        $results.Add([pscustomobject]@{ ComputerName=$cn; Queue=$queue; Action='None'; Result='Broken'; Message='Use -ReinstallIfBroken or -RemoveStale' })
      }
    }
  }
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Sort-Object ComputerName, Queue | Format-Table -AutoSize