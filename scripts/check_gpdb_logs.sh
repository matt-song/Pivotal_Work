#!/bin/bash

log=$1

[ ! -f $log ] && echo "no such file [$log], exit" && exit 1;

for severity in WARN ERROR FATAL
do 
    echo === $severity ===
#    echo "# cat $log | grep "\\\"$severity\\\"" | awk -F',' '{print \$19}' | sort | uniq -c "
#    cat $log | grep "\"$severity\"" | awk -F',' '{print $19}' | sort | uniq -c
    cat $log | grep "\"$severity\"" | awk -F',"' '{print $8}' | sed 's/,,.*//g' | sort | uniq -c | sort -nr
    echo 
done
