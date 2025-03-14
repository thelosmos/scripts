#!/usr/bin/bash

# Pipe URL list to this script and it will output a pdf(s) of the pages in the current directory. This scrip assumes the URL(s) have an htm extension. Please modify as needed.
# Depends on Chromium being installed

while read line; 
    do filename=$(echo $line | grep -iPo [^/]*$ | sed 's/$/.pdf/'); 
        chromium --headless  --print-to-pdf=$filename $line;
done  

