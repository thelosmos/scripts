#!/bin/bash
# This script will split an image in 3 sections vertically. Pipe source files into this script. Split files will be saved in the directory of the original source file.
# Script relies on  Imagemagic and must be installed.

while read fullfilename;

do
dir=$(dirname "$fullfilename");
filename=$(basename "$fullfilename");
fname="${filename%.*}";
ext="${filename##*.}";

echo "Input File: $fullfilename";

convert -crop 33.333333%x100% $fullfilename -scene 1 $dir/$fname-part-%02d.$ext

done
