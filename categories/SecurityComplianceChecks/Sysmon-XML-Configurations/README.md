# Sysmon-XML-Configurations

This is a repository for sysmon .xml configuration files with a range of different events and filters to provide a comprehensive view of system activity and aid cyber security professionals in gaining the insight that they need on their networks and systems

These configurations are to be called during sysmon installation by using the following command:

```cmd
sysmon -accepteula -i c:\windows\config.xml
```

## Configuration Files

### Initial-XML-Configuration.xml
Basic Sysmon configuration file that enables core monitoring events including process creation, network connections, file creation/modification, and registry changes. This is a good starting point for general system monitoring.

### INF-file_deletion.xml
Focused configuration for monitoring file deletion events. Useful for detecting potential data destruction or cleanup activities by malware or unauthorized users.

### INF-service_creation.xml
Configuration that monitors Windows service creation and modification events. Critical for detecting persistence mechanisms and service-based attacks.

### INF-system_shutdown.xml
Monitors system shutdown and restart events. Helpful for tracking system availability and detecting forced shutdowns that might indicate system compromise.

### SEC-process_injection.xml
Advanced configuration for detecting process injection techniques commonly used by malware and advanced persistent threats (APTs). Monitors CreateRemoteThread, SetThreadContext, and other injection methods.

### SEC-sensitive_file_access.xml
Configuration focused on monitoring access to sensitive files and directories such as system files, password databases, and configuration files.

### SEC-sensitive_registry_access.xml
Monitors access to security-critical registry keys including those related to Windows security settings, user accounts, and system configuration.

## Usage Instructions

1. **Choose the appropriate configuration** based on your monitoring requirements
2. **Copy the XML file** to your target system
3. **Install Sysmon** with the configuration:
   ```cmd
   sysmon -accepteula -i path\to\config.xml
   ```
4. **Update existing installation** with new configuration:
   ```cmd
   sysmon -c path\to\config.xml
   ```

## Configuration Categories

### Information Gathering (INF)
- File deletion monitoring
- Service creation tracking  
- System shutdown events

### Security Monitoring (SEC)
- Process injection detection
- Sensitive file access
- Registry security monitoring

## Best Practices

- **Start with Initial-XML-Configuration.xml** for baseline monitoring
- **Combine multiple configurations** based on your security requirements
- **Test configurations** in non-production environments first
- **Monitor log volume** and adjust filtering as needed
- **Regularly update** configurations to address new threats

## Integration with SIEM

These configurations are designed to work with popular SIEM solutions:
- **Splunk**: Use Splunk Universal Forwarder to collect Windows Event Logs
- **ELK Stack**: Configure Winlogbeat to forward Sysmon events
- **Microsoft Sentinel**: Use Azure Monitor Agent or Log Analytics Agent

## Performance Considerations

- **High-volume environments**: Use more restrictive filtering
- **Storage requirements**: Plan for increased log storage needs
- **Network impact**: Consider bandwidth when forwarding logs to SIEM
- **System performance**: Monitor CPU and disk I/O impact