<#
.SYNOPSIS
  Restart one or more remote Windows computers with pre-checks, grace period, notification, and verification.

.DESCRIPTION
  - Pre-checks: reachability (ping) and PowerShell remoting (WinRM).
  - Notification: optional message and countdown (grace period) to warn active users.
  - Restart method: prefers Restart-Computer via WinRM; can fall back to shutdown.exe /r /t on the target.
  - Verification: optionally wait for the machine to go offline and come back online (WMI/WinRM).
  - Logging: writes a concise result table; can also export CSV.

.PARAMETER ComputerName
  Target computer(s). Defaults to local computer name.

.PARAMETER Credential
  Optional PSCredential for remoting into non-trusted or workgroup hosts.

.PARAMETER Message
  Optional broadcast message to end users (used with shutdown.exe comment; also echoed in logs).

.PARAMETER GraceSeconds
  Time (seconds) to wait before restart, allowing users to save work. Default: 60.

.PARAMETER Force
  Force close running apps during restart.

.PARAMETER UseShutdownExe
  Use legacy shutdown.exe method instead of Restart-Computer (fallback for broken WinRM scenarios).

.PARAMETER WaitOnline
  After initiating restart, wait for machine to go down and come back online, then confirm WinRM.

.PARAMETER DownTimeoutSeconds
  Max seconds to wait for the host to go offline (default: 120).

.PARAMETER UpTimeoutSeconds
  Max seconds to wait for the host to come back online (default: 600).

.PARAMETER OutputCsv
  Optional CSV path to write results.

.EXAMPLES
  # Standard restart with a 2-minute grace and verification
  .\RestartRemoteComputers.ps1 -ComputerName app01,app02 -GraceSeconds 120 -WaitOnline -Verbose

  # Workgroup box using explicit creds and legacy method
  $cred = Get-Credential
  .\RestartRemoteComputers.ps1 -ComputerName LAB-PC01 -Credential $cred -UseShutdownExe -Message "Maintenance reboot in 1 minute" -Verbose

  # Force restart immediately and export results
  .\RestartRemoteComputers.ps1 -ComputerName (gc .\servers.txt) -GraceSeconds 5 -Force -WaitOnline -OutputCsv .\restart_results.csv

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Targets: -ComputerName (textbox/file/AD OU picker)
  - Credentials: -Credential for cross-domain/workgroup
  - UX knobs: message text, grace period, force toggle
  - Verification: Wait for offline/online with timeouts
  - Method selection: WinRM vs shutdown.exe fallback
  - Export path: -OutputCsv
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string]$Message,

  [Parameter()]
  [ValidateRange(0, 3600)]
  [int]$GraceSeconds = 60,

  [Parameter()]
  [switch]$Force,

  [Parameter()]
  [switch]$UseShutdownExe,

  [Parameter()]
  [switch]$WaitOnline,

  [Parameter()]
  [ValidateRange(10, 900)]
  [int]$DownTimeoutSeconds = 120,

  [Parameter()]
  [ValidateRange(60, 3600)]
  [int]$UpTimeoutSeconds = 600,

  [Parameter()]
  [string]$OutputCsv
)

function Test-ICMP {
  param([string]$HostName)
  try {
    Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction Stop
  } catch { $false }
}

function Test-WinRM {
  param([string]$Computer,[pscredential]$Cred)
  try {
    if ($Cred) { Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock { 1 } -ErrorAction Stop | Out-Null }
    else       { Invoke-Command -ComputerName $Computer               -ScriptBlock { 1 } -ErrorAction Stop | Out-Null }
    $true
  } catch { $false }
}

# Send the restart on the target (two paths)
$sbRestartComputer = {
  param([int]$Grace,[string]$Note,[bool]$Hard)
  try {
    # A courtesy note for event logs
    if ($Note) { Write-EventLog -LogName Application -Source "PowerShell" -EntryType Information -EventId 1000 -Message "Scheduled restart: $Note" -ErrorAction SilentlyContinue }
  } catch {}

  if ($Hard) {
    Restart-Computer -Force -ErrorAction SilentlyContinue
  } else {
    # Give users a moment (if >0)
    if ($Grace -gt 0) { Start-Sleep -Seconds $Grace }
    Restart-Computer -ErrorAction SilentlyContinue
  }
}

