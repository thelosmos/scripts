#!/usr/bin/python3.6
import re
import csv
import socket
#import requests
#import dns.resolver


# Provide path to input file.
logfile = "192.168.86.208-aclog.@20201218T000001.s"

# Provide domain name
domain = ""

# DNS resolver to caching.
#dns.resolver.LRUCache(max_size=100000)

with open('%s-IronParserResults.csv' % logfile, 'w', newline='') as csvfile:
    fieldnames = ["Device IP", "Device Hostname", "Username", "Web Host"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    with open(logfile) as lf:
        for line in lf:
            ip = re.search(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', line)
            if ip:
                ip = ip.group()
                try:
                  host = socket.gethostbyaddr(ip)
                except Exception:
                   host = "DNS Entry Not Available"
            user = re.search(r' domain', line)
            if user:
                user = user.group()
            webhost = re.search(r'(tunnel|http|https)://[^/"]+', line)
            if webhost:
                webhost = webhost.group()
            
            # Check for blank lines before writing to file.
            if ip or user or webhost:
                writer.writerow({"Device IP": ip, "Device Hostname": host, "Username": user, "Web Host": webhost})
