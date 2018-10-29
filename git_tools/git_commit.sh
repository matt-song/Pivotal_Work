#!/bin/bash

DATE_NOW=`date +%F`
FOLDER="/Users/xsong/git_repository/pv_work"
cd $FOLDER

git add *
git commit -m "Updated at $DATE_NOW"
git push -u origin master
