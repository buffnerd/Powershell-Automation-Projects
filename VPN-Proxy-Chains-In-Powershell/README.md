```
██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
-------Script by Aaron Voborny---https://github.com/buffnerd--------
VPN and Proxy Chain Automation for Enhanced Network Security
```

# 🌐 VPN Proxy Chains in PowerShell

Network infrastructure automation for creating and managing VPN proxy chains to enhance security and anonymity.

## 🎯 Project Overview

This PowerShell project automates the setup and management of VPN proxy chains, allowing for multiple layers of network routing to enhance privacy and security in network communications.

## 📁 Project Files

- **`Create-And-Activate.ps1`** - Sets up VPN connection and proxy chain configuration
- **`Deactivate.ps1`** - Safely disconnects and cleans up proxy chain settings

## 🔧 Features

### **VPN Proxy Chain Setup**
- Configures multiple proxy servers in a chain configuration
- Sets up VPN connection as the primary proxy
- Automatically configures Windows internet settings
- Establishes secure connection routing

### **Network Configuration**
- Creates network interfaces for VPN connections
- Configures proxy server settings in Windows registry
- Manages proxy override lists for specific servers
- Enables/disables proxy chains as needed

### **Connection Management**
- Establishes VPN connections using RAS dial
- Monitors network configuration status
- Provides connection verification
- Safe disconnection and cleanup procedures

## 🚀 Usage

### **Activate VPN Proxy Chain**
```powershell
# Run the setup script
.\Create-And-Activate.ps1

# This will:
# 1. Configure proxy server variables
# 2. Create VPN network interface
# 3. Set up proxy chain in Windows settings
# 4. Enable proxy functionality
# 5. Connect to VPN
# 6. Verify connection status
```

### **Deactivate VPN Proxy Chain**
```powershell
# Run the deactivation script
.\Deactivate.ps1

# This will:
# 1. Disconnect from VPN connection
# 2. Disable proxy chain functionality
# 3. Clear proxy server settings
# 4. Reset proxy override configurations
```

## ⚙️ Configuration

### **Proxy Server Variables**
```powershell
$proxy1 = "proxy1.example.com"    # First proxy server
$proxy2 = "proxy2.example.com"    # Second proxy server  
$proxy3 = "proxy3.example.com"    # Third proxy server
$vpn = "vpn.example.com"          # VPN endpoint
```

### **Registry Settings Modified**
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings`
  - `ProxyServer` - VPN endpoint configuration
  - `ProxyOverride` - Proxy server chain list
  - `ProxyEnable` - Enable/disable proxy functionality

## 🔒 Security Considerations

### **Network Security**
- **Multi-layer routing** provides enhanced anonymity
- **VPN encryption** secures initial connection
- **Proxy chaining** obscures traffic patterns
- **Registry isolation** maintains user-specific settings

### **Operational Security**
- Scripts modify only user-specific registry keys
- VPN credentials should be securely managed
- Proxy server configurations should be validated
- Connection status should be monitored

## 📋 Prerequisites

- **Windows Operating System** with PowerShell
- **Remote Access Services (RAS)** PowerShell module
- **Administrator privileges** for network configuration
- **Valid VPN credentials** and proxy server access
- **Network connectivity** to proxy servers and VPN endpoint

## 🛠️ Installation & Setup

1. **Install RAS Module** (if not present):
   ```powershell
   Install-Module -Name RemoteAccess
   ```

2. **Configure Proxy Servers**: Update script variables with your actual proxy server addresses

3. **Set VPN Credentials**: Configure VPN connection details in Windows

4. **Test Connectivity**: Verify access to proxy servers and VPN endpoint

## 🔍 Troubleshooting

### **Common Issues**
- **Connection Failures**: Verify proxy server addresses and VPN credentials
- **Registry Access**: Ensure script runs with appropriate user privileges
- **Network Conflicts**: Check for existing proxy configurations
- **Module Dependencies**: Confirm RAS PowerShell module is installed

### **Verification Steps**
```powershell
# Check current proxy settings
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Verify network configuration
Get-NetIPConfiguration

# Test VPN connection status
Get-VpnConnection
```

## ⚠️ Important Notes

- **Testing Required**: Always test in non-production environment first
- **Backup Settings**: Save original proxy configurations before modification
- **Security Review**: Ensure proxy servers are trusted and secure
- **Compliance**: Verify usage complies with organizational policies

## 🎛️ Customization Options

- **Additional Proxies**: Extend chain with more proxy servers
- **Load Balancing**: Implement proxy rotation logic
- **Monitoring**: Add connection health checks
- **Logging**: Include detailed operation logging
- **Error Handling**: Enhanced exception management

This project provides a foundation for implementing advanced network routing strategies using PowerShell automation while maintaining security and operational efficiency.