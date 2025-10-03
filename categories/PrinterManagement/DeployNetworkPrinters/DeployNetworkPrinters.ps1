<#
.SYNOPSIS
  Deploy shared network printers to target computers (per-machine or per-user), with idempotent checks.

.DESCRIPTION
  - Per-machine (all users): uses 'rundll32 printui.dll,PrintUIEntry /ga' so the connection appears for every user
    after a restart of the Print Spooler or a logon refresh.
  - Per-user: uses Add-Printer -ConnectionName for the current user context on the target.
  - Can set a default printer (per-user) when using the per-user mode.
  - Validates queue reachability and skips already-present connections.

.PARAMETER ComputerName
  One or more target computers (default: local computer).

.PARAMETER Credential
  Optional credential for remote Invoke-Command.

.PARAMETER Printers
  One or more shared printer paths (e.g., '\\print01\HR-1stFloor'). You can mix multiple queues.

.PARAMETER PerMachine
  If set, deploy per-machine (all users) using PrintUIEntry /ga. Otherwise deploy per-user via Add-Printer.

.PARAMETER SetDefault
  Optional queue name (e.g., '\\print01\HR-1stFloor') to set as the default printer (per-user mode only).

.PARAMETER ValidateReachability
  If set, quickly checks that the SMB path \\server\queue is reachable before attempting install.

.PARAMETER RestartSpooler
  If set with -PerMachine, restarts Spooler on the target so per-machine connections materialize immediately for new sessions.

.PARAMETER OutputCsv
  Optional CSV to write results.

.EXAMPLES
  # Per-machine deployment to many hosts (all users), and restart spooler to make it show up
  .\DeployNetworkPrinters.ps1 -ComputerName (gc .\hosts.txt) -Printers '\\print01\HR-1stFloor','\\print01\Ops-2ndFloor' `
    -PerMachine -RestartSpooler -ValidateReachability -Verbose

  # Per-user deployment to a single host and set default
  .\DeployNetworkPrinters.ps1 -ComputerName PC-007 -Printers '\\print01\HR-1stFloor' -SetDefault '\\print01\HR-1stFloor' -Verbose

.REQUIREMENTS
  - Targets must access the print server and share (firewall, DNS, permissions).
  - For per-machine (/ga) installation: local admin on targets, Print Spooler service available.
  - For per-user: script runs in the user context (or you accept setting default via user context).

.NOTES (Environment adjustments & future GUI prompts)
  - Printer list input (multi-select).
  - Mode toggle: Per-machine vs Per-user.
  - 'Set default' dropdown (per-user).
  - 'Validate reachability' and 'Restart spooler' checkboxes.
  - Credentials prompt for remote hosts.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter(Mandatory)]
  [string[]]$Printers,  # e.g. '\\print01\HR-1stFloor'

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [switch]$PerMachine,

  [Parameter()]
  [string]$SetDefault,

  [Parameter()]
  [switch]$ValidateReachability,

  [Parameter()]
  [switch]$RestartSpooler,

  [Parameter()]
  [string]$OutputCsv
)

# Quick UNC reachability check
function Test-PrinterUNC {
  param([string]$PrinterPath)
  try { return [bool](Test-Path $PrinterPath) } catch { return $false }
}

# Checks if a printer connection already exists on the target
$sbCheckUser = {
  param([string]$queue)
  try {
    $p = Get-Printer -Name $queue -ErrorAction SilentlyContinue
    return [bool]$p
  } catch { return $false }
}

# Add per-user printer via Add-Printer
$sbAddUser = {
  param([string]$queue,[string]$defaultQueue)
  try {
    if (-not (Get-Printer -Name $queue -ErrorAction SilentlyContinue)) {
      Add-Printer -ConnectionName $queue -ErrorAction Stop
    }
    if ($defaultQueue -and $queue -ieq $defaultQueue) {
      (Get-WmiObject -Class Win32_Printer -Filter ("Name='{0}'" -f $queue)).SetDefaultPrinter() | Out-Null
    }
    return "Installed"
  } catch {
    return "Error: $($_.Exception.Message)"
  }
}

# Add per-machine (all users) via PrintUIEntry /ga
$sbAddMachine = {
  param([string]$queue,[bool]$restart)
  try {
    $printArgs = "/ga /n `"$queue`""
    Start-Process -FilePath "$env:WINDIR\System32\rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry $printArgs" -Wait -WindowStyle Hidden
    if ($restart) {
      Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    }
    return "Installed (machine)"
  } catch {
    return "Error: $($_.Exception.Message)"
  }
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($cn in $ComputerName) {
  foreach ($q in $Printers) {
    $status = [pscustomobject]@{
      ComputerName = $cn
      Queue        = $q
      Mode         = (if ($PerMachine) { 'PerMachine' } else { 'PerUser' })
      Action       = 'None'
      Result       = 'Skipped'
      Message      = $null
    }

    # Optional quick reachability
    if ($ValidateReachability -and -not (Test-PrinterUNC -PrinterPath $q)) {
      $status.Result = 'Unreachable'
      $status.Message = 'Queue path not reachable'
      $results.Add($status); continue
    }

    try {
      if ($PerMachine) {
        if ($PSCmdlet.ShouldProcess("$cn", "Install per-machine $q")) {
          $res = if ($Credential) {
            Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbAddMachine -ArgumentList $q, $RestartSpooler.IsPresent -ErrorAction Stop
          } else {
            Invoke-Command -ComputerName $cn -ScriptBlock $sbAddMachine -ArgumentList $q, $RestartSpooler.IsPresent -ErrorAction Stop
          }
          $status.Action = 'Install'
          $status.Result = if ($res -is [string]) { $res } else { 'Installed (machine)' }
        }
      } else {
        # Per-user: idempotent check first
        $exists = if ($Credential) {
          Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbCheckUser -ArgumentList $q -ErrorAction Stop
        } else {
          Invoke-Command -ComputerName $cn -ScriptBlock $sbCheckUser -ArgumentList $q -ErrorAction Stop
        }

        if ($exists) {
          $status.Result = 'AlreadyPresent'
          $status.Action = 'None'
        } else {
          if ($PSCmdlet.ShouldProcess("$cn", "Install per-user $q")) {
            $res = if ($Credential) {
              Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sbAddUser -ArgumentList $q, $SetDefault -ErrorAction Stop
            } else {
              Invoke-Command -ComputerName $cn -ScriptBlock $sbAddUser -ArgumentList $q, $SetDefault -ErrorAction Stop
            }
            $status.Action = 'Install'
            $status.Result = if ($res -is [string]) { $res } else { 'Installed' }
          }
        }
      }
    } catch {
      $status.Result = 'Error'
      $status.Message = $_.Exception.Message
    }

    $results.Add($status)
  }
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Format-Table -AutoSize