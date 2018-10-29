#!/bin/bash

HOST_FILE="/etc/hosts"

IFS=$'\n'; 

for i in `cat $HOST_FILE | egrep -v "^$|localhost|broadcasthost"`;
do
    if [ "x"`echo $i | grep "^#####"` != "x" ]
    then
        echo -e "\n$i";
    #
    elif [ "x"`echo $i | grep -e "^[0-9]"` != "x" ]
    then
        echo $i | awk '{ printf "%-10s %s\n", $2,$1}'; 
    fi
done; 
echo
unset IFS
