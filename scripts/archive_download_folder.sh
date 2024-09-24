#!/bin/bash
backup_folder="$HOME/Downloads/archive_`date +%F`"
mkdir -pv $backup_folder

mv $HOME/Downloads/* $backup_folder
mv $backup_folder/box $HOME/Downloads/
# tar -zcvf ${backup_folder}.tar.gz $backup_folder
# rm -rf $backup_folder
# mv $backup_folder /Users/xsong/Downloads/box/Download_Archive/
