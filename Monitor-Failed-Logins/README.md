# Monitor-Failed-Logins
# Here is a detailed guide on how to monitor failed user logins on a domain using PowerShell.

# Prerequisites
# You will need to have access to a domain controller.
# You will need to have the ActiveDirectory module installed on your machine. You can check if it is already installed by running the following command:

Get-Module -ListAvailable | Where-Object {$_.Name -eq "ActiveDirectory"}

# If the ActiveDirectory module is not installed, you can install it by running the following command:

Install-Module -Name ActiveDirectory