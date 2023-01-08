#!/usr/bin/python3.6
import re
import csv
import socket

# Provide path to input file.
logfile = "aclog.@20210304T000000.c"

# Provide domain name
domain = ""


with open('%s-IronParserResults.csv' % logfile, 'w', newline='') as csvfile:
    fieldnames = ["Device IP", "Username", "Web Host"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    with open(logfile, 'r', encoding='utf8') as lf:
        for line in lf:
            ip = re.search(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', line)
            if ip:
              ip = ip.group()
            user = re.search(r'domain', line)
            if user:
                user = user.group()
            webhost = re.search(r'(tunnel|http|https)://[^/"]+', line)
            if webhost:
                webhost = webhost.group()
            
            # Check for blank lines before writing to file.
            if ip or user or webhost:
                writer.writerow({"Device IP": ip, "Username": user, "Web Host": webhost})
