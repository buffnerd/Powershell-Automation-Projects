<#
.SYNOPSIS
  Safely stop/start (or restart) Windows services across one or more computers with retries and validation.

.DESCRIPTION
  - Stop/Start/Restart actions with configurable timeouts.
  - Optionally restart required dependencies first (or after) based on direction.
  - Validates service reaches Running (or Stopped) state.
  - Retries on failure; logs structured results and optional CSV.

.PARAMETER ComputerName
  One or more computers.

.PARAMETER Services
  One or more ServiceName values (e.g., 'W3SVC','Spooler').

.PARAMETER Credential
  Optional PSCredential for remote actions.

.PARAMETER Action
  'Restart' (default), 'Stop', or 'Start'.

.PARAMETER TimeoutSeconds
  How long to wait for desired state per service (default: 60).

.PARAMETER RetryCount
  Number of times to retry if the operation fails (default: 1).

.PARAMETER RestartDependencies
  If set and Action is Restart/Start, attempts to ensure required dependencies are Running.

.PARAMETER ValidateAfter
  If set, verify service reached desired state (Running for Start/Restart, Stopped for Stop) and record result.

.PARAMETER OutputCsv
  Optional CSV path to store results.

.EXAMPLES
  # Restart IIS and Schedule on two servers with validation
  .\RestartServices.ps1 -ComputerName web01,web02 -Services 'W3SVC','Schedule' -ValidateAfter -Verbose

  # Stop Spooler fleet-wide, with retries and timeout
  .\RestartServices.ps1 -ComputerName (gc .\print-servers.txt) -Services 'Spooler' -Action Stop -RetryCount 2 -TimeoutSeconds 120 -Verbose

  # Start a dependency-aware set
  .\RestartServices.ps1 -ComputerName app01 -Services 'W3SVC' -RestartDependencies -ValidateAfter
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter(Mandatory)]
  [string[]]$Services,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [ValidateSet('Restart','Stop','Start')]
  [string]$Action = 'Restart',

  [Parameter()]
  [ValidateRange(10, 600)]
  [int]$TimeoutSeconds = 60,

  [Parameter()]
  [ValidateRange(0, 5)]
  [int]$RetryCount = 1,

  [Parameter()]
  [switch]$RestartDependencies,

  [Parameter()]
  [switch]$ValidateAfter,

  [Parameter()]
  [string]$OutputCsv
)

function Invoke-Remote {
  param([string]$Computer,[scriptblock]$Script,[object[]]$Arguments,[pscredential]$Cred)
  if ($Cred) { return Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock $Script -ArgumentList $Arguments -ErrorAction Stop }
  else       { return Invoke-Command -ComputerName $Computer -ScriptBlock $Script -ArgumentList $Arguments -ErrorAction Stop }
}

# Scriptblocks executed on target
$sbOperate = {
  param($svc,$op,$timeout,$deps,$validate)
  try {
    $target = Get-Service -Name $svc -ErrorAction Stop

    # Handle dependencies for Start/Restart
    if ($deps -and ($op -eq 'Start' -or $op -eq 'Restart') -and $target.ServicesDependedOn) {
      foreach ($d in $target.ServicesDependedOn) {
        try {
          $ds = Get-Service -Name $d.Name -ErrorAction Stop
          if ($ds.Status -ne 'Running') {
            Start-Service -Name $d.Name -ErrorAction SilentlyContinue
            $ds.WaitForStatus('Running','00:00:'+$timeout) | Out-Null
          }
        } catch { }
      }
    }

    switch ($op) {
      'Stop'    { if ($target.Status -ne 'Stopped')  { Stop-Service  -Name $svc -Force -ErrorAction SilentlyContinue } }
      'Start'   { if ($target.Status -ne 'Running')  { Start-Service -Name $svc -ErrorAction SilentlyContinue } }
      'Restart' { Restart-Service -Name $svc -Force -ErrorAction SilentlyContinue }
    }

    # Wait for final state
    if ($validate) {
      $desired = if ($op -eq 'Stop') { 'Stopped' } else { 'Running' }
      try { (Get-Service -Name $svc).WaitForStatus($desired,'00:00:'+$timeout) | Out-Null } catch { }
      $final = (Get-Service -Name $svc).Status
      return [pscustomobject]@{ Service=$svc; Operation=$op; FinalStatus=$final; Desired=$desired }
    } else {
      return [pscustomobject]@{ Service=$svc; Operation=$op; FinalStatus=(Get-Service -Name $svc).Status; Desired=$null }
    }
  } catch {
    return [pscustomobject]@{ Service=$svc; Operation=$op; FinalStatus='Error'; Desired=$null; Message=$_.Exception.Message }
  }
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($cn in $ComputerName) {
  foreach ($svc in $Services) {
    $attempt = 0
    $done = $false
    while (-not $done -and $attempt -le $RetryCount) {
      $attempt++

      if ($PSCmdlet.ShouldProcess("$cn", "$Action $svc (attempt $attempt)")) {
        try {
          $res = Invoke-Remote -Computer $cn -Cred $Credential -Script $sbOperate -Arguments @($svc,$Action,$TimeoutSeconds,$RestartDependencies.IsPresent,$ValidateAfter.IsPresent)
          $ok = $true
          if ($ValidateAfter) {
            $ok = ($res.FinalStatus -eq $res.Desired)
          } else {
            # if not validating, consider anything not 'Error' as OK
            $ok = ($res.FinalStatus -ne 'Error')
          }

          $results.Add([pscustomobject]@{
            ComputerName = $cn
            ServiceName  = $svc
            Action       = $Action
            Attempt      = $attempt
            Desired      = $res.Desired
            FinalStatus  = $res.FinalStatus
            Success      = $ok
            Message      = $res.Message
            Timestamp    = (Get-Date)
          })

          if ($ok) { $done = $true } else { Start-Sleep -Seconds 3 }
        } catch {
          $results.Add([pscustomobject]@{
            ComputerName = $cn
            ServiceName  = $svc
            Action       = $Action
            Attempt      = $attempt
            Desired      = $null
            FinalStatus  = 'Error'
            Success      = $false
            Message      = $_.Exception.Message
            Timestamp    = (Get-Date)
          })
          Start-Sleep -Seconds 3
        }
      } else {
        $done = $true
      }
    }
  }
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Sort-Object ComputerName, ServiceName, Attempt | Format-Table -AutoSize