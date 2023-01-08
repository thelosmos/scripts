//Modify DHCP Scope Option

$scopes = Get-DhcpServerv4Scope

foreach($id in $scopes.ScopeID){
    Set-DhcpServerv4OptionValue -ScopeId $id -OptionId 6 -value 1.1.1.1 , 2.2.2.2 , 3.3.3.3