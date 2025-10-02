# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------
# VPN and Proxy Chain Deactivation Script

# To activate the VPN proxy chain, you can simply run the previous script. This will set up the VPN connection and the proxy chain, and then connect to the VPN.

# To deactivate the VPN proxy chain, you can use the following script:

# Disconnect from the VPN
rasdial "VPN Connection" /disconnect

# Disable the use of the proxy chain
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0

# Remove the VPN connection from the list of proxies
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -Value ""

# Remove the second proxy from the list of proxies
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride" -Value ""

# This script disconnects from the VPN, disables the use of the proxy chain, removes the VPN connection and the other proxies from the list of proxies, and removes the second proxy from the list of proxies.

# Keep in mind that these scripts assume that you have already set up the VPN connection and the proxy servers as described in the previous script. You may need to modify these scripts to fit your specific needs.