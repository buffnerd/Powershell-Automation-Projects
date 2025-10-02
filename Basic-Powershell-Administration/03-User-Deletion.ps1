# Deleting an Existing User in Active Directory
# To delete an existing user in Active Directory, use the Remove-ADUser cmdlet.

# Here is the basic syntax:

Remove-ADUser -Identity "jdoe"

# This will delete the user with the samAccountName "jdoe".

# Note that this will permanently delete the user and their associated information from Active Directory.