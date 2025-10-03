<#
.SYNOPSIS
  Reclaim space by removing (or quarantining) stale temporary files with guardrails.

.DESCRIPTION
  Scans one or more roots plus optional common temp folders, filters by:
    - Age (LastWriteTime older than N days)
    - Min size (only delete files >= N MB)
    - Include/Exclude glob patterns
    - Exclude hidden/system items by default
  Then deletes OR moves items into a quarantine folder. Produces a CSV report and a
  summary of bytes freed. Supports -WhatIf and a separate -DryRun toggle.

.PARAMETER Path
  One or more root folders to scan (UNC or local). If not provided, only common temp folders are used when -IncludeSystemTemp is set.

.PARAMETER IncludeSystemTemp
  Include $env:TEMP and C:\Windows\Temp in the scan set.

.PARAMETER AgeDays
  Only files with LastWriteTime older than this many days are candidates. Default: 14.

.PARAMETER MinSizeMB
  Only files >= this size (in MB) are candidates. Default: 1 MB.

.PARAMETER IncludePatterns
  Optional list of wildcards to include (e.g., "*.tmp","*.log","*.bak"). If omitted, all files are considered.

.PARAMETER ExcludePatterns
  Optional wildcards to exclude (e.g., "*.dmp","*.evtx").

.PARAMETER ExcludePathLike
  Optional wildcard path filter to skip directories (e.g., "*\DoNotTouch\*").

.PARAMETER IncludeHiddenSystem
  If set, include Hidden/System files (not recommended). Default is to skip them.

.PARAMETER QuarantinePath
  If provided, matching files are MOVED here (preserving relative structure). Safer than deletion.

.PARAMETER OutputCsv
  Optional CSV filepath for the per-file action log.

.PARAMETER ErrorLog
  Optional text file to append warnings/errors.

.PARAMETER DryRun
  Preview matches and actions without deleting/moving (independent of -WhatIf).

