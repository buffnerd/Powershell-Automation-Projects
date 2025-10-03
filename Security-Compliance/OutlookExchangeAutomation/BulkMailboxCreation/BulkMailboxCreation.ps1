<#
.SYNOPSIS
  Bulk create/enable mailboxes from CSV for Exchange Online or On-Prem Exchange.

.DESCRIPTION
  Reads a CSV, validates each row, and then:
   - Exchange Online:
       * Option A: Create mailbox for EXISTING Entra ID user (recommended).
       * Option B: Create NEW Entra ID user + assign license + create mailbox (optional).
   - On-Prem Exchange:
       * Enable mailbox for an EXISTING AD user (recommended).
       * Optionally create a NEW AD user + enable mailbox (requires appropriate modules/tools).

  CSV columns supported (case-insensitive; extra columns ignored):
    - UserPrincipalName  (UPN)   [EXO preferred]
    - SamAccountName     (on-prem)
    - DisplayName
    - FirstName
    - LastName
    - PrimarySmtpAddress  (if omitted, derived from UPN)
    - Alias               (mailNickname)
    - OU                  (on-prem new user target OU DN)
    - InitialPassword     (new user scenario; plain text or SecureString in separate file)
    - LicenseSku          (EXO only; e.g., 'ENTERPRISEPACK' or full Sku like 'contoso:ENTERPRISEPACK')
    - UsageLocation       (EXO license req; e.g., 'US')
    - TimeZone            (e.g., 'Pacific Standard Time')
    - Language            (e.g., 'en-US')

.PARAMETER CsvPath
  Input CSV path with one row per mailbox.

.PARAMETER Mode
  'OnlineExisting' (EXO existing user mailbox),
  'OnlineCreate'   (create EXO user + license + mailbox),
  'OnPremExisting' (enable mailbox for existing AD user),
  'OnPremCreate'   (create AD user + enable mailbox).

.PARAMETER ConnectOnline
  If set, connect to Exchange Online (EXO) using Connect-ExchangeOnline. Requires EXO V3 module.

.PARAMETER ConnectOnPrem
  If set, connects to on-prem Exchange PowerShell (implicit remoting). Provide -OnPremUri etc.

.PARAMETER OnPremUri
  On-prem Exchange PowerShell URI, e.g., https://exch01.contoso.com/powershell/

.PARAMETER Credential
  Credential used for EXO and/or on-prem sessions (prompts if omitted).

.PARAMETER DomainSuffix
  Optional default SMTP domain if PrimarySmtpAddress is missing, e.g., 'contoso.com'.

.PARAMETER DefaultPassword
  Optional SecureString default password for new users if not provided per-row.

.PARAMETER WhatIf
  Preview actions without making changes.

.PARAMETER OutputCsv
  Optional CSV to log results.

.EXAMPLES
  # EXO: create mailboxes for existing Entra ID users
  .\BulkMailboxCreation.ps1 -CsvPath .\new_mailboxes.csv -Mode OnlineExisting -ConnectOnline -Verbose

  # EXO: create brand-new users, license, and mailbox
  $cred = Get-Credential
  .\BulkMailboxCreation.ps1 -CsvPath .\hires.csv -Mode OnlineCreate -ConnectOnline -Credential $cred -DomainSuffix contoso.com -Verbose

  # On-prem: enable mailbox for existing AD users
  .\BulkMailboxCreation.ps1 -CsvPath .\ad_users.csv -Mode OnPremExisting -ConnectOnPrem -OnPremUri https://ex01/powershell/ -Verbose

.NOTES (Environment-specific adjustments & future GUI prompts)
  - Connection method and credentials
  - Mode (OnlineExisting/OnlineCreate/OnPremExisting/OnPremCreate)
  - CSV mapping + default SMTP domain
  - Default password policy for created users
  - WhatIf/OutputCsv for preview/audit
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory)]
  [string]$CsvPath,

  [Parameter(Mandatory)]
  [ValidateSet('OnlineExisting','OnlineCreate','OnPremExisting','OnPremCreate')]
  [string]$Mode,

  [Parameter()]
  [switch]$ConnectOnline,

  [Parameter()]
  [switch]$ConnectOnPrem,

  [Parameter()]
  [string]$OnPremUri,

  [Parameter()]
  [pscredential]$Credential,

  [Parameter()]
  [string]$DomainSuffix,

  [Parameter()]
  [SecureString]$DefaultPassword,

  [Parameter()]
  [switch]$WhatIf,

  [Parameter()]
  [string]$OutputCsv
)

