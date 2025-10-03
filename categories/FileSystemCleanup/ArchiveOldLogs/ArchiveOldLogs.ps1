<#
.SYNOPSIS
  Compress old logs into ZIPs with guardrails and clear reporting.

.DESCRIPTION
  Scans roots for candidate log files older than N days and matching file patterns.
  Builds ZIPs under a destination root mirroring source structure (or per-date). Optionally
  deletes originals after successful compression. Records a manifest of actions in CSV.

.PARAMETER Path
  One or more root folders (UNC or local).

.PARAMETER AgeDays
  Only files with LastWriteTime older than this are candidates. Default: 14.

.PARAMETER IncludePatterns
  Wildcards of files to include (default: "*.log","*.txt","*.etl","*.evtx").

.PARAMETER ExcludePatterns
  Wildcards to exclude (e.g., "*.current","*.lck").

.PARAMETER ExcludePathLike
  Wildcard path filter to skip directories.

.PARAMETER DestinationRoot
  Root folder where ZIPs are written (required). Script mirrors source structure beneath this root.

.PARAMETER PerFolderZip
  Create a single ZIP per source folder (default). If not set, rolls ZIPs by date bucket (yyyy-MM).

.PARAMETER MaxZipSizeMB
  If > 0, starts a new ZIP when current one would exceed this size (approximate). Default 0 = unlimited.

.PARAMETER DeleteOriginals
  If set, deletes log files after successful compression. Default: OFF (safer).

.PARAMETER OutputCsv
  Optional CSV manifest path.

.PARAMETER ErrorLog
  Optional text log for errors/warnings.

.PARAMETER DryRun
  Preview only; no changes.

.EXAMPLES
  # Archive *.log older than 30 days into per-folder zips under \\nas\archives
  .\ArchiveOldLogs.ps1 -Path "D:\Apps\Logs","\\fs01\Web\Logs" -AgeDays 30 -DestinationRoot "\\nas\archives" -Verbose

  # Date-bucketed ZIPs with max ~500 MB each; delete originals after
  .\ArchiveOldLogs.ps1 -Path "D:\Logs" -AgeDays 7 -DestinationRoot "E:\LogArchive" -MaxZipSizeMB 500 -DeleteOriginals

  # Preview only; add *.txt and *.evtx patterns; exclude a path
  .\ArchiveOldLogs.ps1 -Path "D:\Logs" -IncludePatterns "*.log","*.txt","*.evtx" -ExcludePathLike "*\active\*" -DryRun

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Roots to scan: -Path (multi-select)
  - Age threshold: -AgeDays slider
  - Patterns: include/exclude lists; ExcludePathLike
  - Destination root picker; Per-folder vs date buckets toggle
  - Rollover: -MaxZipSizeMB numeric
  - Delete originals toggle (OFF by default)
  - Dry-run/WhatIf + manifest CSV and ErrorLog paths
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [string[]]$Path,

  [Parameter()]
  [ValidateRange(1,3650)]
  [int]$AgeDays = 14,

  [Parameter()]
  [string[]]$IncludePatterns = @("*.log","*.txt","*.etl","*.evtx"),

  [Parameter()]
  [string[]]$ExcludePatterns,

  [Parameter()]
  [string]$ExcludePathLike,

  [Parameter(Mandatory)]
  [string]$DestinationRoot,

  [Parameter()]
  [switch]$PerFolderZip,

  [Parameter()]
  [ValidateRange(0, 102400)]
  [int]$MaxZipSizeMB = 0,

  [Parameter()]
  [switch]$DeleteOriginals,

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

if (-not (Test-Path $DestinationRoot)) {
  try { New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null } catch { throw "Cannot create DestinationRoot: $($_.Exception.Message)" }
}

$cutoff = (Get-Date).AddDays(-1 * $AgeDays)
$manifest = New-Object System.Collections.Generic.List[Object]

# Group candidates per source folder (and optionally date bucket)
function Get-LogCandidates {
  param([string[]]$Roots)
  $bucket = @{}

  foreach ($root in $Roots) {
    if (-not (Test-Path $root)) { Write-ErrorToLog "Path not found: $root"; continue }
    try {
      $files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue
    } catch {
      Write-ErrorToLog "Enumeration failed: $root : $($_.Exception.Message)"; continue
    }

    foreach ($f in $files) {
      if ($ExcludePathLike -and ($f.FullName -like $ExcludePathLike)) { continue }
      if ($IncludePatterns -and ($IncludePatterns | Where-Object { $f.Name -like $_ }).Count -eq 0) { continue }
      if ($ExcludePatterns -and ($ExcludePatterns | Where-Object { $f.Name -like $_ }).Count -gt 0) { continue }
      if ($f.LastWriteTime -ge $cutoff) { continue }

      $keyFolder = $f.DirectoryName
      $keyDate   = Get-Date $f.LastWriteTime -Format 'yyyy-MM'
      $key       = if ($PerFolderZip) { $keyFolder } else { "$keyFolder|$keyDate" }

      if (-not $bucket.ContainsKey($key)) { $bucket[$key] = New-Object System.Collections.Generic.List[Object] }
      $bucket[$key].Add($f)
    }
  }
  return $bucket
}

