# 🔍 Sentinel Lab - Failed RDP Login Monitoring

This PowerShell script monitors failed RDP login attempts and converts source IP addresses to full geolocation data for Azure Sentinel SIEM analysis.

## 🎯 Project Overview

This script creates a comprehensive security monitoring solution that:
- Monitors Windows Security Event Log for failed RDP logins (Event ID 4625)
- Retrieves geolocation data for source IP addresses using external API
- Creates formatted log files compatible with Azure Sentinel
- Provides sample data for Log Analytics workspace training

## 🔧 Prerequisites

- **Windows System** with Event Viewer access
- **Administrator Privileges** to read Security Event Log
- **Internet Connection** for geolocation API calls
- **API Key** from [ipgeolocation.io](https://ipgeolocation.io/)

## 📋 Features

### ⚡ Real-time Monitoring
- Continuous monitoring of Windows Security Event Log
- Automatic detection of failed RDP login attempts
- Duplicate event prevention to avoid log pollution

### 🌍 Geolocation Integration
- Converts IP addresses to geographic coordinates
- Retrieves country, state/province information
- Includes city and region data when available

### 📊 Azure Sentinel Compatible
- Generates logs in format optimized for Azure Sentinel
- Includes sample data for Log Analytics training
- Structured data format for easy parsing

### 🎨 Visual Feedback
- Color-coded console output for easy monitoring
- Real-time display of processed events
- Detailed logging information

## 🚀 Usage

### Setup
1. **Get API Key**: Register at [ipgeolocation.io](https://ipgeolocation.io/) and obtain your API key
2. **Update Script**: Replace the API key in the script with your personal key
3. **Set Permissions**: Ensure script runs with administrator privileges

### Execution
```powershell
# Run the script
.\Sentinel-Lab.ps1

# The script will:
# 1. Create log file at C:\ProgramData\failed_rdp.log
# 2. Generate sample data for training
# 3. Begin monitoring for failed RDP attempts
# 4. Process and log geolocation data for each event
```

## 📁 Output Format

The script generates log entries in the following format:
```
latitude:40.71455,longitude:-74.00714,destinationhost:DESKTOP-PC,username:admin,sourcehost:192.168.1.100,state:New York,country:United States,label:United States - 192.168.1.100,timestamp:2021-10-26 10:44:07
```

### Field Descriptions
- **latitude/longitude**: Geographic coordinates of source IP
- **destinationhost**: Target machine name
- **username**: Attempted login username
- **sourcehost**: Source IP address
- **state**: State/Province of source IP
- **country**: Country of source IP
- **label**: Human-readable location label
- **timestamp**: Event timestamp

## 🔒 Security Considerations

- **API Key Protection**: Keep your geolocation API key secure
- **Rate Limiting**: Script includes delays to prevent API rate limiting
- **Log File Security**: Ensure log file permissions are appropriately restricted
- **Network Security**: Monitor for suspicious patterns in failed login attempts

## 🏗️ Azure Sentinel Integration

### Log Analytics Workspace Setup
1. Create custom log table in Azure Sentinel
2. Use sample data to train field extraction
3. Configure data connector for log file ingestion
4. Create custom queries and alerts

### Sample KQL Queries
```kql
// Show failed logins by country
CustomLog_CL
| where label_s contains "-"
| summarize count() by country_s
| order by count_ desc

// Map failed login attempts
CustomLog_CL
| where destinationhost_s != "samplehost"
| project latitude_d, longitude_d, country_s, sourcehost_s
```

## 🎛️ Customization Options

- **Modify API Provider**: Change geolocation service if needed
- **Adjust Monitoring Interval**: Modify sleep duration for different polling rates
- **Custom Log Format**: Adapt output format for specific SIEM requirements
- **Additional Event IDs**: Extend to monitor other security events

## 🐛 Troubleshooting

### Common Issues
- **API Quota Exceeded**: Check API usage limits and consider upgrading plan
- **Permission Denied**: Ensure script runs with administrator privileges
- **Network Connectivity**: Verify internet connection for API calls
- **Event Log Access**: Confirm Security Event Log is accessible

### Performance Optimization
- Consider batching API requests for high-volume environments
- Implement caching for frequently seen IP addresses
- Add local IP range filtering to reduce API calls

## 📈 Monitoring & Alerting

Set up alerts for:
- High volume of failed login attempts
- Login attempts from suspicious geographic locations
- Repeated attempts from same source IP
- Attempts using common/default usernames

This script provides a foundation for comprehensive RDP security monitoring and can be integrated into broader security operations workflows.