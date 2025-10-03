<#
.SYNOPSIS
  Detect and repair broken/disconnected mapped network drives.

.DESCRIPTION
  - Detects mapped drives via Get-PSDrive and (if present) Get-SmbMapping / 'net use'.
  - For mappings that are disconnected or whose UNC is unreachable:
      * Optionally add credentials via 'cmdkey' (server-scoped)
      * Remove and recreate the mapping
      * Validate reachability after remediation
  - Can remove stale mappings when the share no longer exists (opt-in).
  - Supports allow-listing servers to touch (safety).

.PARAMETER Servers
  Optional allow-list of servers (e.g., @('fs01','nas01')). Only mappings pointing to these are remediated.

.PARAMETER Credential
  Optional credential to re-authenticate protected shares.

.PARAMETER StoreCredWithCmdKey
  If set, store credential with cmdkey for the server prior to remap.

.PARAMETER RemoveStale
  Remove mappings whose UNC is not reachable and cannot be repaired.

.PARAMETER RetryCount
  Number of retry attempts after remediation (default: 2).

.PARAMETER RetryDelaySeconds
  Seconds to wait between retries (default: 5).

.PARAMETER OutputCsv
  Optional results CSV.

.EXAMPLES
  # Simple repair on current machine
  .\FixBrokenMappings.ps1 -Verbose

  # Re-auth with credential and store cmdkey; only touch fs01/nas01
  $cred = Get-Credential
  .\FixBrokenMappings.ps1 -Servers fs01,nas01 -Credential $cred -StoreCredWithCmdKey -Verbose -OutputCsv .\fix_results.csv

  # Remove truly stale mappings that can't be restored
  .\FixBrokenMappings.ps1 -RemoveStale -Verbose

.NOTES (Environment adjustments & future GUI prompts)
  - Server allow-list (GUI: multi-select)
  - Creds optional (GUI: credential picker)
  - RemoveStale toggle (GUI: checkbox with scary confirmation)
  - Retry knobs (GUI: numeric inputs)
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string[]]$Servers,
  [pscredential]$Credential,
  [switch]$StoreCredWithCmdKey,
  [switch]$RemoveStale,
  [ValidateRange(0,10)][int]$RetryCount = 2,
  [ValidateRange(1,60)][int]$RetryDelaySeconds = 5,
  [string]$OutputCsv
)

function Get-NetworkMappings {
  # Returns objects: Letter, Path, Status ('OK'|'Disconnected'|'Unknown')
  $items = New-Object System.Collections.Generic.List[Object]

  # PSDrive view
  foreach ($d in Get-PSDrive -PSProvider FileSystem) {
    if ($d.Root -like '\\*') {
      $status = Test-Path $d.Root
      $items.Add([pscustomobject]@{
        Letter = $d.Name.ToUpper()
        Path   = $d.Root
        Status = if ($status) { 'OK' } else { 'Disconnected' }
      })
    }
  }

  # If available, merge with Get-SmbMapping (better status)
  if (Get-Command Get-SmbMapping -ErrorAction SilentlyContinue) {
    try {
      $smb = Get-SmbMapping | Where-Object { $_.LocalPath -like '*:' }
      foreach ($m in $smb) {
        $letter = ($m.LocalPath.TrimEnd(':')).ToUpper()
        $existing = $items | Where-Object { $_.Letter -eq $letter }
        $st = if ($m.Status -eq 'Ok') { 'OK' } else { 'Disconnected' }
        if ($existing) {
          $existing.Status = $st
          $existing.Path   = $m.RemotePath
        } else {
          $items.Add([pscustomobject]@{
            Letter = $letter
            Path   = $m.RemotePath
            Status = $st
          })
        }
      }
    } catch { Write-Verbose "Get-SmbMapping failed: $($_.Exception.Message)" }
  }

  # Fallback: 'net use'
  try {
    $nu = net use
    foreach ($line in $nu) {
      if ($line -match '^[A-Z]:') {
        $parts = $line -split '\s+'
        $letter = ($parts[0]).TrimEnd(':').ToUpper()
        $unc    = $parts | Where-Object { $_ -like '\\*' } | Select-Object -First 1
        $state  = if ($parts -contains 'OK') { 'OK' } else { 'Disconnected' }
        if ($letter -and $unc) {
          $existing = $items | Where-Object { $_.Letter -eq $letter }
          if ($existing) { $existing.Path = $unc; $existing.Status = $state }
          else {
            $items.Add([pscustomobject]@{ Letter=$letter; Path=$unc; Status=$state })
          }
        }
      }
    }
  } catch { Write-Verbose "Parsing 'net use' failed: $($_.Exception.Message)" }

  $items | Sort-Object Letter -Unique
}

