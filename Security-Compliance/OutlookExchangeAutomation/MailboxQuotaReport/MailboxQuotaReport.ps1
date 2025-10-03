<#
.SYNOPSIS
  Report mailbox sizes vs quotas (EXO and/or on-prem), with threshold flags and exports.

.DESCRIPTION
  For each mailbox:
   - Size (TotalItemSize), ItemCount
   - ProhibitSendQuota / ProhibitSendReceiveQuota (and IssueWarningQuota when available)
   - Percent used (vs ProhibitSendReceiveQuota)
   - Archive mailbox stats (if present)
  Outputs table and optional CSV/HTML.

.PARAMETER ConnectOnline
  Connect to Exchange Online (EXO) using Connect-ExchangeOnline.

.PARAMETER ConnectOnPrem
  Connect to on-prem Exchange via implicit remoting.

.PARAMETER OnPremUri
  On-prem Exchange PowerShell URI.

.PARAMETER Credential
  PSCredential for either EXO or on-prem.

.PARAMETER Identity
  Optional mailbox identity filter (string, accepts wildcards).

.PARAMETER MinPercentUsed
  Only show rows >= this % used (default 0).

.PARAMETER IncludeArchive
  Include archive mailbox statistics.

.PARAMETER OutputCsv
  CSV output path.

.PARAMETER OutputHtml
  HTML output path (pretty table).

.EXAMPLES
  # EXO: all mailboxes, show >= 80% used
  .\MailboxQuotaReport.ps1 -ConnectOnline -MinPercentUsed 80 -OutputCsv .\quota80.csv -Verbose

  # On-prem subset by identity
  .\MailboxQuotaReport.ps1 -ConnectOnPrem -OnPremUri https://ex01/powershell/ -Identity "Sales*" -OutputHtml .\quota.html

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Connection choice and creds: -ConnectOnline / -ConnectOnPrem (+ URI) / -Credential
  - Scope: -Identity filter, include archive toggle
  - Threshold: -MinPercentUsed slider
  - Exports: -OutputCsv, -OutputHtml
#>
[CmdletBinding()]
param(
  [Parameter()]
  [switch]$ConnectOnline,

  [Parameter()]
  [switch]$ConnectOnPrem,

  [Parameter()]
  [string]$OnPremUri,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string]$Identity,

  [Parameter()]
  [ValidateRange(0,100)]
  [int]$MinPercentUsed = 0,

  [Parameter()]
  [switch]$IncludeArchive,

  [Parameter()]
  [string]$OutputCsv,

  [Parameter()]
  [string]$OutputHtml
)

function Connect-EXOIfNeeded {
  param([pscredential]$Cred)
  if (-not (Get-Module ExchangeOnlineManagement)) {
    Write-Warning "ExchangeOnlineManagement not loaded. Install-Module ExchangeOnlineManagement"
  }
  try {
    if ($Cred) { Connect-ExchangeOnline -Credential $Cred -ShowBanner:$false -ErrorAction Stop }
    else       { Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop }
  } catch { throw "EXO connect failed: $($_.Exception.Message)" }
}

function Connect-OnPremIfNeeded {
  param([string]$Uri,[pscredential]$Cred)
  if (-not $Uri) { throw "On-prem Exchange URI required." }
  try {
    $sess = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $Uri -Credential $Cred -Authentication Kerberos -ErrorAction Stop
    Import-PSSession $sess -DisableNameChecking -ErrorAction Stop | Out-Null
  } catch { throw "On-prem connect failed: $($_.Exception.Message)" }
}

function ConvertTo-Bytes {
  param($exSize)
  # Converts Exchange-style size "123.4 MB (129,555,555 bytes)" to [long] bytes safely
  if (-not $exSize) { return 0 }
  if ($exSize.ToString() -match '\(([\d,]+) bytes\)') {
    return [int64]($Matches[1] -replace ',','')
  }
  # Fallback: try casting
  try { return [int64]$exSize } catch { return 0 }
}

# Connect as requested
if ($ConnectOnline) { if (-not $Credential) { $Credential = Get-Credential } ; Connect-EXOIfNeeded -Cred $Credential }
if ($ConnectOnPrem) { if (-not $Credential) { $Credential = Get-Credential } ; Connect-OnPremIfNeeded -Uri $OnPremUri -Cred $Credential }

