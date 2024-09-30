# Path to the text file containing the list of logon names (UPNs)
$logonListPath = ".\usernames.txt"

# Specify the domain controller to connect to
$domainController = "domaincontroller.domain.com"

# Import the Active Directory module
Import-Module ActiveDirectory

# Import the logon names from the text file
$logonNames = Get-Content -Path $logonListPath

# Loop through each logon name
foreach ($logonName in $logonNames) {
    
    # Import the Active Directory module
    Import-Module ActiveDirectory

    # Get the user object from Active Directory using the logon name (UPN)
    $user = Get-ADUser -Server $domainController -Filter {UserPrincipalName -eq $logonName} -Properties DisplayName, PasswordLastSet

    if ($user) {
        # Output the user's display name and the last password set date
        Write-Output "$($user.DisplayName): Last Password Change - $($user.PasswordLastSet)"
    } else {
        Write-Output "User not found: $logonName"
    }
}