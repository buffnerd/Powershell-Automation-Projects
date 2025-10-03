<#
.SYNOPSIS
  Silently install MSI/EXE software on one or more computers with detection and logging.

.DESCRIPTION
  - Copies installer to target(s) (default: \\<host>\C$\Windows\Temp).
  - Executes with silent switches (MSI: msiexec /i; EXE: your args).
  - Detection: MSI ProductCode OR display name/version via Uninstall registry.
  - Returns a per-host status object; optional CSV export.

.PARAMETER ComputerName
  One or more computers (default: local).

.PARAMETER Credential
  Optional credential for admin shares and remote process creation.

.PARAMETER InstallerPath
  Local or UNC path to the installer file (.msi or .exe).

.PARAMETER InstallerType
  'MSI' or 'EXE'. If omitted, inferred from extension.

.PARAMETER SilentArgs
  Silent switches. Default for MSI: "/qn /norestart". For EXE you MUST provide.

.PARAMETER ProductCode
  MSI ProductCode (GUID) for detection (preferred for MSI).

.PARAMETER DisplayNameContains
  Fallback detection: substring of DisplayName in Uninstall registry.

.PARAMETER MinimumVersion
  Optional: Only install if detected version is less than this (e.g. '10.2.0').

.PARAMETER RemoteStagingPath
  Remote folder where the installer is placed (default: C:\Windows\Temp).

.PARAMETER LogFolder
  Optional log directory on local machine to write per-host logs.

.PARAMETER OutputCsv
  Optional CSV path for results.

.EXAMPLES
  PS> .\InstallSoftware.ps1 -ComputerName server01,server02 `
       -InstallerPath \\filesrv\sw\AcmeClient.msi -ProductCode '{11111111-2222-3333-4444-555555555555}' `
       -SilentArgs "/qn /norestart" -Verbose

  PS> .\InstallSoftware.ps1 -ComputerName (gc .\hosts.txt) `
       -InstallerPath \\filesrv\sw\AcmeSetup.exe -InstallerType EXE -SilentArgs "/S /v/qn" `
       -DisplayNameContains "Acme Client" -MinimumVersion "10.5.0" -OutputCsv .\install_results.csv -Verbose

.REQUIREMENTS
  - Admin access to targets (ADMIN$ and remote service control).
  - WinRM not required; uses admin shares + remote service (psexec-like with WMI).
  - Targets must allow remote registry read for detection (usually enabled by default).

.NOTES (Environment adjustments & future GUI prompts)
  - File server paths (UNC) → GUI file picker.
  - Silent switches per vendor → GUI text box with presets library.
  - ProductCode vs DisplayName detection → GUI radio/select.
  - Version gating (`-MinimumVersion`) → GUI numeric/semantic input.
  - Staging path & log folder → GUI folder pickers.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter(Mandatory)]
  [ValidateScript({ Test-Path $_ })]
  [string]$InstallerPath,

  [Parameter()]
  [ValidateSet('MSI','EXE')]
  [string]$InstallerType,

  [Parameter()]
  [string]$SilentArgs,

  [Parameter()]
  [ValidatePattern('^\{[0-9A-Fa-f\-]{36}\}$')]
  [string]$ProductCode,

  [Parameter()]
  [string]$DisplayNameContains,

  [Parameter()]
  [version]$MinimumVersion,

  [Parameter()]
  [string]$RemoteStagingPath = 'C:\Windows\Temp',

  [Parameter()]
  [string]$LogFolder,

  [Parameter()]
  [string]$OutputCsv
)

function Get-InstalledApp {
  param(
    [string]$Computer,
    [string]$ProductCode,
    [string]$DisplayNameContains
  )
  # Detection via registry (do NOT use Win32_Product)
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  $result = $null
  try {
    foreach ($p in $paths) {
      $items = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock {
        param($pp)
        Get-ItemProperty -Path $pp -ErrorAction SilentlyContinue |
          Select-Object DisplayName, DisplayVersion, PSChildName
      } -ArgumentList $p -ErrorAction Stop

      foreach ($it in $items) {
        if ($ProductCode -and $it.PSChildName -eq $ProductCode) {
          $result = $it; break
        }
        if ($DisplayNameContains -and $it.DisplayName -and $it.DisplayName -like "*$DisplayNameContains*") {
          $result = $it; break
        }
      }
      if ($result) { break }
    }
  } catch {
    Write-Verbose "Detection failed on $Computer`: $($_.Exception.Message)"
  }
  return $result
}