.EXAMPLES
  # Clean typical temp folders older than 14 days, 5 MB+, report to CSV (no hidden/system)
  .\CleanupTempFiles.ps1 -IncludeSystemTemp -MinSizeMB 5 -OutputCsv .\cleanup.csv -Verbose

  # Clean a custom cache share, exclude a protected subtree, quarantine instead of delete
  .\CleanupTempFiles.ps1 -Path "\\fs01\Cache","D:\Build\_temp" -AgeDays 30 -ExcludePathLike "*\Pinned\*" `
    -QuarantinePath "E:\Quarantine\Temp" -OutputCsv .\cleanup.csv -Verbose

  # Preview only (no changes), restrict to *.tmp and *.log
  .\CleanupTempFiles.ps1 -Path "D:\Temp" -IncludePatterns "*.tmp","*.log" -DryRun

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Paths: -Path (folder picker / multi-select), Include common temp toggle
  - Safety: -DryRun checkbox, -WhatIf support, Quarantine destination picker
  - Filters: Age (days) slider, Min Size (MB), Include/Exclude patterns, exclude path like
  - Exports: -OutputCsv, -ErrorLog
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [string[]]$Path,

  [Parameter()]
  [switch]$IncludeSystemTemp,

  [Parameter()]
  [ValidateRange(1,3650)]
  [int]$AgeDays = 14,

  [Parameter()]
  [ValidateRange(0, 1048576)]
  [int]$MinSizeMB = 1,

  [Parameter()]
  [string[]]$IncludePatterns,

  [Parameter()]
  [string[]]$ExcludePatterns,

  [Parameter()]
  [string]$ExcludePathLike,

  [Parameter()]
  [switch]$IncludeHiddenSystem,

  [Parameter()]
  [string]$QuarantinePath,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$ErrorLog,

  [Parameter()]
  [switch]$DryRun
)

function Write-ErrorToLog {
  param([string]$Message)
  if ($ErrorLog) { try { "[$(Get-Date -Format s)] $Message" | Out-File -FilePath $ErrorLog -Append -Encoding utf8 } catch {} }
  Write-Warning $Message
}

# Build the scan set
$roots = @()
if ($Path) { $roots += $Path }
if ($IncludeSystemTemp) {
  $roots += $env:TEMP
  $roots += "C:\Windows\Temp"
}
$roots = $roots | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique
if (-not $roots) { throw "No valid paths to scan. Provide -Path and/or -IncludeSystemTemp." }

$cutoff = (Get-Date).AddDays(-1 * $AgeDays)
$candidates = New-Object System.Collections.Generic.List[Object]

# Enumerate files
foreach ($root in $roots) {
  try {
    $files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue
  } catch {
    Write-ErrorToLog "Enumeration failed: $root : $($_.Exception.Message)"
    continue
  }

  foreach ($f in $files) {
    # Exclude Hidden/System unless explicitly included
    if (-not $IncludeHiddenSystem) {
      $attr = $f.Attributes
      if ($attr -band [IO.FileAttributes]::Hidden -or $attr -band [IO.FileAttributes]::System) { continue }
    }

    if ($ExcludePathLike -and ($f.FullName -like $ExcludePathLike)) { continue }

    if ($IncludePatterns -and ($IncludePatterns | Where-Object { $f.Name -like $_ }).Count -eq 0) { continue }
    if ($ExcludePatterns -and ($ExcludePatterns | Where-Object { $f.Name -like $_ }).Count -gt 0) { continue }

    if ($f.LastWriteTime -ge $cutoff) { continue }

    $sizeOk = ($f.Length -ge ($MinSizeMB * 1MB))
    if (-not $sizeOk) { continue }

    $candidates.Add($f)
  }
}

# Prepare action log
$log = New-Object System.Collections.Generic.List[Object]
[int64]$bytesFreed = 0

# Quarantine helper
function Move-FileToQuarantine {
  param([System.IO.FileInfo]$File,[string]$QuarantineRoot)
  $drive = ($File.FullName -split ':[\\/]',2)[0]       # e.g., 'C'
  $rel   = $File.FullName -replace '^[A-Za-z]:',''      # strip drive colon
  $rel   = $rel.TrimStart('\','/')
  $dest  = Join-Path -Path (Join-Path $QuarantineRoot $drive) -ChildPath $rel
  $destDir = Split-Path $dest -Parent
  if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
  Move-Item -LiteralPath $File.FullName -Destination $dest -Force
  return $dest
}

foreach ($f in $candidates) {
  $action = if ($QuarantinePath) { 'Quarantine' } else { 'Delete' }
  $ok = $false; $msg = $null; $dest = $null

  if ($DryRun) {
    $ok = $true
  } elseif ($PSCmdlet.ShouldProcess($f.FullName, $action)) {
    try {
      if ($QuarantinePath) {
        $dest = Move-FileToQuarantine -File $f -QuarantineRoot $QuarantinePath
      } else {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
      }
      $ok = $true
      $bytesFreed += $f.Length
    } catch { $msg = $_.Exception.Message }
  } else {
    $ok = $true
  }

  $log.Add([pscustomobject]@{
    Path          = $f.FullName
    SizeBytes     = $f.Length
    LastWriteTime = $f.LastWriteTime
    Action        = if ($DryRun) { "DRYRUN:$action" } else { $action }
    Success       = $ok
    Message       = $msg
    QuarantinedTo = $dest
  })
}

# Output & summary
if ($OutputCsv) {
  try { $log | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-ErrorToLog "CSV export failed: $($_.Exception.Message)" }
}

$summary = [pscustomobject]@{
  ItemsConsidered = $candidates.Count
  ItemsAffected   = ($log | Where-Object Success).Count
  BytesFreed      = $bytesFreed
  MBFreed         = [math]::Round($bytesFreed/1MB,2)
}
$summary | Format-List