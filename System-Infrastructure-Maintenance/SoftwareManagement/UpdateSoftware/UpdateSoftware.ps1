<#
.SYNOPSIS
  Update an application to a target version using an installer or winget.

.DESCRIPTION
  - Checks current installed version via ProductCode or DisplayName.
  - If current version is less than TargetVersion, runs the provided installer.
  - Optional 'winget' mode for machines that have winget (workstations).
  - Safe outputs and CSV export for compliance tracking.

.PARAMETER ComputerName
  One or more computers.

.PARAMETER Credential
  Optional credential.

.PARAMETER TargetVersion
  Version that should be present after update.

.PARAMETER ProductCode
  MSI ProductCode for detection.

.PARAMETER DisplayNameContains
  Fallback detection string for DisplayName (Uninstall registry).

.PARAMETER InstallerPath
  Path to installer (MSI/EXE) to update the software.

.PARAMETER InstallerType
  MSI or EXE (inferred from extension if omitted).

.PARAMETER SilentArgs
  Silent switches for installer (required for EXE).

.PARAMETER UseWinget
  Attempt update via winget (if available): `winget upgrade --id <WingetId> --silent --accept-package-agreements --accept-source-agreements`

.PARAMETER WingetId
  Package Id for winget when -UseWinget is specified.

.PARAMETER OutputCsv
  Optional CSV path.

.EXAMPLES
  PS> .\UpdateSoftware.ps1 -ComputerName server01 -ProductCode '{111...}' -TargetVersion 10.6.0 `
       -InstallerPath \\fs\sw\AcmeClient_10.6.0.msi -SilentArgs "/qn /norestart" -Verbose

  PS> .\UpdateSoftware.ps1 -ComputerName desktop01 -UseWinget -WingetId "Acme.Client" -TargetVersion 10.6.0 -Verbose
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter(Mandatory)]
  [version]$TargetVersion,

  [Parameter()]
  [ValidatePattern('^\{[0-9A-Fa-f\-]{36}\}$')]
  [string]$ProductCode,

  [Parameter()]
  [string]$DisplayNameContains,

  [Parameter()]
  [ValidateScript({ Test-Path $_ })]
  [string]$InstallerPath,

  [Parameter()]
  [ValidateSet('MSI','EXE')]
  [string]$InstallerType,

  [Parameter()]
  [string]$SilentArgs,

  [Parameter()]
  [switch]$UseWinget,

  [Parameter()]
  [string]$WingetId,

  [Parameter()]
  [string]$OutputCsv
)

begin {
  function Get-Installed {
    param($Computer,$ProductCode,$DisplayNameContains)
    $paths = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $found = $null
    foreach ($p in $paths) {
      try {
        $items = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock {
          param($pp)
          Get-ItemProperty -Path $pp -ErrorAction SilentlyContinue |
            Select-Object DisplayName, DisplayVersion, PSChildName
        } -ArgumentList $p -ErrorAction Stop
        foreach ($it in $items) {
          if ($ProductCode -and $it.PSChildName -eq $ProductCode) { $found = $it; break }
          if ($DisplayNameContains -and $it.DisplayName -and $it.DisplayName -like "*$DisplayNameContains*") { $found = $it; break }
        }
        if ($found) { break }
      } catch { Write-Verbose "Detection failed on $Computer`: $($_.Exception.Message)" }
    }
    return $found
  }

  if ($UseWinget -and -not $WingetId) { throw "-WingetId is required when -UseWinget is set." }
  if (-not $UseWinget) {
    if (-not $InstallerType) {
      $ext = [System.IO.Path]::GetExtension($InstallerPath)
      $InstallerType = if ($ext -ieq '.msi') { 'MSI' } else { 'EXE' }
    }
    if ($InstallerType -eq 'MSI' -and -not $SilentArgs) { $SilentArgs = '/qn /norestart' }
    if ($InstallerType -eq 'EXE' -and -not $SilentArgs) { throw "EXE updates require -SilentArgs." }
  }
  $results = New-Object System.Collections.Generic.List[Object]
}

process {
  foreach ($cn in $ComputerName) {
    $status = [pscustomobject]@{
      ComputerName = $cn
      Action       = 'Update'
      Method       = if ($UseWinget) { 'winget' } else { 'installer' }
      CurrentVer   = $null
      TargetVer    = $TargetVersion.ToString()
      Result       = 'Skipped'
      Message      = $null
    }

    $det = Get-Installed -Computer $cn -ProductCode $ProductCode -DisplayNameContains $DisplayNameContains
    if (-not $det -or -not $det.DisplayVersion) {
      $status.Result = 'NotInstalled'
      $status.Message = 'Application not detected on system.'
      $results.Add($status); continue
    }
    $status.CurrentVer = $det.DisplayVersion
    if ([version]$det.DisplayVersion -ge $TargetVersion) {
      $status.Result = 'UpToDate'
      $status.Message = 'Current version meets/exceeds target.'
      $results.Add($status); continue
    }

    try {
      if ($UseWinget) {
        if ($PSCmdlet.ShouldProcess("$cn", "winget upgrade $WingetId")) {
          $cmd = "winget upgrade --id `"$WingetId`" --silent --accept-package-agreements --accept-source-agreements"
          $sb  = { param($c) cmd.exe /c $c }
          $res = Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $sb -ArgumentList $cmd -ErrorAction Stop
        }
      } else {
        # Staging and run installer like InstallSoftware.ps1
        $fileName = Split-Path $InstallerPath -Leaf
        $dest = "\\$cn\C$\Windows\Temp\$fileName"
        if ($PSCmdlet.ShouldProcess("$cn", "Copy $fileName")) {
          Copy-Item -Path $InstallerPath -Destination $dest -Force -ErrorAction Stop
        }
        $remoteFile = "C:\Windows\Temp\$fileName"
        $cmd = if ($InstallerType -eq 'MSI') { "msiexec.exe /i `"$remoteFile`" $SilentArgs" } else { "`"$remoteFile`" $SilentArgs" }
        if ($PSCmdlet.ShouldProcess("$cn", "Execute $fileName")) {
          $invoke = { param($commandLine)
            $proc = Get-WmiObject -Class Win32_Process -List
            $r = $proc.Create($commandLine); return $r
          }
          $r = Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $invoke -ArgumentList $cmd -ErrorAction Stop
          if ($r.ReturnValue -ne 0) { throw "Remote process creation failed with code $($r.ReturnValue)." }
        }
      }

      Start-Sleep -Seconds 10
      $post = Get-Installed -Computer $cn -ProductCode $ProductCode -DisplayNameContains $DisplayNameContains
      if ($post -and [version]$post.DisplayVersion -ge $TargetVersion) {
        $status.Result = 'Updated'
        $status.Message = "Now at $($post.DisplayVersion)."
      } else {
        $status.Result = 'Unknown'
        $status.Message = 'Post-update version not confirmed.'
      }
    } catch {
      $status.Result = 'Failed'
      $status.Message = $_.Exception.Message
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