$OUs = 
"",
""
$File = ""


$ADReport =
foreach($OU in $OUs){
    Get-ADComputer -Filter * -searchbase $OU  -Properties Name, DNSHostName, DistinguishedName
}

$ADReport |
select-object Name, DNSHostName, DistinguishedName |
export-csv $File -NoTypeInformation