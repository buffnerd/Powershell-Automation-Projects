<#
.SYNOPSIS
  Export applied GPOs (RSoP) for one or more computers/users to HTML/XML.

.DESCRIPTION
  Runs gpresult *on the target machine(s)* to ensure accurate scoping and permissions,
  saves reports to a temp directory on the target, and optionally copies them back.

.PARAMETER ComputerName
  Target computer(s). Defaults to local computer.

.PARAMETER User
  Optional specific user (domain\sam or UPN) to include a User-scope RSoP. If omitted, script exports Computer-scope only.

.PARAMETER Credential
  Optional credential for remote Invoke-Command. Required for non-trusted domains or workgroup hosts.

.PARAMETER RemoteReportFolder
  Folder on the target to place generated reports (default: C:\Windows\Temp\RSoP).

.PARAMETER CopyBackTo
  Optional local folder to copy the generated reports into (per computer subfolder). Will be created if missing.

.PARAMETER ExportHtml
  Generate an HTML report (human-readable).

.PARAMETER ExportXml
  Generate an XML report (machine-readable).

.PARAMETER Force
  Overwrite existing reports on the remote if present.

.EXAMPLES
  # Local computer, computer-scope only, HTML + XML, copy back to .\RSoP
  .\ExportAppliedGPOs.ps1 -ExportHtml -ExportXml -CopyBackTo .\RSoP -Verbose

  # Remote computer with user scope, copy back
  $cred = Get-Credential
  .\ExportAppliedGPOs.ps1 -ComputerName 'PC-001' -User 'CONTOSO\jdoe' -Credential $cred -ExportHtml -CopyBackTo .\RSoP -Verbose

  # Multiple computers from file, XML only, don't copy back
  .\ExportAppliedGPOs.ps1 -ComputerName (Get-Content .\hosts.txt) -ExportXml -Verbose

.REQUIREMENTS
  - On each target: gpresult.exe available (Windows default).
  - You need rights to query RSoP on the target (local admin recommended).
  - Remote PowerShell remoting enabled (WinRM) for remote execution.

.NOTES (Environment adjustments & future GUI prompts)
  - Computer picker (manual list, file, or AD query via OU) — GUI control.
  - User picker (optional) — GUI input with domain validation.
  - Credentials — GUI SecureString prompt.
  - Target and local output folders — GUI folder pickers.
  - Overwrite policy (Force) — GUI checkbox with warning.
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [string]$User,   # e.g., CONTOSO\jdoe or jdoe@contoso.com

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string]$RemoteReportFolder = 'C:\Windows\Temp\RSoP',

  [Parameter()]
  [string]$CopyBackTo,

  [Parameter()]
  [switch]$ExportHtml,

  [Parameter()]
  [switch]$ExportXml,

  [Parameter()]
  [switch]$Force
)

begin {
  if (-not $ExportHtml -and -not $ExportXml) {
    Write-Verbose "No format specified; defaulting to -ExportHtml."
    $ExportHtml = $true
  }

  if ($CopyBackTo -and -not (Test-Path $CopyBackTo)) {
    New-Item -Path $CopyBackTo -ItemType Directory -Force | Out-Null
  }

  $results = New-Object System.Collections.Generic.List[Object]
}

process {
  foreach ($cn in $ComputerName) {
    Write-Verbose "Processing $cn …"

    # Remote script: run gpresult on the TARGET
    $remoteScript = {
      param($user, $folder, $doHtml, $doXml, $force)

      if (-not (Test-Path $folder)) { New-Item -Path $folder -ItemType Directory -Force | Out-Null }

      $time = Get-Date -Format "yyyyMMdd_HHmmss"
      $base = Join-Path $folder ("RSoP_$env:COMPUTERNAME" + $(if ($user) { "_$($user -replace '[\\/:*?""<>|]','_')" } else { "" }) + "_$time")

      $out = @()

      if ($doHtml) {
        $html = "$base.html"
        $gpArgs = @('/H', $html, '/F')
        if ($user) { $gpArgs += @('/USER', $user) }
        Start-Process -FilePath 'gpresult.exe' -ArgumentList $gpArgs -Wait -PassThru -WindowStyle Hidden | Out-Null
        $out += $html
      }

      if ($doXml) {
        $xml = "$base.xml"
        $gpArgs = @('/X', $xml, '/F')
        if ($user) { $gpArgs += @('/USER', $user) }
        Start-Process -FilePath 'gpresult.exe' -ArgumentList $gpArgs -Wait -PassThru -WindowStyle Hidden | Out-Null
        $out += $xml
      }

      return $out
    }

    try {
      $files = if ($Credential) {
        Invoke-Command -ComputerName $cn -Credential $Credential -ScriptBlock $remoteScript -ArgumentList $User, $RemoteReportFolder, $ExportHtml.IsPresent, $ExportXml.IsPresent, $Force.IsPresent -ErrorAction Stop
      } else {
        Invoke-Command -ComputerName $cn -ScriptBlock $remoteScript -ArgumentList $User, $RemoteReportFolder, $ExportHtml.IsPresent, $ExportXml.IsPresent, $Force.IsPresent -ErrorAction Stop
      }

      # Copy reports back (optional)
      $copied = @()
      if ($CopyBackTo) {
        $dest = Join-Path $CopyBackTo $cn
        if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }
        foreach ($rf in $files) {
          $sharePath = "\\$cn\" + ($rf -replace ':','$')
          try {
            $lf = Join-Path $dest (Split-Path $rf -Leaf)
            Copy-Item -Path $sharePath -Destination $lf -Force
            $copied += $lf
          } catch {
            Write-Warning "Failed to copy $sharePath -> $dest : $($_.Exception.Message)"
          }
        }
      }

      $results.Add([pscustomobject]@{
        ComputerName = $cn
        RemoteFiles  = ($files -join '; ')
        CopiedTo     = if ($CopyBackTo) { (Join-Path $CopyBackTo $cn) } else { $null }
        Status       = 'OK'
      })
    } catch {
      Write-Warning "Failed $cn : $($_.Exception.Message)"
      $results.Add([pscustomobject]@{
        ComputerName = $cn
        RemoteFiles  = $null
        CopiedTo     = $null
        Status       = 'Error'
        Message      = $_.Exception.Message
      })
    }
  }
}

end {
  $results | Format-Table -AutoSize
}