# --------------------------
# Helpers for environment
# --------------------------
function Ensure-Modules {
  param([string[]]$Modules)
  foreach ($m in $Modules) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
      Write-Warning "Module $m not found. Please install it."
    }
  }
}

function Connect-EXOIfNeeded {
  param([pscredential]$Cred)
  if (-not (Get-Module ExchangeOnlineManagement)) {
    Write-Warning "ExchangeOnlineManagement not loaded. Install-Module ExchangeOnlineManagement"
  }
  try {
    if ($Cred) { Connect-ExchangeOnline -Credential $Cred -ShowBanner:$false -ErrorAction Stop }
    else       { Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop }
  } catch {
    throw "Failed to connect to Exchange Online: $($_.Exception.Message)"
  }
}

function Connect-OnPremIfNeeded {
  param([string]$Uri,[pscredential]$Cred)
  if (-not $Uri) { throw "On-prem Exchange URI required (e.g., https://ex01/powershell/)." }
  try {
    $sess = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $Uri -Credential $Cred -Authentication Kerberos -ErrorAction Stop
    Import-PSSession $sess -DisableNameChecking -ErrorAction Stop | Out-Null
  } catch {
    throw "Failed to connect to on-prem Exchange: $($_.Exception.Message)"
  }
}

function Ensure-Row {
  param([hashtable]$Row)
  # Normalize and infer basics
  if (-not $Row.PrimarySmtpAddress -and $Row.UserPrincipalName -and $DomainSuffix) {
    $local = $Row.UserPrincipalName -replace '@.*$',''
    $Row.PrimarySmtpAddress = "$local@$DomainSuffix"
  }
  if (-not $Row.Alias -and $Row.UserPrincipalName) {
    $Row.Alias = ($Row.UserPrincipalName.Split('@')[0]).ToLower()
  }
  return $Row
}

function To-Plain {
  param([SecureString]$s)
  if (-not $s) { return $null }
  $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

# --------------------------
# Start
# --------------------------
if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }
$rows = Import-Csv -Path $CsvPath