begin {
  # Inference & defaults
  if (-not $InstallerType) {
    $ext = [System.IO.Path]::GetExtension($InstallerPath)
    $InstallerType = ($ext -ieq '.msi') ? 'MSI' : 'EXE'
  }
  if ($InstallerType -eq 'MSI' -and -not $SilentArgs) { $SilentArgs = '/qn /norestart' }
  if ($InstallerType -eq 'EXE' -and -not $SilentArgs) {
    throw "For EXE installers you must specify -SilentArgs (vendor-specific)."
  }
  if ($InstallerType -eq 'MSI' -and -not $ProductCode -and -not $DisplayNameContains) {
    Write-Warning "MSI detection works best with -ProductCode. Falling back to DisplayName if provided."
  }
  if (-not (Test-Path $InstallerPath)) { throw "Installer not found: $InstallerPath" }

  $results = New-Object System.Collections.Generic.List[Object]
  $fileName = Split-Path $InstallerPath -Leaf
}

process {
  foreach ($cn in $ComputerName) {
    $status = [pscustomobject]@{
      ComputerName = $cn
      Action       = 'Install'
      Installer    = $fileName
      Result       = 'Skipped'
      Message      = $null
      DetectedName = $null
      DetectedVer  = $null
    }

    try {
      # Pre-check: detection
      $det = Get-InstalledApp -Computer $cn -ProductCode $ProductCode -DisplayNameContains $DisplayNameContains
      if ($det) {
        $status.DetectedName = $det.DisplayName
        $status.DetectedVer  = $det.DisplayVersion
        if ($MinimumVersion) {
          if ([version]$det.DisplayVersion -ge $MinimumVersion) {
            $status.Result = 'UpToDate'
            $status.Message = "Installed ($($det.DisplayVersion)) >= Minimum ($MinimumVersion)."
            $results.Add($status); continue
          }
        } else {
          $status.Result = 'AlreadyInstalled'
          $status.Message = "Detected existing installation."
          $results.Add($status); continue
        }
      }

      # Copy installer
      $remoteFile = Join-Path $RemoteStagingPath $fileName
      $dest = "\\$cn\C$\Windows\Temp\$fileName"
      Write-Verbose "Copying installer to $dest"
      if ($PSCmdlet.ShouldProcess("$cn", "Copy $fileName to $RemoteStagingPath")) {
        Copy-Item -Path $InstallerPath -Destination $dest -Force -ErrorAction Stop
      }

      # Build command line
      if ($InstallerType -eq 'MSI') {
        $cmd = "msiexec.exe /i `"$remoteFile`" $SilentArgs"
      } else {
        $cmd = "`"$remoteFile`" $SilentArgs"
      }

      # Execute remotely (Win32_Process)
      if ($PSCmdlet.ShouldProcess("$cn", "Execute installer")) {
        $invoke = {
          param($commandLine)
          $si = New-Object Win32_ProcessStartup
          $si.ShowWindow = 0
          $proc = Get-WmiObject -Class Win32_Process -List
          $result = $proc.Create($commandLine)
          return $result
        }

        $res = if ($Credential) {
          Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $invoke -ArgumentList $cmd -ErrorAction Stop
        } else {
          Invoke-Command -ComputerName $cn -ScriptBlock $invoke -ArgumentList $cmd -ErrorAction Stop
        }

        if ($res.ReturnValue -ne 0) {
          throw "Remote process creation failed with code $($res.ReturnValue)."
        }
      }

      Start-Sleep -Seconds 10 # brief wait before post-detect
      $post = Get-InstalledApp -Computer $cn -ProductCode $ProductCode -DisplayNameContains $DisplayNameContains
      if ($post) {
        $status.Result = 'Installed'
        $status.DetectedName = $post.DisplayName
        $status.DetectedVer  = $post.DisplayVersion
        $status.Message = "Installation detected post-run."
      } else {
        $status.Result = 'Unknown'
        $status.Message = "Installer executed but detection did not confirm."
      }
    } catch {
      $status.Result = 'Failed'
      $status.Message = $_.Exception.Message
    }

    # Log file (optional)
    if ($LogFolder) {
      try {
        if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory | Out-Null }
        $logFile = Join-Path $LogFolder "Install_$($cn)_$($fileName).log"
        "[$(Get-Date -Format s)] $($status | ConvertTo-Json -Compress)" | Out-File -FilePath $logFile -Append -Encoding utf8
      } catch {
        Write-Warning "Failed to write log for $cn`: $($_.Exception.Message)"
      }
    }

    $results.Add($status)
  }
}

end {
  if ($OutputCsv) {
    try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
  }
  $results | Format-Table -AutoSize
}