#!/bin/bash
# Note: the BASH on MAC does not support hash in declare... shit

#source_dir='/Users/xsong/Pivotal_Work/'
conf='
aio2|/Users/xsong/Pivotal_Work/|~/git_repository/|gpadmin
aio1|/Users/xsong/Pivotal_Work/|~/git_repository/|gpadmin
mdw|/Users/xsong/Pivotal_Work/|~/git_repository/|gpadmin
smdw|/Users/xsong/Pivotal_Work/|/data/matt/Pivotal_Work/|gpadmin
gfw|/Users/xsong/MiRoute_RemoteDownload/server/|/opt/web/remoteDownload/|root
'

for line in `echo $conf | grep -v "^$"`
do
    host=`echo $line | awk -F'|' '{print $1}'`
    source_dir=`echo $line | awk -F'|' '{print $2}'`
    target_dir=`echo $line | awk -F'|' '{print $3}'`
    user=`echo $line | awk -F'|' '{print $4}'`
    
    echo "Sync data from [$source_dir] to host [$host], target folder [$target_dir]..."
    
    ### make sure the host is alive
    ping_result=`ping -c1 -W3  $host 2>/dev/null | grep "packets received" 2>/dev/null | awk '{print $4}'`
    if [ "x$ping_result" == 'x1' ]
    then
        rsync -av --delete --exclude=".git*" $source_dir $user@${host}:$target_dir
    else
        echo "[ERROR] Host [$host] is down, skip..."
    fi
done
