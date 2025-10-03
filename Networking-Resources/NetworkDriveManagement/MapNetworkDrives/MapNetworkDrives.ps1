<#
.SYNOPSIS
  Map one or more network drives (UNC) to drive letters, safely and idempotently.

.DESCRIPTION
  - Accepts mappings via -CsvPath or -Mappings (array of objects).
  - Optionally validates UNC reachability before mapping.
  - Idempotent: if a drive already maps to the same UNC, it is skipped.
  - Can remove conflicting existing mappings before creating new ones.
  - Supports credentials (optional) and cmdkey storage (optional).
  - Uses New-PSDrive -Persist by default; can fallback to 'net use'.

.PARAMETER CsvPath
  CSV with columns: Letter, Path, Label (optional).
  Example:
    Letter,Path,Label
    H,\\fs01\homes\%USERNAME%,Home
    P,\\fs01\projects,Projects

.PARAMETER Mappings
  Array of objects/hashtables with fields: Letter, Path, Label (optional).
  Example:
    -Mappings @(
      @{ Letter='H'; Path='\\fs01\homes\'+$env:USERNAME; Label='Home' },
      @{ Letter='P'; Path='\\fs01\projects'; Label='Projects' }
    )

.PARAMETER Credential
  Optional PSCredential to map protected shares (or cross-domain).

.PARAMETER StoreCredWithCmdKey
  If set, stores credentials with 'cmdkey' for the target server (prompt-safe).

.PARAMETER RemoveExisting
  If a drive letter is already used but points elsewhere, remove it first.

.PARAMETER TestPathBeforeMap
  If set, validates UNC is reachable prior to mapping (fast fail).

.PARAMETER UseNetUse
  Use 'net use' instead of New-PSDrive (rarely needed; legacy environments).

.PARAMETER OutputCsv
  Optional path to export a results summary.

.EXAMPLES
  # CSV-driven mappings, validate paths, keep idempotent, and log results
  .\MapNetworkDrives.ps1 -CsvPath .\mappings.csv -TestPathBeforeMap -OutputCsv .\map_results.csv -Verbose

  # Two explicit mappings with credential & cmdkey storage
  $cred = Get-Credential
  .\MapNetworkDrives.ps1 -Mappings @(
      @{ Letter='H'; Path='\\fs01\homes\'+$env:USERNAME; Label='Home' },
      @{ Letter='P'; Path='\\fs01\projects'; Label='Projects' }
    ) -Credential $cred -StoreCredWithCmdKey -Verbose

.NOTES  (Environment adjustments & future GUI prompts)
  - UNC roots (\\server\share) should be configurable (GUI: server/share pickers).
  - Labels are cosmetic here (for your inventory/logs); Explorer labels on mapped drives
    typically follow the share name (changing label requires shell/registry tricks — out of scope).
  - If you require GPO-style reconnect at logon, keep -Persist (default) and/or deploy via GPO.
  - GUI should prompt for: mappings list (table editor), credentials (optional), path pre-check, and conflict policy.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(ParameterSetName='CSV', Mandatory=$true)]
  [ValidateScript({ Test-Path $_ })]
  [string]$CsvPath,

  [Parameter(ParameterSetName='Direct', Mandatory=$true)]
  [object[]]$Mappings,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [switch]$StoreCredWithCmdKey,

  [Parameter()]
  [switch]$RemoveExisting,

  [Parameter()]
  [switch]$TestPathBeforeMap,

  [Parameter()]
  [switch]$UseNetUse,

  [Parameter()]
  [string]$OutputCsv
)

