#!/bin/bash
 
### change the path of below accordingly
hostfile="/home/gpadmin/all_hosts.txt"
gpdb_path="/opt/greenplum-db/greenplum_path.sh"
 
today=`date +%F`
date=`date +%F_%H_%M_%S`
workFolder="/home/gpadmin/gpAdminLogs/memory_monitor/${today}"
log_file="${workFolder}/memory_monitor_${date}.log"

## create the work folder ##
mkdir -pv $workFolder
 

echo "====== Start monitor at `date` =======" >> $log_file
source $gpdb_path
gpssh -f $hostfile "ps auxwww"  >> $log_file
echo ""  >> $log_file