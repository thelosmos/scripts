#!/usr/bin/env python

import paramiko
import time
import getpass
import re
import csv
from itertools import izip
import socket
import requests


def disable_paging(remote_conn):
    '''Disable paging on a Cisco router'''

    remote_conn.send("terminal length 0\n")
    time.sleep(1)

    # Clear the buffer on the screen
    output = remote_conn.recv(1000)

    return output


def getHost(ip):
    """
    This method returns the 'True Host' name for a
    given IP address
    """
    try:
        data = socket.gethostbyaddr(ip)
        time.sleep(2)
        host = repr(data[0])
        return (host)
    except Exception:
        # fail gracefully
        return "None"


def getMac(mac):
    macvendor = requests.get('http://api.macvendors.com/' + mac).text
    return macvendor


if __name__ == '__main__':
    # LOGIN PROMPT
    print ''
    print '#########################################################'
    print '### This script will log into a layer 3 Cisco switch, ###'
    print '##### lookup IPs from a list of MAC addresses, and ######'
    print '##### resolve hostnames via system configured DNS. ######'
    print '###### The script will also lookup the NIC vendor. ######'
    print '##### A csv will be generated in the local directory.####'
    print '#########################################################'
    print ''
    ip = raw_input("Layer 3 Device IP:")
    username = raw_input("Username:")
    password = getpass.getpass()

    # LIST FILE OF MAC ADDRESSES
    f = open('list.txt', 'r')

    # CREATE LIST AND CLOSE FILE
    macs = f.readlines()
    macs = [x.strip() for x in macs]
    macs = [x.strip(r'\s|\'') for x in macs]
    f.close()

    # Create instance of SSHClient object
    remote_conn_pre = paramiko.SSHClient()

    # Automatically add untrusted hosts (make sure okay for security policy in your environment)
    remote_conn_pre.set_missing_host_key_policy(
        paramiko.AutoAddPolicy())

    # initiate SSH connection
    remote_conn_pre.connect(
        ip, username=username, password=password, look_for_keys=False, allow_agent=False)
    remote_conn = remote_conn_pre.invoke_shell()
    print "Interactive SSH Connection Established to %s" % ip

    # SHOW CURRENT PROMPT
    output = remote_conn.recv(1000)
    print output

    # CREATE LISTS FOR IPS AND HOSTNAMES
    deviceiplist = list()
    hostnamelist = list()
    macvendorlist = list()

    # ARP AND DNS LOOKUP
    for x in macs:
        if re.match(r'([a-f0-9]{4}\.[a-f0-9]{4}\.[a-f0-9]{4})', x):
            remote_conn.send("show ip arp " + x)
            remote_conn.send("\n")
            time.sleep(2)
            output = remote_conn.recv(5000)
            deviceip = re.search(
                r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', output)
            if deviceip:
                deviceip = deviceip.group()
                host = getHost(deviceip)
            else:
                deviceip = 'None'
                host = 'None'
            macvendor = getMac(x)
            deviceiplist.append(deviceip)
            hostnamelist.append(host)
            macvendorlist.append(macvendor)

            # SHOW RESULTS/PROGRESS
            print str(x)+" "+str(deviceip)+" "+str(host)+" "+str(macvendor)

        # WRITE RESULTS TO CSV
        with open('results.csv', 'wb') as r:
            writer = csv.writer(r)
            writer.writerow(["MAC Address", "Device IP", "Hostname", "Vendor"])
            writer.writerows(
                izip(macs, deviceiplist, hostnamelist, macvendorlist))
    r.close()
