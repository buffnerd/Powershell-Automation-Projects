<#
.SYNOPSIS
  Hardware & platform inventory across one or more Windows computers.

.DESCRIPTION
  Collects commonly requested hardware facts:
    - System: Manufacturer, Model, SerialNumber, ChassisType
    - BIOS/UEFI: SMBIOSBIOSVersion, BIOSReleaseDate, UEFIMode, SecureBoot
    - CPU & Memory: Name, Cores/Logical, Total RAM (GB)
    - Disks: Total size, Free space (summaries); physical type where possible
    - NICs: Enabled NICs, IPv4 list (compressed)
    - OS: Caption, Version, Build, InstallDate, LastBootUpTime
    - Optional: TPM present/ready, BitLocker volume protection status (summary)

.PARAMETER ComputerName
  One or more computers (default: local).

.PARAMETER Credential
  Optional credential for remote collection.

.PARAMETER IncludeTPM
  Include TPM presence/ready state (requires TPM module/WMI provider).

.PARAMETER IncludeSecureBoot
  Include Secure Boot state (on UEFI systems).

.PARAMETER IncludeBitLocker
  Include BitLocker volume protection summary (uses Win32_EncryptableVolume / manage-bde fallback).

.PARAMETER OutputCsv
  Optional CSV output path.

.PARAMETER OutputJsonl
  Optional JSONL (one object per line) output path.

.PARAMETER ThrottleLimit
  Max concurrent remote executions (default: 8).

.EXAMPLES
  # Quick fleet snapshot to CSV
  .\HardwareInventory.ps1 -ComputerName (gc .\hosts.txt) -OutputCsv .\hw.csv -Verbose

  # Add security posture bits (TPM/SecureBoot/BitLocker) for a smaller scope
  .\HardwareInventory.ps1 -ComputerName PC-01,PC-02 -IncludeTPM -IncludeSecureBoot -IncludeBitLocker -OutputJsonl .\hw.jsonl

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Target list: -ComputerName (textbox, file, or AD query)
  - Security bits: -IncludeTPM, -IncludeSecureBoot, -IncludeBitLocker (checkboxes)
  - Parallelism: -ThrottleLimit slider
  - Exports: -OutputCsv, -OutputJsonl (save dialogs)
  - Credentials: -Credential for cross-domain/workgroup targets
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [switch]$IncludeTPM,

  [Parameter()]
  [switch]$IncludeSecureBoot,

  [Parameter()]
  [switch]$IncludeBitLocker,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputJsonl,

  [Parameter()]
  [ValidateRange(1,64)]
  [int]$ThrottleLimit = 8
)

