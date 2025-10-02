# Step 1: Connect to the Domain Controller
# Before we can start querying the domain controller for failed login events, we need to establish a connection to the domain controller.

# To do this, we will use the Get-ADDomainController cmdlet from the ActiveDirectory module. This cmdlet returns a list of domain 
# controllers in the domain and allows us to specify which domain controller we want to connect to.

$domainController = Get-ADDomainController -Discover