function Get-ServerFromUNC {
  param([string]$UNC)
  if ($UNC -match '^\\\\([^\\]+)\\') { return $Matches[1] }
  return $null
}

function Add-CmdKeyCredential {
  param([string]$Server,[pscredential]$Cred)
  if (-not $Server -or -not $Cred) { return }
  $user = $Cred.UserName
  $pass = $Cred.GetNetworkCredential().Password
  $target = "*//$Server"
  & cmdkey.exe /add:$target /user:$user /pass:$pass | Out-Null
}

function Test-UNCReachable {
  param([string]$UNC)
  try { return [bool](Test-Path $UNC) } catch { return $false }
}

$map = Get-NetworkMappings
$results = New-Object System.Collections.Generic.List[Object]

foreach ($m in $map) {
  $server = Get-ServerFromUNC -UNC $m.Path
  if ($Servers -and $server -and ($Servers -notcontains $server)) {
    Write-Verbose "Skipping $($m.Letter): ($($m.Path)) – server not in allow-list."
    continue
  }

  $ok = Test-UNCReachable -UNC $m.Path
  if ($ok -and $m.Status -eq 'OK') {
    $results.Add([pscustomobject]@{ Letter=$m.Letter; Path=$m.Path; Action='None'; Result='Healthy'; Message=$null })
    continue
  }

  # Attempt remediation
  if ($Credential -and $StoreCredWithCmdKey -and $server) {
    Add-CmdKeyCredential -Server $server -Cred $Credential
  }

  if ($PSCmdlet.ShouldProcess("$($m.Letter):", "Repair mapping to $($m.Path)")) {
    try {
      # Remove first
      try {
        Remove-PSDrive -Name $m.Letter -ErrorAction SilentlyContinue
        & net use "$($m.Letter):" /delete /y | Out-Null
      } catch {}

      # Recreate
      $args = @{
        Name       = $m.Letter
        PSProvider = 'FileSystem'
        Root       = $m.Path
        Persist    = $true
        ErrorAction= 'Stop'
      }
      if ($Credential) { $args['Credential'] = $Credential }
      New-PSDrive @args | Out-Null

      # Retry reachability checks
      $repaired = $false
      for ($i=0; $i -le $RetryCount; $i++) {
        Start-Sleep -Seconds $RetryDelaySeconds
        if (Test-UNCReachable -UNC $m.Path) { $repaired = $true; break }
      }

      if ($repaired) {
        $results.Add([pscustomobject]@{ Letter=$m.Letter; Path=$m.Path; Action='Repair'; Result='Success'; Message=$null })
      } else {
        if ($RemoveStale) {
          if ($PSCmdlet.ShouldProcess("$($m.Letter):", "Remove stale mapping (unreachable)")) {
            try {
              Remove-PSDrive -Name $m.Letter -ErrorAction SilentlyContinue
              & net use "$($m.Letter):" /delete /y | Out-Null
            } catch {}
            $results.Add([pscustomobject]@{ Letter=$m.Letter; Path=$m.Path; Action='Remove'; Result='StaleRemoved'; Message='Unreachable after retries' })
          }
        } else {
          $results.Add([pscustomobject]@{ Letter=$m.Letter; Path=$m.Path; Action='Repair'; Result='Failed'; Message='Still unreachable after retries' })
        }
      }
    } catch {
      $results.Add([pscustomobject]@{ Letter=$m.Letter; Path=$m.Path; Action='Repair'; Result='Error'; Message=$_.Exception.Message })
      Write-Warning "Repair failed on $($m.Letter): $($_.Exception.Message)"
    }
  }
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Sort-Object Letter | Format-Table -AutoSize