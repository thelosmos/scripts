#! /bin/bash

#Define Google DNS Address
IP='8.8.8.8'
VPN=''
#Ping Google DNS and empty results into /dev/null file (unix dumping ground)
ping -c5 $IP &> /dev/null

# '$?' is the return value from the ping above. '0' is success, '1' is failure. This statement will take down the VPN tunnel and re-establish if the return value was anything but zero.
if [ $? -ne 0 ]
then
	nmcli con down id $VPN
	nmcli con up id $VPN

fi
