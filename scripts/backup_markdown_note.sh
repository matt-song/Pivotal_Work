#!/bin/bash

today=`date +%F`
home_folder='/Users/xsong/Documents/Work'
archive_folder="${home_folder}/999_Archive"
target_folder_list='01_Cases 02_Jira'
# target_folder_list='01_Cases 02_Jira 03_Others'
backup_target='/Users/xsong/Downloads/box/backup/typora_backup'

### create target backup folder ###
mkdir -pv "${archive_folder}/${today}"

for folder in $target_folder_list
do
    file_count=`ls ${home_folder}/${folder}/ | wc -l | sed 's/ //g'`
    if [ "x$file_count" == 'x0' ]
    then
        echo "empty folder [${home_folder}/${folder}/], skip..."
    else
        mkdir -pv "${archive_folder}/${today}/$folder"
        mv -v ${home_folder}/${folder}/* ${archive_folder}/${today}/${folder}/
    fi
done

## backup all document to ssd
echo "sync the files to archvie location [$backup_target]..."
rsync -av --delete $home_folder $backup_target
