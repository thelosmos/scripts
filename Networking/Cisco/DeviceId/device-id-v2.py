#!/usr/bin/env python

import paramiko
import time
import getpass
import re
import csv
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
        return host
    except Exception:
        # fail gracefully
        return "None"

def getMac(mac):
    macvendor = requests.get('https://api.macvendors.com/' + str(mac)).text
    return macvendor

if __name__ == '__main__':
    #LOGIN PROMPT
    print ''
    print '#########################################################'
    print '### This script will log into a layer 3 Cisco switch, ###'
    print '##### retrieve its ARP table, parse for IPs and MACs, ###' 
    print '##### and resolve hostnames via system configured DNS. ##'
    print '###### The script will also lookup the NIC vendor. ######'
    print '##### A csv will be generated in the local directory. ###'
    print '#########################################################'
    print ''
    ip = raw_input("Layer 3 Device IP:")
    username = raw_input("Username:")
    password = getpass.getpass()

     # Create instance of SSHClient object
    remote_conn_pre = paramiko.SSHClient()

    # Automatically add untrusted hosts (make sure okay for security policy in your environment)
    remote_conn_pre.set_missing_host_key_policy(
         paramiko.AutoAddPolicy())

    # initiate SSH connection
    remote_conn_pre.connect(ip, username=username, password=password, look_for_keys=False, allow_agent=False)
    remote_conn = remote_conn_pre.invoke_shell()
    print "Interactive SSH Connection Established to %s" % ip

    #SHOW CURRENT PROMPT
    output = remote_conn.recv(10000)
    print output

    #CREATE LISTS FOR IPS AND HOSTNAMES
    devicemaclist = list()
    deviceiplist = list()
    hostnamelist = list()
    macvendorlist = list()
    
    #disable paging
    disable_paging(remote_conn)
    
    #GET ARP TABLE
    remote_conn.send("show ip arp")
    remote_conn.send("\n")
    time.sleep(2)
    output = remote_conn.recv(1000000)
    f = open('arp.txt','w')
    f.write(output)
    f.close()
    remote_conn.close()
    print 'Disconnecting From Layer 3 Device'
    print '***Vendor lookup speed will be limited as not to exceed macvendor.com API call limits.***'

    #Create csv file
    with open(ip+'-results.csv', 'wb') as r:
      writer = csv.writer(r)
      writer.writerow(["MAC Address", "Device IP", "Hostname", "Vendor"])
      r.close()
    
    #Parse arp.txt file
    arptxt = open('arp.txt', 'r')
    for x in arptxt:
        deviceip = re.search(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', x)
        if deviceip:
          deviceip = deviceip.group()
          host = getHost(deviceip)
        else:
          host = "None"
        deviceiplist.append(deviceip)
        hostnamelist.append(host)
        devicemac = re.search(r'([a-f0-9]{4}\.[a-f0-9]{4}\.[a-f0-9]{4})', x)
        if devicemac:
          devicemac = devicemac.group()
          macvendor = getMac(devicemac)
        else:
          macvendor = "None"
        devicemaclist.append(devicemac)
        macvendorlist.append(macvendor)

        time.sleep(1)

        #Append values to csv file
        with open(ip+'-results.csv', 'a') as r:
            writer = csv.writer(r)
            writer.writerow([devicemac,deviceip,host,macvendor])
        
        print str(deviceip)+" "+str(host)+" "+str(devicemac)+" "+str(macvendor)
    r.close()
