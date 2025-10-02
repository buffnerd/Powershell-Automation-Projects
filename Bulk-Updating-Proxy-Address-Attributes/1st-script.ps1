# Using the 'Get' cmdlet in an elevated PowerShell Prompt, run the following command:

Get-ADUser -Filter * -SearchBase "OU=Knowledge,OU=Users,DC=companydomain,DC=com"
      
# NOTE:  It is important to change the information in quotations to match an OU that exists in your organization's Active Directory Environment.