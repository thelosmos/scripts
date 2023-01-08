#netsh.exe dhcp server 127.0.0.1 scope $i show optionvalue | select-string -Pattern '(OptionId\s:\s51)((.*\n){5})' -AllMatches | % { $_.Matches } | % { $_.Value };
$dhcpserver='127.0.0.1'

$getscopes=netsh.exe dhcp server $dhcpserver show scope | select-string -Pattern ‘172\.20\.\d{1,3}\.\d{1,3}’ -AllMatches | % { $_.Matches } | % { $_.Value };
$getscopes
foreach ($i in $getscopes) {
    netsh dhcp server $dhcpserver scope $i set optionvalue 51 DWORD 7200
   
}