#!/bin/vbash

#Define Google DNS Address
IP='8.8.8.8'

#Ping Google DNS and empty results into /dev/null file (unix dumping ground)
ping -c5 $IP &> /dev/null

# '$?' is the return value from the ping above. '0' is success, '1' is failure. 
#This statement will take down the VPN tunnel and re-establish if the return valu
#e was anything but zero.

if [ $? -ne 0 ]; then
	configure
	set interfaces openvpn vtun66 disable
	commit
	delete interfaces openvpn vtun66 disable
	commit
	save
	exit

fi
