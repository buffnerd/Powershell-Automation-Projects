# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------
# Security Event Log Query Script for Failed Login Detection

# Step 2: Query the Security Event Log for Failed Login Events
# Now that we have a connection to the domain controller, we can start querying the security event log for failed login events.

# To do this, we will use the Get-WinEvent cmdlet. This cmdlet allows us to retrieve events from event logs on local and remote machines.

# We will specify the Security event log and use the FilterHashtable parameter to filter for events with an EventID of 4625. This is the
# event ID for failed login events.

$failedLogins = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625} -ComputerName $domainController