# Get mailboxes
$mailboxes = @()
if ($ConnectOnline) {
  $mbxArgs = @{}
  if ($Identity) { $mbxArgs['Identity'] = $Identity }
  $mailboxes = Get-EXOMailbox @mbxArgs -ResultSize Unlimited
} elseif ($ConnectOnPrem) {
  $mbxArgs = @{}
  if ($Identity) { $mbxArgs['Identity'] = $Identity }
  $mailboxes = Get-Mailbox @mbxArgs -ResultSize Unlimited
} else {
  throw "Choose -ConnectOnline or -ConnectOnPrem."
}

$rows = New-Object System.Collections.Generic.List[Object]

foreach ($m in $mailboxes) {
  try {
    if ($ConnectOnline) {
      $st = Get-EXOMailboxStatistics -Identity $m.UserPrincipalName -ErrorAction Stop
      $quota = Get-EXOMailbox -Identity $m.UserPrincipalName | Select-Object -ExpandProperty ProhibitSendReceiveQuota -ErrorAction SilentlyContinue
      $warn  = Get-EXOMailbox -Identity $m.UserPrincipalName | Select-Object -ExpandProperty IssueWarningQuota -ErrorAction SilentlyContinue
      $send  = Get-EXOMailbox -Identity $m.UserPrincipalName | Select-Object -ExpandProperty ProhibitSendQuota  -ErrorAction SilentlyContinue
    } else {
      $id = $m.Identity
      $st = Get-MailboxStatistics -Identity $id -ErrorAction Stop
      $mbx = Get-Mailbox -Identity $id
      $quota = $mbx.ProhibitSendReceiveQuota
      $warn  = $mbx.IssueWarningQuota
      $send  = $mbx.ProhibitSendQuota
    }

    $usedBytes = ConvertTo-Bytes $st.TotalItemSize
    $quotaBytes= ConvertTo-Bytes $quota
    $pct = if ($quotaBytes -gt 0) { [math]::Round(($usedBytes / $quotaBytes) * 100, 1) } else { 0 }

    $row = [pscustomobject]@{
      DisplayName   = $m.DisplayName
      PrimarySmtp   = $m.PrimarySmtpAddress
      ItemCount     = $st.ItemCount
      TotalSize     = $st.TotalItemSize
      ProhibitSend  = $send
      ProhibitSR    = $quota
      IssueWarning  = $warn
      PercentUsed   = $pct
      ArchiveItems  = $null
      ArchiveSize   = $null
    }

    if ($IncludeArchive -and $m.ArchiveStatus -and $m.ArchiveStatus -ne 'None') {
      try {
        if ($ConnectOnline) {
          $ast = Get-EXOMailboxStatistics -Identity $m.UserPrincipalName -Archive -ErrorAction Stop
        } else {
          $ast = Get-MailboxStatistics -Identity $m.Identity -Archive -ErrorAction Stop
        }
        $row.ArchiveItems = $ast.ItemCount
        $row.ArchiveSize  = $ast.TotalItemSize
      } catch { }
    }

    if ($row.PercentUsed -ge $MinPercentUsed) {
      $rows.Add($row)
    }

  } catch {
    $rows.Add([pscustomobject]@{
      DisplayName   = $m.DisplayName
      PrimarySmtp   = $m.PrimarySmtpAddress
      ItemCount     = $null
      TotalSize     = $null
      ProhibitSend  = $null
      ProhibitSR    = $null
      IssueWarning  = $null
      PercentUsed   = -1
      ArchiveItems  = $null
      ArchiveSize   = $null
      Error         = $_.Exception.Message
    })
  }
}

# Output
if ($OutputCsv) {
  try { $rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

if ($OutputHtml) {
  $style = @"
<style>
table { border-collapse: collapse; font-family: Segoe UI, Arial, sans-serif; font-size: 12px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; }
th { background: #f4f4f4; text-align: left; }
tr.alert { background: #fff5f5; }
</style>
"@
  $rowsHtml = $rows | Sort-Object PercentUsed -Descending | ConvertTo-Html -Title "Mailbox Quota Report" -Head $style -PreContent "<h2>Mailbox Quota Report</h2><p>Generated: $(Get-Date)</p>"
  try { $rowsHtml | Out-File -FilePath $OutputHtml -Encoding UTF8 } catch { Write-Warning "HTML export failed: $($_.Exception.Message)" }
}

$rows | Sort-Object PercentUsed -Descending | Format-Table -AutoSize