$candidateMap = Get-LogCandidates -Roots $Path

# Helper to compute destination ZIP path
function Get-ArchiveZipPath {
  param([string]$Key)
  if ($PerFolderZip) {
    $srcFolder = $Key
    $rel = $srcFolder -replace '^[A-Za-z]:','' ; $rel = $rel.TrimStart('\','/')
    $zipDir = Join-Path $DestinationRoot $rel
    if (-not (Test-Path $zipDir)) { New-Item -ItemType Directory -Path $zipDir -Force | Out-Null }
    return Join-Path $zipDir "archive.zip"
  } else {
    $parts = $Key -split '\|',2
    $srcFolder = $parts[0]; $bucket = $parts[1]
    $rel = $srcFolder -replace '^[A-Za-z]:','' ; $rel = $rel.TrimStart('\','/')
    $zipDir = Join-Path (Join-Path $DestinationRoot $rel) $bucket
    if (-not (Test-Path $zipDir)) { New-Item -ItemType Directory -Path $zipDir -Force | Out-Null }
    return Join-Path $zipDir "archive_$bucket.zip"
  }
}

# Add files to ZIP (handles size rollover)
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Add-FilesToZip {
  param([System.Collections.Generic.List[Object]]$Files,[string]$ZipPath,[int]$MaxMB,[switch]$DryRunMode)
  $created = @()
  $currentZip = $ZipPath
  $index = 1
  $currentSize = 0

  if ($DryRunMode) {
    foreach ($f in $Files) { $created += $currentZip } # preview
    return ,$created
  }

  foreach ($f in $Files) {
    # Rollover if needed (approx via file size)
    if ($MaxMB -gt 0 -and ($currentSize + $f.Length) -gt ($MaxMB * 1MB)) {
      $index++
      $base = [System.IO.Path]::GetFileNameWithoutExtension($ZipPath)
      $dir  = Split-Path $ZipPath -Parent
      $currentZip = Join-Path $dir ("{0}_{1}.zip" -f $base,$index)
      $currentSize = 0
    }

    if (-not (Test-Path $currentZip)) {
      # Create empty zip
      [System.IO.Compression.ZipFile]::Open($currentZip, [System.IO.Compression.ZipArchiveMode]::Create).Dispose()
      $created += $currentZip
    }

    $archive = [System.IO.Compression.ZipFile]::Open($currentZip, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
      $entryPath = $f.FullName -replace '^[A-Za-z]:','' ; $entryPath = $entryPath.TrimStart('\','/')
      $null = $archive.CreateEntryFromFile($f.FullName, $entryPath, [System.IO.Compression.CompressionLevel]::Optimal)
      $currentSize += $f.Length
    } finally {
      $archive.Dispose()
    }
  }
  return ,$created
}

[int64]$totalBytes = 0
foreach ($key in $candidateMap.Keys) {
  $files = $candidateMap[$key]
  if (-not $files -or $files.Count -eq 0) { continue }

  $zip = Get-ArchiveZipPath -Key $key
  $zipList = Add-FilesToZip -Files $files -ZipPath $zip -MaxMB $MaxZipSizeMB -DryRunMode:$DryRun

  foreach ($f in $files) {
    $manifest.Add([pscustomobject]@{
      SourcePath      = $f.FullName
      SizeBytes       = $f.Length
      LastWriteTime   = $f.LastWriteTime
      ZipTarget       = ($zipList | Select-Object -Last 1)
      Action          = if ($DryRun) { 'DRYRUN:Compress' } else { 'Compress' }
      DeleteOriginal  = $DeleteOriginals.IsPresent
    })
    if (-not $DryRun) { $totalBytes += $f.Length }
  }

  # Delete originals after successful compression
  if ($DeleteOriginals -and -not $DryRun) {
    if ($PSCmdlet.ShouldProcess(($files[0].DirectoryName), "Delete originals ($($files.Count))")) {
      foreach ($f in $files) {
        try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop } catch { Write-ErrorToLog "Delete failed $($f.FullName): $($_.Exception.Message)" }
      }
    }
  }
}

# Export manifest and print summary
if ($OutputCsv) {
  try { $manifest | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-ErrorToLog "CSV export failed: $($_.Exception.Message)" }
}

$summary = [pscustomobject]@{
  FilesArchived = ($manifest | Measure-Object).Count
  EstimatedBytesCompressed = $totalBytes
  EstimatedMBCompressed    = [math]::Round($totalBytes/1MB,2)
  ZipsCreatedOrUpdated     = ($manifest | Select-Object -ExpandProperty ZipTarget -Unique).Count
}
$summary | Format-List