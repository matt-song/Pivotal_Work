#!/bin/bash

DATE_NOW=`date +%F`
cd ~/git_repository/pv_work

git add *
git commit -m "Updated at $DATE_NOW"
git push -u origin master
