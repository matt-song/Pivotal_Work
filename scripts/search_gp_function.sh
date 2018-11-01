#!/bin/bash 
keyword=$1

psql -P "pager=off" -c "\df *.*" | awk -F"|" '{print $2}' | sort -u | grep -i --color "$keyword"
