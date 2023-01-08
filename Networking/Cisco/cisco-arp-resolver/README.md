# Cisco-ARP-Resolver

This script will log into a layer 3 Cisco switch, lookup IPs from a list of MAC addresses provided in a text file named list.txt within the same directory, and resolve hostnames via system configured DNS. The script will also lookup the NIC vendor. A csv will be generated in the local directory with the results.

**You will need to provide a list of MAC address in Cisco's format (xxxx.xxxx.xxxx) and list these in a list.txt file.**
