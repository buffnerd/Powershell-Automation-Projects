# In your elevated PowerShell Prompt, run a command which pulls the .csv and triggers the proxyAddresses attribute to be updated with the information in the proxyAddresses column in your CSV for users in the selected OU based on their SAM Account Name for the unique identifier. That command will look something like this:

Import-Csv "C:\Users\adminaccount\scripts\bulk-update-proxy-addresses.csv" | ForEach-Object {
	Set-ADUser -Identity $_.samaccountname -Add @{ProxyAddresses = ($_.ProxyAddresses -split ",")}
}
      
# NOTE:  It is important to change the information in quotations to match a file path that exists in your environment.

# Extra information:  The "," just before the final two brackets in the final script tells the domain controller to
# add multiple fields, delimiting them by commas.  This can be useful for attributes such as Proxy Addresses and
# Direct Reports where you may need to make multiple entries.
      
# A FRIENDLY REMINDER:  Always make sure to run scripts like this on small test groups first to verify it functions as
# intended.  Making mistakes on bulk updates can cause uneccessary rework and tie up critical resources.  
# MEASURE TWICE, CUT ONCE!!!!!