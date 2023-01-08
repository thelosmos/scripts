#!/usr/bin/env python

import time
import json
import requests
import csv
from itertools import izip
import re


if __name__ == '__main__':


    # LIST FILE OF IP ADDRESSES
    f = open('list2.txt','r')

    #CREATE LIST AND CLOSE FILE
    ips = f.readlines()
    ips = [x.strip() for x in ips]
    f.close()

    iplist = list()
    iplistcidr = list()
    ownerlist = list()
    startaddlist = list()
    cidrlengthlist = list()

    for x in ips:
      iplist.append(x)
      response=requests.get('https://whois.arin.net/rest/ip/'+str(x)+'.json')
      response=response.json()
      owner = response['net']['orgRef']['@name']
      ownerlist.append(owner)
      startadd = response['net']['netBlocks']['netBlock']['startAddress']['$']
      startaddlist.append(startadd)
      cidrlength = response['net']['netBlocks']['netBlock']['cidrLength']['$']
      cidrlengthlist.append(cidrlength)
      print str(x) + " " + str(owner)+" "+ str(startadd)+"/"+str(cidrlength)
    
    # WRITE RESULTS TO CSV
    with open('arin-results.csv', 'wb') as r:
            writer = csv.writer(r)
            writer.writerow(["Network", "Company","Parent Network", "CIDR"])
            writer.writerows(
                izip(
                    iplist,
                    ownerlist,
                    startaddlist,
                    cidrlengthlist))