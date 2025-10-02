# Restore-AD
Powershell Automation Script that checks for an existing OU and if it doesn't exist then it restores it with backup data.  The backup data file needs to be in the same directory as the script.  You may change certain information in this script depending on your needs.  In this script, I have created a Finance OU.  The sample data is fake data.

This PowerShell script automates several tasks related to Active Directory management. Here's a comprehensive explanation of what each part of the script does:

1 - Check for Existence of Organizational Unit (OU): The script uses the Get-ADOrganizationalUnit cmdlet to check for the existence of an OU named "Finance" in the Active Directory. If the OU exists, the script proceeds to deactivate the protection from accidental deletion.

2 - Deactivate Protection from Accidental Deletion (if applicable): If the "Finance" OU exists, the script checks whether it is protected from accidental deletion. If protection is enabled, the script temporarily deactivates it by setting the ProtectedFromAccidentalDeletion property to $false.

3 - Delete Existing OU (if applicable): After deactivating protection, the script attempts to delete the "Finance" OU using the Remove-ADOrganizationalUnit cmdlet. It catches any errors that occur during the deletion process and displays an error message.

4 - Create New OU: If the "Finance" OU does not exist or after deleting the existing one, the script creates a new OU named "Finance" using the New-ADOrganizationalUnit cmdlet.

5 - Import Data into Active Directory: The script imports data from a CSV file named "financePersonnel.csv" into the Active Directory domain. It iterates through each row in the CSV file and creates a new user account for each entry using the New-ADUser cmdlet. The user accounts are created within the "Finance" OU.

6 - Reactivate Protection from Accidental Deletion: After completing the tasks, the script reactivates protection from accidental deletion for the "Finance" OU by setting the ProtectedFromAccidentalDeletion property to $true.

7 - Generate Output File: Finally, the script retrieves user information from the "Finance" OU using the Get-ADUser cmdlet. It filters the results to include all users and retrieves additional properties such as display name, postal code, office phone, and mobile phone. The user information is then exported to a text file named "AdResults.txt" located in the same directory as the PowerShell script.

Overall, this script streamlines the process of managing Active Directory by checking for the existence of an OU, creating or deleting the OU as needed, importing user data from a CSV file, and generating an output file with user information for submission or further analysis. Additionally, it ensures that the OU's protection from accidental deletion is properly managed throughout the process.