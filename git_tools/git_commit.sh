#!/bin/bash

msg=$1;
[ x"$msg" != x ] && msg+=","
DATE_NOW=`date +%F`

cd ~/Pivotal_Work
git add *
git commit -m "$msg Updated at $DATE_NOW"
git push -u origin master
