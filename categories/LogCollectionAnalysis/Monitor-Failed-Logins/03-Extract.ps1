# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------
# Event Data Extraction Script for Failed Login Information

# Step 3: Extract Relevant Information from the Events
# Now that we have a list of failed login events, we can start extracting the relevant information from these events.

# The Get-WinEvent cmdlet returns events as System.Diagnostics.Eventing.Reader.EventLogRecord objects, which contain a lot of information about the event.

# To extract the relevant information, we can use the Select-Object cmdlet to select only the properties that we are interested in. In this case, we are 
# interested in the TimeCreated, UserName, and MachineName properties.

$failedLogins = $failedLogins | Select-Object TimeCreated, UserName, MachineName