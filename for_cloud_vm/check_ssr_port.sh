#!/bin/bash
serverList='x.x.x.x x.x.x.x'
sshPort=xxx
sshUser=root
scriptFile='/root/scripts/vultr_check_ss_status.sh'

for host in $serverList; 
do
    hostname=`ssh -o ConnectTimeout=5 -p $sshPort $sshUser@$host "hostname"`
    if [ "x$hostname" == 'x' ] 
    then 
        echo "Host [$host] is not reachable, skip!" && continue
    fi
    # echo "==== Checking server [$hostname] at [`date`] ===="
    
    ### SSR Port ###
    echo -e "\n> Checking SSR ports on [$hostname] with IP [$host]: \n"
    portListV2ray=`ssh -o ConnectTimeout=5 -p $sshPort $sshUser@$host "cat $scriptFile  | grep '^ss_port_v2ray_list' | awk -F\"'\" '{print \\\$2}'" `
    portListNormal=`ssh -o ConnectTimeout=5 -p $sshPort $sshUser@$host "cat $scriptFile  | grep '^ss_port_normal' | awk -F\"'\" '{print \\\$2}'" `
    allPort="$portListV2ray $portListNormal"
    for port in $allPort
    do
        echo -en "  Testing on [$port]: \t"
        nc -zv -w 5 $host $port > /dev/null 2>&1
        if [ "x$?" == "x0" ]
        then
            echo "[GOOD]"
        else
            echo "[FAIL]"
        fi 
    done
done

