# REGISTRY HACK TO TURN OFF TLS 1.1 ON SERVERS AND CLIENTS

# Keep in mind that a GPO will take precedence over registry edits.

# CLIENT KEYS

# Set variables to indicate value and key to set

$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
$Name 	 	  = 'Enabled'
$Value		  = '0'

# Create the key if it does not exist

If (-Not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}

# Now set the value

New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

;

# Now do the same thing for a second key for the client to set the DisabledByDefault setting to true

$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
$Name 	 	  = 'DisabledByDefault'
$Value		  = '1'

If (-Not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}

New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

;

# SERVER KEYS

# Set variables to indicate value and key to set

$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
$Name 	 	  = 'Enabled'
$Value		  = '0'

# Create the key if it does not exist

If (-Not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}

# Now set the value

New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

;

# Now do the same thing for a second key for the server to set the DisabledByDefault setting to true

$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
$Name 	 	  = 'DisabledByDefault'
$Value		  = '1'

If (-Not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}  
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force;

# This script adds four keys to the registry which will disable TLS 1.1 on a Client or Server