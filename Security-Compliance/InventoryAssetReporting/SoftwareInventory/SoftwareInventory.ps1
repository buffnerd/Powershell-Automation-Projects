<#
.SYNOPSIS
  Enumerate installed applications (registry-based) with optional filters and updates.

.DESCRIPTION
  Queries standard uninstall keys on 64-bit and WOW6432Node:
    HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*
    HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*
  Avoids Win32_Product (which is slow and can reconfigure MSI).
  Optionally includes Windows Updates via Get-HotFix for a fuller picture.

.PARAMETER ComputerName
  One or more computers (default: local).

.PARAMETER Credential
  Optional credential for remote registry/commands.

.PARAMETER NameContains
  Optional substring filter on DisplayName.

.PARAMETER PublisherContains
  Optional substring filter on Publisher.

.PARAMETER MinVersion
  Optional minimum version (semantic) to include.

.PARAMETER IncludeUpdates
  Include Get-HotFix results (KB numbers) as separate rows with Type='Update'.

.PARAMETER ExcludeSystemComponents
  If set (default), skip entries with SystemComponent=1, ParentKeyName, or no DisplayName.

.PARAMETER OutputCsv
  Optional CSV output path.

.PARAMETER OutputJsonl
  Optional JSONL output path.

.PARAMETER ThrottleLimit
  Max concurrent remote executions (default: 8).

.EXAMPLES
  # Full inventory to CSV
  .\SoftwareInventory.ps1 -ComputerName (gc .\hosts.txt) -OutputCsv .\sw.csv -Verbose

  # Filter for a vendor and versions below 10.5
  .\SoftwareInventory.ps1 -ComputerName app01 -PublisherContains 'Acme' -MinVersion 10.5

  # Include KB updates
  .\SoftwareInventory.ps1 -ComputerName desk01 -IncludeUpdates -OutputJsonl .\sw.jsonl

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Target scope: -ComputerName (textbox/file/AD query)
  - Filters: -NameContains, -PublisherContains, -MinVersion
  - Policy: -ExcludeSystemComponents (default on)
  - Updates: -IncludeUpdates (checkbox)
  - Exports: -OutputCsv, -OutputJsonl
  - Parallelism: -ThrottleLimit
  - Credentials: -Credential
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('CN')]
  [string[]]$ComputerName = $env:COMPUTERNAME,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string]$NameContains,

  [Parameter()]
  [string]$PublisherContains,

  [Parameter()]
  [version]$MinVersion,

  [Parameter()]
  [switch]$IncludeUpdates,

  [Parameter()]
  [switch]$ExcludeSystemComponents = $true,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputJsonl,

  [Parameter()]
  [ValidateRange(1,64)]
  [int]$ThrottleLimit = 8
)