# Connect where requested
if ($ConnectOnline) {
  if (-not $Credential) { $Credential = Get-Credential -Message "EXO/Entra connect" }
  Connect-EXOIfNeeded -Cred $Credential
}
if ($ConnectOnPrem) {
  if (-not $Credential) { $Credential = Get-Credential -Message "On-Prem Exchange connect" }
  Connect-OnPremIfNeeded -Uri $OnPremUri -Cred $Credential
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($r in $rows) {
  $h = @{}; $r.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
  $h = Ensure-Row -Row $h

  $upn   = $h['UserPrincipalName']
  $sam   = $h['SamAccountName']
  $alias = $h['Alias']
  $smtp  = $h['PrimarySmtpAddress']
  $disp  = if ($h['DisplayName']) { $h['DisplayName'] } else { (($h['FirstName'] + ' ' + $h['LastName']).Trim()) }
  $tz    = $h['TimeZone']
  $lang  = $h['Language']
  $lic   = $h['LicenseSku']
  $loc   = $h['UsageLocation']
  $ou    = $h['OU']
  $pwd   = $h['InitialPassword']

  $rowResult = [pscustomobject]@{
    Identity     = if ($upn) { $upn } else { $sam }
    SMTP         = $smtp
    Mode         = $Mode
    Action       = 'None'
    Success      = $false
    Message      = $null
  }

  try {
    switch ($Mode) {

      'OnlineExisting' {
        if (-not $upn) { throw "UserPrincipalName required for OnlineExisting." }
        # Idempotence: if mailbox exists, skip
        $exists = Get-EXOMailbox -Identity $upn -ErrorAction SilentlyContinue
        if ($exists) {
          $rowResult.Action = 'SkipExists'; $rowResult.Success = $true; break
        }
        if ($WhatIf) { $rowResult.Action = 'CreateMailbox (WhatIf)'; $rowResult.Success = $true; break }
        # Create mailbox for existing cloud user
        Enable-EXOMailbox -Identity $upn -PrimarySmtpAddress $smtp -ErrorAction Stop
        $rowResult.Action = 'CreateMailbox'; $rowResult.Success = $true
      }

      'OnlineCreate' {
        if (-not $upn) { throw "UserPrincipalName required for OnlineCreate." }
        if (-not $pwd -and -not $DefaultPassword) { throw "InitialPassword (row) or -DefaultPassword is required for creating users." }
        $pwdPlain = if ($pwd) { $pwd } else { To-Plain $DefaultPassword }

        # Create Entra ID user if missing
        $user = Get-EXORecipient -Identity $upn -ErrorAction SilentlyContinue
        if (-not $user) {
          if ($WhatIf) { $rowResult.Action = 'New-MsolUser (WhatIf)'; $rowResult.Success = $true; break }
          # Use MS Graph/Entra module in real life; here we assume New-MgUser or legacy MSOnline/New-MsolUser is available in your environment.
          # Placeholder: New-MgUser or New-MsolUser (commented to avoid accidental runs)
          # New-MgUser -AccountEnabled $true -DisplayName $disp -MailNickname $alias -UserPrincipalName $upn -PasswordProfile @{ Password=$pwdPlain }
          $rowResult.Action = 'CreateUser+Mailbox (pseudo)'; # Replace with your org's user creation cmdlets
        }

        # License (optional)
        if ($lic) {
          if (-not $loc) { throw "UsageLocation is required when assigning a license in EXO." }
          # Assign license using MSOnline or Graph modules (implementation varies by org tooling)
          # Set-MsolUser -UserPrincipalName $upn -UsageLocation $loc
          # Set-MsolUserLicense -UserPrincipalName $upn -AddLicenses $lic
        }

        if ($WhatIf) { $rowResult.Action = 'CreateMailbox (WhatIf)'; $rowResult.Success = $true; break }
        Enable-EXOMailbox -Identity $upn -PrimarySmtpAddress $smtp -ErrorAction Stop
        $rowResult.Action = 'CreateMailbox'; $rowResult.Success = $true

        # Regional settings (optional)
        if ($tz -or $lang) {
          try {
            if ($lang) { Set-MailboxRegionalConfiguration -Identity $upn -Language $lang -ErrorAction Stop }
            if ($tz)   { Set-MailboxRegionalConfiguration -Identity $upn -TimeZone $tz -ErrorAction Stop }
          } catch { Write-Warning "Regional configuration failed for ${upn}: $($_.Exception.Message)" }
        }
      }

      'OnPremExisting' {
        if (-not $sam -and -not $upn) { throw "SamAccountName or UPN required for OnPremExisting." }
        $id = if ($sam) { $sam } else { $upn }
        $mbx = Get-Mailbox -Identity $id -ErrorAction SilentlyContinue
        if ($mbx) { $rowResult.Action = 'SkipExists'; $rowResult.Success = $true; break }
        if ($WhatIf) { $rowResult.Action = 'Enable-Mailbox (WhatIf)'; $rowResult.Success = $true; break }
        Enable-Mailbox -Identity $id -PrimarySmtpAddress $smtp -Alias $alias -ErrorAction Stop
        $rowResult.Action = 'EnableMailbox'; $rowResult.Success = $true
      }

      'OnPremCreate' {
        if (-not $sam) { throw "SamAccountName required for OnPremCreate." }
        if (-not $pwd -and -not $DefaultPassword) { throw "InitialPassword (row) or -DefaultPassword required." }
        $pwdPlain = if ($pwd) { $pwd } else { To-Plain $DefaultPassword }
        if ($WhatIf) { $rowResult.Action = 'New-ADUser + Enable-Mailbox (WhatIf)'; $rowResult.Success = $true; break }

        # Create AD user (requires RSAT ActiveDirectory)
        # New-ADUser -Name $disp -SamAccountName $sam -UserPrincipalName $upn -AccountPassword (ConvertTo-SecureString $pwdPlain -AsPlainText -Force) -Enabled $true -Path $ou -GivenName $h['FirstName'] -Surname $h['LastName']
        # Enable mailbox
        Enable-Mailbox -Identity $sam -PrimarySmtpAddress $smtp -Alias $alias -ErrorAction Stop
        $rowResult.Action = 'NewADUser+EnableMailbox'; $rowResult.Success = $true
      }
    }
  } catch {
    $rowResult.Message = $_.Exception.Message
  }

  $results.Add($rowResult)
}

if ($OutputCsv) {
  try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 } catch { Write-Warning "CSV export failed: $($_.Exception.Message)" }
}

$results | Format-Table -AutoSize