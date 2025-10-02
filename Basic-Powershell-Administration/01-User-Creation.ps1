# ██████╗░██╗░░░██╗███████╗███████╗  ███╗░░██╗███████╗██████╗░██████╗░
# ██╔══██╗██║░░░██║██╔════╝██╔════╝  ████╗░██║██╔════╝██╔══██╗██╔══██╗
# ██████╦╝██║░░░██║█████╗░░█████╗░░  ██╔██╗██║█████╗░░██████╔╝██║░░██║
# ██╔══██╗██║░░░██║██╔══╝░░██╔══╝░░  ██║╚████║██╔══╝░░██╔══██╗██║░░██║
# ██████╦╝╚██████╔╝██║░░░░░██║░░░░░  ██║░╚███║███████╗██║░░██║██████╔╝
# ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝░░░░░  ╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝╚═════╝░
# -------Script by Aaron Voborny---https://github.com/buffnerd--------
# Active Directory User Creation Automation Script

# Creating a New User in Active Directory
# To create a new user in Active Directory, use the New-ADUser cmdlet.

# Here is the basic syntax:

New-ADUser -Name "John Doe" -GivenName "John" -Surname "Doe" -SamAccountName "jdoe" -UserPrincipalName "jdoe@example.com" -AccountPassword (Read-Host -AsSecureString "Enter password") -Enabled $true

# This will create a new user with the name "John Doe", given name "John", surname "Doe", samAccountName "jdoe", and userPrincipalName "jdoe@example.com". The -AccountPassword parameter allows you to specify a password for the user, and the -Enabled parameter specifies whether the account is enabled or disabled.

# You can also specify other properties for the user, such as the department, office, and description, using the -Department, -Office, and -Description parameters, respectively.