begin {
  # --- Remote scriptblock executed on target ---
  $sb = {
    param($nameLike,$pubLike,$minVer,[bool]$excludeSystem,[bool]$includeUpdates)

    function Get-UninstallItems {
      param([string[]]$Roots)
      $res = New-Object System.Collections.Generic.List[Object]
      foreach ($r in $Roots) {
        try {
          $items = Get-ItemProperty -Path $r -ErrorAction SilentlyContinue
          foreach ($it in $items) {
            $dn = $it.DisplayName
            if (-not $dn) { continue }
            if ($excludeSystem) {
              if ($it.SystemComponent -eq 1) { continue }
              if ($it.ParentKeyName) { continue }
            }
            $ver = $null
            if ($it.DisplayVersion) {
              try { $ver = [version]$it.DisplayVersion } catch { $ver = $it.DisplayVersion }
            }
            $obj = [pscustomobject]@{
              ComputerName   = $env:COMPUTERNAME
              Type           = 'Product'
              DisplayName    = $dn
              DisplayVersion = $it.DisplayVersion
              VersionObj     = $ver
              Publisher      = $it.Publisher
              InstallDateRaw = $it.InstallDate
              EstimatedSizeMB= if ($it.EstimatedSize) { [math]::Round($it.EstimatedSize/1024,1) } else { $null }
              UninstallString= $it.UninstallString
              ProductCode    = $it.PSChildName  # often MSI product code
              RegistryPath   = $it.PSPath
            }
            $res.Add($obj)
          }
        } catch {}
      }
      $res
    }

    $roots = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = Get-UninstallItems -Roots $roots

    # Client-side filters
    $apps = $apps | Where-Object {
      (-not $nameLike      -or $_.DisplayName    -like "*$nameLike*") -and
      (-not $pubLike       -or $_.Publisher      -like "*$pubLike*")  -and
      (-not $minVer        -or (($_.VersionObj -is [version]) -and ($_.VersionObj -ge $minVer)))
    }

    # Add updates if requested
    if ($includeUpdates) {
      try {
        $kbs = Get-HotFix
        foreach ($kb in $kbs) {
          $apps += [pscustomobject]@{
            ComputerName   = $env:COMPUTERNAME
            Type           = 'Update'
            DisplayName    = $kb.HotFixID
            DisplayVersion = $kb.Description
            VersionObj     = $null
            Publisher      = 'Microsoft'
            InstallDateRaw = $kb.InstalledOn
            EstimatedSizeMB= $null
            UninstallString= $null
            ProductCode    = $null
            RegistryPath   = $null
          }
        }
      } catch {}
    }

    # Normalize InstallDate
    foreach ($a in $apps) {
      $d = $a.InstallDateRaw
      $installDate = if ($d -is [datetime]) { 
        $d 
      } elseif ($d -and $d.Length -eq 8 -and $d -match '^\d{8}$') {
        # YYYYMMDD as in older MSI entries
        try { [datetime]::ParseExact($d,'yyyyMMdd',$null) } catch { $null }
      } else { 
        $null 
      }
      $a | Add-Member -NotePropertyName InstallDate -NotePropertyValue $installDate
      $a.PSObject.Properties.Remove('VersionObj') | Out-Null
      $a.PSObject.Properties.Remove('InstallDateRaw') | Out-Null
    }

    return $apps
  }

  if (-not $OutputCsv -and -not $OutputJsonl) {
    Write-Verbose "No output specified; will print table only."
  }
  $bag = New-Object System.Collections.Concurrent.ConcurrentBag[object]
}

process {
  $workers = foreach ($cn in $ComputerName) {
    $ps = [powershell]::Create()
    $ps.AddScript({
      param($cn,$cred,$sb,$n,$p,$v,$ex,$upd)
      try {
        if ($cred) {
          Invoke-Command -ComputerName $cn -Credential $cred -ScriptBlock $sb -ArgumentList $n,$p,$v,$ex,$upd -ErrorAction Stop
        } else {
          Invoke-Command -ComputerName $cn -ScriptBlock $sb -ArgumentList $n,$p,$v,$ex,$upd -ErrorAction Stop
        }
      } catch {
        [pscustomobject]@{ ComputerName=$cn; Type='Error'; DisplayName=$null; DisplayVersion=$null; Publisher=$null; InstallDate=$null; Error=$_.Exception.Message }
      }
    }).AddArgument($cn).AddArgument($Credential).AddArgument($sb).AddArgument($NameContains).AddArgument($PublisherContains).AddArgument($MinVersion).AddArgument($ExcludeSystemComponents.IsPresent).AddArgument($IncludeUpdates.IsPresent) | Out-Null
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
      $bag.Add([pscustomobject]@{ ComputerName='Unknown'; Type='Error'; Error=$_.Exception.Message })
    } finally {
      $ps.Dispose()
    }
  }
}

end {
  $rows = $bag.ToArray() | Sort-Object ComputerName, Type, DisplayName, DisplayVersion

  if ($OutputCsv)  { try { $rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" } }
  if ($OutputJsonl){ try { $rows | ForEach-Object { $_ | ConvertTo-Json -Depth 6 -Compress } | Out-File -FilePath $OutputJsonl -Encoding UTF8 } catch { Write-Warning "JSONL export failed: $($_.Exception.Message)" } }

  $rows | Select-Object ComputerName,Type,DisplayName,DisplayVersion,Publisher,InstallDate,EstimatedSizeMB,ProductCode |
    Format-Table -AutoSize
}