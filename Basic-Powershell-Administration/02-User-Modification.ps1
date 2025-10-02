# Modifying an Existing User in Active Directory

# To modify an existing user in Active Directory, use the Set-ADUser cmdlet.

# Here is the basic syntax:

Set-ADUser -Identity "jdoe" -Title "Manager" -Department "IT" -Office "New York" -Description "Systems manager"

# This will modify the user with the samAccountName "jdoe" and set their title to "Manager", department to "IT", office to "New York", and description to "Systems manager".

# You can also modify other properties of the user using the appropriate parameters, such as -GivenName, -Surname, and -EmailAddress.