$sbShutdownExe = {
  param([int]$Grace,[string]$Note,[bool]$Hard)
  try {
    $arguments = "/r /t $Grace /d p:0:0"
    if ($Hard) { $arguments += " /f" }
    if ($Note) { $arguments += " /c `"$Note`"" }
    Start-Process -FilePath "$env:WINDIR\System32\shutdown.exe" -ArgumentList $arguments -WindowStyle Hidden
    "Sent"
  } catch { "Error: $($_.Exception.Message)" }
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($cn in $ComputerName) {
  $status = [pscustomobject]@{
    ComputerName = $cn
    ICMP         = $false
    WinRM        = $false
    Method       = if ($UseShutdownExe) { 'shutdown.exe' } else { 'Restart-Computer' }
    Initiated    = $false
    DownOK       = $null
    UpOK         = $null
    Message      = $Message
    Notes        = $null
  }

  # Pre-checks
  $status.ICMP  = Test-ICMP -HostName $cn
  $status.WinRM = Test-WinRM -Computer $cn -Cred $Credential

  if (-not $status.ICMP -and -not $status.WinRM) {
    $status.Notes = "Host unreachable (no ICMP/WinRM)."
    $results.Add($status); continue
  }

  if ($PSCmdlet.ShouldProcess($cn, "Restart")) {
    try {
      if (-not $UseShutdownExe -and $status.WinRM) {
        if ($Credential) {
          Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbRestartComputer -ArgumentList $GraceSeconds,$Message,$Force.IsPresent -ErrorAction Stop | Out-Null
        } else {
          Invoke-Command -ComputerName $cn               -ScriptBlock $sbRestartComputer -ArgumentList $GraceSeconds,$Message,$Force.IsPresent -ErrorAction Stop | Out-Null
        }
        $status.Initiated = $true
      } else {
        # Fall back to shutdown.exe (requires admin share/WinRM to invoke remotely; we'll try via Invoke-Command first, else psexec-like remoting is out of scope)
        if ($Credential) {
          Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbShutdownExe -ArgumentList $GraceSeconds,$Message,$Force.IsPresent -ErrorAction Stop | Out-Null
        } else {
          Invoke-Command -ComputerName $cn               -ScriptBlock $sbShutdownExe -ArgumentList $GraceSeconds,$Message,$Force.IsPresent -ErrorAction Stop | Out-Null
        }
        $status.Method    = 'shutdown.exe'
        $status.Initiated = $true
      }
    } catch {
      $status.Notes = "Failed to send restart: $($_.Exception.Message)"
      $results.Add($status); continue
    }
  } else {
    $results.Add($status); continue
  }

  # Verification phase (optional)
  if ($WaitOnline -and $status.Initiated) {
    # Wait for offline
    $downStart = Get-Date
    do {
      Start-Sleep -Seconds 3
      $ping = Test-ICMP -HostName $cn
      if (-not $ping) { $status.DownOK = $true; break }
    } while ((Get-Date) -lt $downStart.AddSeconds($DownTimeoutSeconds))
    if (-not $status.DownOK) { $status.DownOK = $false }

    # Wait for online
    $upStart = Get-Date
    do {
      Start-Sleep -Seconds 5
      $ping = Test-ICMP -HostName $cn
      $wrm  = $ping -and (Test-WinRM -Computer $cn -Cred $Credential)
      if ($wrm) { $status.UpOK = $true; break }
    } while ((Get-Date) -lt $upStart.AddSeconds($UpTimeoutSeconds))
    if (-not $status.UpOK) { $status.UpOK = $false }
  }

  $results.Add($status)
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Format-Table -AutoSize