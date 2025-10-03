<#
.SYNOPSIS
  Check disk space across one or more Windows computers and flag low free space.

.DESCRIPTION
  Queries NTFS/local fixed disks (DriveType = 3) using CIM (Win32_LogicalDisk),
  computes free %, free GB, and flags volumes breaching thresholds.
  Supports remote computers (WinRM/CIM), drive filtering, and CSV export.

.PARAMETER ComputerName
  One or more target computers. Default is the local computer.

.PARAMETER Credential
  Optional credential for remote CIM sessions.

.PARAMETER MinFreePercent
  Minimum acceptable free space percentage (default: 10).

.PARAMETER MinFreeGB
  Minimum acceptable free space in GB (default: 5).

.PARAMETER ExcludeDrives
  One or more drive letters (e.g., 'D','E') to exclude from the check.

.PARAMETER IncludeDrives
  One or more drive letters to explicitly include; overrides ExcludeDrives.

.PARAMETER AlertOnly
  If set, only outputs rows that violate thresholds.

.PARAMETER OutputCsv
  Optional path to write a CSV report.

.EXAMPLES
  PS> .\DiskSpaceCheck.ps1 -ComputerName server01,server02 -Verbose
  PS> .\DiskSpaceCheck.ps1 -ComputerName (Get-Content .\servers.txt) -MinFreePercent 15 -MinFreeGB 10 -AlertOnly -OutputCsv .\disk_alerts.csv
  PS> .\DiskSpaceCheck.ps1 -ComputerName server01 -Credential (Get-Credential) -IncludeDrives 'C','E'

.REQUIREMENTS
  - PowerShell 5+.
  - For remote hosts: WinRM/CIM enabled; firewall allows remote management; DNS reachable.
  - You need rights to query WMI/CIM remotely.

.NOTES (Environment adjustments & future GUI prompts)
  - Computer targets: list, file picker, or AD query (GUI).
  - Credentials: optional credential prompt (GUI).
  - Thresholds: sliders or numeric inputs for % and GB (GUI).
  - Drive selection: multi-select include/exclude (GUI).
  - Output path: save-as dialog (GUI).
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [ValidateRange(1,100)]
  [int]$MinFreePercent = 10,

  [Parameter()]
  [ValidateRange(1, 100000)]
  [int]$MinFreeGB = 5,

  [Parameter()]
  [ValidatePattern('^[A-Za-z]$')]
  [string[]]$ExcludeDrives,

  [Parameter()]
  [ValidatePattern('^[A-Za-z]$')]
  [string[]]$IncludeDrives,

  [Parameter()]
  [switch]$AlertOnly,

  [Parameter()]
  [string]$OutputCsv
)

begin {
  $sessions = @{}
  $results  = New-Object System.Collections.Generic.List[Object]
}

process {
  foreach ($cn in $ComputerName) {
    try {
      if ($Credential) {
        $sessions[$cn] = New-CimSession -ComputerName $cn -Credential $Credential -ErrorAction Stop
      } else {
        $sessions[$cn] = New-CimSession -ComputerName $cn -ErrorAction Stop
      }
    } catch {
      Write-Warning "Failed to create CIM session to '$cn': $($_.Exception.Message)"
      continue
    }

    try {
      $disks = Get-CimInstance -CimSession $sessions[$cn] -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
    } catch {
      Write-Warning "Failed to query disks on '$cn': $($_.Exception.Message)"
      continue
    }

    foreach ($d in $disks) {
      $letter = ($d.DeviceID).TrimEnd(':')
      # Include/Exclude filter logic
      if ($IncludeDrives -and ($letter -notin $IncludeDrives)) { continue }
      if ($ExcludeDrives -and ($letter -in  $ExcludeDrives))   { continue }

      $sizeGB = [math]::Round(($d.Size/1GB),2)
      $freeGB = [math]::Round(($d.FreeSpace/1GB),2)
      $freePC = if ($d.Size -gt 0) { [math]::Round(($d.FreeSpace / $d.Size * 100),2) } else { 0 }

      $isAlert = ($freePC -lt $MinFreePercent) -or ($freeGB -lt $MinFreeGB)

      $row = [pscustomobject]@{
        ComputerName = $cn
        Drive        = $d.DeviceID
        FileSystem   = $d.FileSystem
        SizeGB       = $sizeGB
        FreeGB       = $freeGB
        FreePercent  = $freePC
        Alert        = $isAlert
        ThresholdPC  = $MinFreePercent
        ThresholdGB  = $MinFreeGB
      }

      if ($AlertOnly) {
        if ($isAlert) { $results.Add($row) }
      } else {
        $results.Add($row)
      }
    }
  }
}

end {
  if ($OutputCsv) {
    try {
      $results | Export-Csv -Path $OutputCsv -NoTypeInformation
      Write-Verbose "Wrote CSV report to '$OutputCsv'."
    } catch {
      Write-Warning "Failed to write CSV '$OutputCsv': $($_.Exception.Message)"
    }
  }
  $results | Sort-Object ComputerName, Drive | Format-Table -AutoSize

  # Cleanup sessions
  foreach ($s in $sessions.Values) {
    try { $s | Remove-CimSession -ErrorAction SilentlyContinue } catch {}
  }
}
