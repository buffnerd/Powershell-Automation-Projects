# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------
# VPN and Proxy Chain Creation and Activation Script

# VPN-Proxy-Chains-In-Powershell

# This script sets up a VPN connection and three proxy servers, then sets up the VPN connection as the first proxy in the chain and the other two proxies as the second proxy in the chain. It then enables the use of the proxy chain and connects to the VPN. Finally, it confirms that the VPN connection has been established.

# Set up variables for the proxy servers
$proxy1 = "proxy1.example.com"
$proxy2 = "proxy2.example.com"
$proxy3 = "proxy3.example.com"

# Set up a variable for the VPN connection
$vpn = "vpn.example.com"

# Create a new NetSh interface for the VPN connection
New-NetIPAddress -InterfaceAlias "VPN Connection" -IPAddress $vpn -PrefixLength 24

# Set up the VPN connection as the first proxy in the chain
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value "$vpn:8080"

# Set up the second proxy in the chain
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value "$proxy1;$proxy2;$proxy3"

# Enable the use of the proxy chain
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1

# Connect to the VPN
rasdial "VPN Connection"

# Confirm that the VPN connection has been established
Get-NetIPConfiguration

# Creating a VPN proxy chain involves routing your internet connection through multiple servers or "proxies" to add an extra layer of security and anonymity. Here is a sample PowerShell script that you can use to set up a VPN proxy chain:

# Keep in mind that this is just a sample script and may need to be modified to fit your specific needs. Additionally, you may need to install the Remote Access Services (RAS) PowerShell module to use the rasdial command.