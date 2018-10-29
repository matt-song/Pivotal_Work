#!/bin/bash

DATE_NOW=`date +%F`
FOLDER="~/git_repository/pv_work"
cd $FOLDER

git fetch origin
git checkout
git pull
