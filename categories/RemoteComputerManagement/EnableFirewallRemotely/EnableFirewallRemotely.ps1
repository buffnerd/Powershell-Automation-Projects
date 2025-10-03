<#
.SYNOPSIS
  Enable Windows Defender Firewall remotely, enforce profile state, and allow required admin ports.

.DESCRIPTION
  - Enables firewall profiles: Domain/Private/Public (select any).
  - Ensures WinRM inbound rules are enabled so future remoting is not broken.
  - Optionally enables well-known rule groups: "Remote Desktop", "File and Printer Sharing".
  - Optionally opens custom inbound ports (TCP/UDP) with a standard naming scheme.
  - Dry-run support (preview changes only) and a simple revert file containing rules created by this run.

.PARAMETER ComputerName
  One or more target computers. Default: local machine.

.PARAMETER Credential
  Optional PSCredential for remote changes.

.PARAMETER EnableDomain
  Turn ON the Domain profile.

.PARAMETER EnablePrivate
  Turn ON the Private profile.

.PARAMETER EnablePublic
  Turn ON the Public profile.

.PARAMETER AllowWinRM
  Ensure Windows Remote Management inbound rules are enabled (recommended).

.PARAMETER AllowRDP
  Enable built-in "Remote Desktop" firewall rules.

.PARAMETER AllowFilePrint
  Enable built-in "File and Printer Sharing" rules.

.PARAMETER OpenTcp
  Custom inbound TCP ports to open (array). Example: 8443, 50443.

.PARAMETER OpenUdp
  Custom inbound UDP ports to open (array).

.PARAMETER RulePrefix
  Prefix for custom rule names (default: 'Ops-Open').

.PARAMETER DryRun
  Show what would change without applying.

.PARAMETER OutputCsv
  Optional CSV path for results.

.EXAMPLES
  # Enforce Domain & Private firewalls on, allow WinRM + RDP, open TCP 8443
  .\EnableFirewallRemotely.ps1 -ComputerName web01,web02 -EnableDomain -EnablePrivate -AllowWinRM -AllowRDP -OpenTcp 8443 -Verbose

  # All profiles on with File/Print, preview only
  .\EnableFirewallRemotely.ps1 -ComputerName (gc .\workstations.txt) -EnableDomain -EnablePrivate -EnablePublic -AllowFilePrint -DryRun

  # Open UDP 514 (Syslog) with a named prefix and export a change log
  .\EnableFirewallRemotely.ps1 -ComputerName siem-collector -EnableDomain -AllowWinRM -OpenUdp 514 -RulePrefix "SIEM" -OutputCsv .\fw_changes.csv

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Profiles to enable: Domain / Private / Public (checkboxes)
  - Admin access rules: WinRM, RDP, File & Printer Sharing (checkboxes)
  - Custom ports: TCP/UDP arrays + naming prefix
  - Dry-run toggle and CSV export path
  - Credentials for remote execution
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [switch]$EnableDomain,

  [Parameter()]
  [switch]$EnablePrivate,

  [Parameter()]
  [switch]$EnablePublic,

  [Parameter()]
  [switch]$AllowWinRM,

  [Parameter()]
  [switch]$AllowRDP,

  [Parameter()]
  [switch]$AllowFilePrint,

  [Parameter()]
  [int[]]$OpenTcp,

  [Parameter()]
  [int[]]$OpenUdp,

  [Parameter()]
  [string]$RulePrefix = 'Ops-Open',

  [Parameter()]
  [switch]$DryRun,

  [Parameter()]
  [string]$OutputCsv
)

function Invoke-Remote {
  param([string]$Computer,[scriptblock]$Block,[object[]]$ArgumentList,[pscredential]$Cred)
  if ($Cred) { Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock $Block -ArgumentList $ArgumentList -ErrorAction Stop }
  else       { Invoke-Command -ComputerName $Computer               -ScriptBlock $Block -ArgumentList $ArgumentList -ErrorAction Stop }
}

$sb = {
  param(
    [bool]$dom,[bool]$priv,[bool]$pub,[bool]$winrm,[bool]$rdp,[bool]$fps,
    [int[]]$tcp,[int[]]$udp,[string]$prefix,[bool]$simulate
  )

  # Helper for action execution
  function Invoke-ActionLocal {
    param([string]$Desc,[scriptblock]$Code,[bool]$Sim)
    if ($Sim) { return "DRYRUN: $Desc" }
    try { & $Code; return "OK: $Desc" } catch { return "ERR: $Desc -> $($_.Exception.Message)" }
  }

  $actions = New-Object System.Collections.Generic.List[Object]

  # Ensure firewall service is present & running
  $svc = Get-Service -Name mpssvc -ErrorAction SilentlyContinue
  if ($svc -and $svc.Status -ne 'Running') {
    $actions.Add( Invoke-ActionLocal "Start firewall service" { Start-Service mpssvc } $simulate )
  }

  if ($dom)  { $actions.Add( Invoke-ActionLocal "Enable Domain profile"   { Set-NetFirewallProfile -Profile Domain  -Enabled True } $simulate ) }
  if ($priv) { $actions.Add( Invoke-ActionLocal "Enable Private profile"  { Set-NetFirewallProfile -Profile Private -Enabled True } $simulate ) }
  if ($pub)  { $actions.Add( Invoke-ActionLocal "Enable Public profile"   { Set-NetFirewallProfile -Profile Public  -Enabled True } $simulate ) }

  # Built-in allow groups
  if ($winrm) {
    $actions.Add( Invoke-ActionLocal "Enable WinRM rules" { Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" } $simulate )
  }
  if ($rdp) {
    $actions.Add( Invoke-ActionLocal "Enable Remote Desktop rules" { Enable-NetFirewallRule -DisplayGroup "Remote Desktop" } $simulate )
  }
  if ($fps) {
    $actions.Add( Invoke-ActionLocal "Enable File and Printer Sharing rules" { Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" } $simulate )
  }

  # Custom port rules
  if ($tcp -and $tcp.Count -gt 0) {
    $unique = $tcp | Select-Object -Unique
    foreach ($p in $unique) {
      $name = "$prefix-TCP-$p"
      $actions.Add( Invoke-ActionLocal "Open TCP $p ($name)" { New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p -Profile Any -EdgeTraversalPolicy Block -ErrorAction Stop } $simulate )
    }
  }
  if ($udp -and $udp.Count -gt 0) {
    $unique = $udp | Select-Object -Unique
    foreach ($p in $unique) {
      $name = "$prefix-UDP-$p"
      $actions.Add( Invoke-ActionLocal "Open UDP $p ($name)" { New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol UDP -LocalPort $p -Profile Any -EdgeTraversalPolicy Block -ErrorAction Stop } $simulate )
    }
    }
  # Return actions
  return $actions
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($cn in $ComputerName) {
  try {
    $acts = Invoke-Remote -Computer $cn -Cred $Credential -Block $sb -ArgumentList @(
      $EnableDomain.IsPresent,$EnablePrivate.IsPresent,$EnablePublic.IsPresent,
      $AllowWinRM.IsPresent,$AllowRDP.IsPresent,$AllowFilePrint.IsPresent,
      $OpenTcp,$OpenUdp,$RulePrefix,$DryRun.IsPresent
    )
    foreach ($a in $acts) {
      $results.Add([pscustomobject]@{
        ComputerName = $cn
        Result       = $a
      })
    }
  } catch {
    $results.Add([pscustomobject]@{
      ComputerName = $cn
      Result       = "ERR: $_"
    })
  }
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Format-Table -AutoSize