begin {
  # --- Remote scriptblock that runs ON THE TARGET ---
  $sb = {
    param($wantTPM,$wantSB,$wantBL)

    function Try-Get {
      param([scriptblock]$Code)
      try { & $Code } catch { $null }
    }

    # System & BIOS
    $cs  = Try-Get { Get-CimInstance Win32_ComputerSystem }
    $bios= Try-Get { Get-CimInstance Win32_BIOS }
    $bb  = Try-Get { Get-CimInstance Win32_BaseBoard }
    $os  = Try-Get { Get-CimInstance Win32_OperatingSystem }

    # CPU / RAM
    $cpu = Try-Get { Get-CimInstance Win32_Processor | Select-Object -First 1 }
    $mem = Try-Get { (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory }

    # Disks (logical summary)
    $drives = Try-Get { Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" }
    $diskSummary = if ($drives) {
      [pscustomobject]@{
        Count      = ($drives | Measure-Object).Count
        TotalGB    = [math]::Round(($drives | Measure-Object -Property Size -Sum).Sum /1GB, 2)
        FreeGB     = [math]::Round(($drives | Measure-Object -Property FreeSpace -Sum).Sum /1GB, 2)
        FreePct    = if ((($drives | Measure-Object -Property Size -Sum).Sum) -gt 0) {
                        [math]::Round((($drives | Measure-Object -Property FreeSpace -Sum).Sum) /
                                       (($drives | Measure-Object -Property Size -Sum).Sum) * 100, 1)
                      } else { $null }
      }
    } else { $null }

    # Physical disks (type hint)
    $phys = Try-Get { Get-CimInstance -Namespace root\microsoft\windows\storage MSFT_PhysicalDisk }
    $diskType = if ($phys) { ($phys.MediaType | Sort-Object -Unique) -join ',' } else { $null }

    # NICs
    $nics = Try-Get { Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" }
    $ipv4 = if ($nics) { ($nics.IPAddress | ForEach-Object { $_ } | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } | Sort-Object -Unique) -join ',' } else { $null }

    # ChassisType
    $enclosure = Try-Get { Get-CimInstance Win32_SystemEnclosure }
    $chassis   = $enclosure.ChassisTypes -join ','

    # UEFI / Secure Boot
    $uefi = $null; $secureBoot = $null
    if ($wantSB) {
      $uefi = Try-Get { (Confirm-SecureBootUEFI -ErrorAction Stop) | Out-Null; $true }  # If cmdlet works → UEFI
      $secureBoot = Try-Get { Confirm-SecureBootUEFI }  # $true/$false/$null
    }

    # TPM
    $tpmPresent = $null; $tpmReady = $null; $tpmVersion = $null
    if ($wantTPM) {
      $tpm = Try-Get { Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm }
      if ($tpm) {
        $tpmPresent = $tpm.IsPresent
        $tpmReady   = $tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue
        $tpmVersion = if ($tpm.SpecVersion) { $tpm.SpecVersion } else { $null }
      }
    }

    # BitLocker
    $blSummary = $null
    if ($wantBL) {
      $vols = Try-Get {
        Get-CimInstance -Namespace root\cimv2\security\microsoftvolumeencryption -Class Win32_EncryptableVolume
      }
      if ($vols) {
        $prot = @()
        foreach ($v in $vols) {
          $p = Try-Get { $v.GetProtectionStatus().ProtectionStatus }
          $drv= Try-Get { $v.DriveLetter }
          $status = switch ($p) { 0 {'Off'} 1 {'On'} $_ {'Unknown'} }
          $prot += "${drv}:${status}"
        }
        $blSummary = $prot -join ','
      }
    }

    # Build final object
    [pscustomobject]@{
      ComputerName     = $env:COMPUTERNAME
      Manufacturer     = $cs.Manufacturer
      Model            = $cs.Model
      SerialNumber     = $bios.SerialNumber
      BIOSVersion      = ($bios.SMBIOSBIOSVersion)
      BIOSReleaseDate  = (Try-Get { [datetime]::ParseExact(($bios.ReleaseDate).Substring(0,8),'yyyyMMdd',$null) })
      ChassisType      = $chassis
      Processor        = $cpu.Name
      Cores            = $cpu.NumberOfCores
      LogicalProcessors= $cpu.NumberOfLogicalProcessors
      MemoryGB         = if ($mem) { [math]::Round($mem/1GB,2) } else { $null }
      DiskCount        = $diskSummary.Count
      DiskTotalGB      = $diskSummary.TotalGB
      DiskFreeGB       = $diskSummary.FreeGB
      DiskFreePct      = $diskSummary.FreePct
      DiskMediaTypes   = $diskType
      NIC_IPv4         = $ipv4
      OSCaption        = $os.Caption
      OSEdition        = $os.OperatingSystemSKU
      OSVersion        = $os.Version
      OSBuild          = $os.BuildNumber
      OSInstallDate    = ($os.InstallDate)
      LastBootUpTime   = ($os.LastBootUpTime)
      UEFIMode         = $uefi
      SecureBoot       = $secureBoot
      TPM_Present      = $tpmPresent
      TPM_Ready        = $tpmReady
      TPM_SpecVersion  = $tpmVersion
      BitLockerSummary = $blSummary
    }
  }

  if (-not $OutputCsv -and -not $OutputJsonl) {
    Write-Verbose "No output specified; will print table only."
  }
  $bag = New-Object System.Collections.Concurrent.ConcurrentBag[object]
}

process {
  # Build per-host PowerShell instances for throttled parallel collection
  $workers = foreach ($cn in $ComputerName) {
    $ps = [powershell]::Create()
    $ps.AddScript({
      param($cn,$cred,$sb,$p1,$p2,$p3)
      try {
        if ($cred) {
          Invoke-Command -ComputerName $cn -Credential $cred -ScriptBlock $sb -ArgumentList $p1,$p2,$p3 -ErrorAction Stop
        } else {
          Invoke-Command -ComputerName $cn -ScriptBlock $sb -ArgumentList $p1,$p2,$p3 -ErrorAction Stop
        }
      } catch {
        [pscustomobject]@{ ComputerName=$cn; Manufacturer=$null; Model=$null; SerialNumber=$null; Error=$_.Exception.Message }
      }
    }).AddArgument($cn).AddArgument($Credential).AddArgument($sb).AddArgument($IncludeTPM.IsPresent).AddArgument($IncludeSecureBoot.IsPresent).AddArgument($IncludeBitLocker.IsPresent) | Out-Null
    $ps
  }

  # Throttle
  $running = @()
  foreach ($ps in $workers) {
    $ps.BeginInvoke() | Out-Null
    $running += $ps
    while ($running.Count -ge $ThrottleLimit) {
      Start-Sleep -Milliseconds 200
      $running = $running | Where-Object { $_.InvocationStateInfo.State -notin 'Completed','Failed' }
    }
  }

  foreach ($ps in $workers) {
    while ($ps.InvocationStateInfo.State -notin 'Completed','Failed') { Start-Sleep -Milliseconds 150 }
    try {
      $r = $ps.EndInvoke($null)
      $bag.Add($r)
    } catch {
      $bag.Add([pscustomobject]@{ ComputerName='Unknown'; Error=$_.Exception.Message })
    } finally {
      $ps.Dispose()
    }
  }
}

end {
  $rows = $bag.ToArray() | Sort-Object ComputerName

  if ($OutputCsv)  { try { $rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" } }
  if ($OutputJsonl){ try { $rows | ForEach-Object { $_ | ConvertTo-Json -Depth 6 -Compress } | Out-File -FilePath $OutputJsonl -Encoding UTF8 } catch { Write-Warning "JSONL export failed: $($_.Exception.Message)" } }

  $rows | Select-Object ComputerName,Manufacturer,Model,SerialNumber,Processor,MemoryGB,DiskTotalGB,DiskFreeGB,OSCaption,OSVersion,OSBuild,UEFIMode,SecureBoot,TPM_Present,BitLockerSummary |
    Format-Table -AutoSize
}