begin {
  function Resolve-ServerFromUNC {
    param([string]$UNC)
    if ($UNC -notmatch '^(\\\\[^\\]+)\\') { return $null }
    return ($UNC -replace '^(\\\\[^\\]+)\\.*','$1').TrimStart('\')
  }

  function Get-CurrentMapping {
    param([string]$Letter)
    # Works on PS 5+: PSDrive shows current root if mapped
    $drive = Get-PSDrive -Name $Letter -ErrorAction SilentlyContinue
    if ($drive -and $drive.DisplayRoot) { return $drive.DisplayRoot }
    if ($drive -and $drive.Root -like '\\*') { return $drive.Root }
    # Fallback: net use (covers odd cases)
    $net = (net use "${Letter}:" 2>$null)
    if ($LASTEXITCODE -eq 0) {
      $line = ($net | Where-Object { $_ -match 'Remote name' }) -replace '.*Remote name\s+',''
      return $line.Trim()
    }
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

  # Normalize mapping list
  $mapList = switch ($PSCmdlet.ParameterSetName) {
    'CSV'    { Import-Csv -Path $CsvPath }
    'Direct' { $Mappings }
  }
  if (-not $mapList -or $mapList.Count -eq 0) { throw "No mappings provided." }

  $results = New-Object System.Collections.Generic.List[Object]
}

process {
  foreach ($m in $mapList) {
    $letter = ($m.Letter).ToString().TrimEnd(':').ToUpper()
    $path   = $m.Path
    $label  = $m.Label

    if ($letter -notmatch '^[A-Z]$') { Write-Warning "Invalid drive letter '$letter'"; continue }
    if ($path -notmatch '^\\\\[^\\]+\\') { Write-Warning "Invalid UNC '$path'"; continue }

    # Expand %USERNAME% etc. if present in CSV
    $path = [Environment]::ExpandEnvironmentVariables($path)

    # Optional reachability check
    if ($TestPathBeforeMap) {
      try {
        if (-not (Test-Path $path)) {
          Write-Warning "UNC not reachable: $path (skipping '${letter}:')"
          $results.Add([pscustomobject]@{ Letter=$letter; Path=$path; Action='Skip'; Result='Unreachable'; Message=$null })
          continue
        }
      } catch {
        Write-Warning "UNC check errored for $path`: $($_.Exception.Message)"
      }
    }

    # Idempotency check
    $current = Get-CurrentMapping -Letter $letter
    if ($current) {
      if ($current.TrimEnd('\') -ieq $path.TrimEnd('\')) {
        Write-Verbose "Drive ${letter}: already mapped to $path – skipping."
        $results.Add([pscustomobject]@{ Letter=$letter; Path=$path; Action='None'; Result='AlreadyMapped'; Message=$null })
        continue
      } elseif ($RemoveExisting) {
        if ($PSCmdlet.ShouldProcess("${letter}:", "Remove conflicting mapping ($current)")) {
          try {
            Remove-PSDrive -Name $letter -ErrorAction SilentlyContinue
            & net use "${letter}:" /delete /y | Out-Null
          } catch { Write-Warning "Failed to remove existing mapping on ${letter}: $($_.Exception.Message)" }
        }
      } else {
        $results.Add([pscustomobject]@{ Letter=$letter; Path=$path; Action='None'; Result='Conflict'; Message="Existing maps to $current" })
        continue
      }
    }

    # Optionally pre-store creds (avoids multiple prompts)
    if ($StoreCredWithCmdKey -and $Credential) {
      $server = Resolve-ServerFromUNC -UNC $path
      if ($server) { Add-CmdKeyCredential -Server $server -Cred $Credential }
    }

    # Create mapping
    try {
      if ($UseNetUse) {
        $netArgs = @($letter + ":", $path, "/persistent:yes")
        if ($Credential) {
          $netArgs += "/user:$($Credential.UserName)" , $Credential.GetNetworkCredential().Password
        }
        if ($PSCmdlet.ShouldProcess("${letter}:", "net use -> $path")) {
          & net use @netArgs | Out-Null
        }
      } else {
        $newParams = @{
          Name       = $letter
          PSProvider = 'FileSystem'
          Root       = $path
          Persist    = $true
          ErrorAction= 'Stop'
        }
        if ($Credential) { $newParams['Credential'] = $Credential }
        if ($PSCmdlet.ShouldProcess("${letter}:", "New-PSDrive -> $path")) {
          New-PSDrive @newParams | Out-Null
        }
      }
      $results.Add([pscustomobject]@{ Letter=$letter; Path=$path; Action='Map'; Result='Success'; Message=$label })
    } catch {
      $results.Add([pscustomobject]@{ Letter=$letter; Path=$path; Action='Map'; Result='Failed'; Message=$_.Exception.Message })
      Write-Warning "Failed to map ${letter}: to $path — $($_.Exception.Message)"
    }
  }
}

end {
  if ($OutputCsv) {
    try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
  }
  $results | Format-Table -AutoSize
}