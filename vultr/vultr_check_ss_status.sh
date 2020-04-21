#!/bin/bash

### ss settings ###
hostIP='ipOfSShost'         ## the IP of host
basePort=80                 ## the port with v2ray-plugin
otherPort1=8001             ## the port without plugin
ssKey='thePassWordOfSS'     ## ss key

logs()
{
    message=$1
    date=`date +"%F %R"`
    echo "${date} ${message}"

}

### start work ###

# Check if the script has already started

script_name=`basename $0`
cur_pid=$$
isRunning=`ps -ef | grep "bash $script_name" | grep -v grep | awk "{if(\\\$2==$cur_pid) {print}}" | wc -l`
logs "Found [$isRunning] process of $script_name" 

if [ $isRunning -gt 1 ]
then
    logs "Already running, exit!"
    exit 1
fi

### define the list to check ###
SS_basePort_count=`ps -ef | grep ss-server | grep shadowsocksi_${basePort}.pid | wc -l`
SS_otherPort1_count=`ps -ef | grep ss-server | grep shadowsocks_${otherPort1}.pid | wc -l`

### check port 80 ###
logs "Checking port $basePort SS status.."
logs "The process count for port $basePort is [ $SS_basePort_count ]"

if [ "x$SS_basePort_count" != 'x1' ]
then
    logs "SS on port $basePort has down, restart it!"
    /opt/shadowsocks-libev/bin/ss-server -s $hostIP -p $basePort -k $ssKey -m aes-128-cfb --plugin /opt/v2ray-plugin/v2ray-plugin --plugin-opts server -f /tmp/.shadowsocksi_${basePort}.pid
    
    SS_basePort_count_new=`ps -ef | grep ss-server | grep shadowsocksi_${basePort}.pid | wc -l`
    if [ "x$SS_basePort_count_new" != 'x1' ]
    then
        logs "Failed to start the SS on prot $basePort, please check"
    else
        logs "SS on port $basePort has started successfully"
    fi
else
    logs "SS on port $basePort is running fine"
fi

### check port without plugin ###
logs "Checking port $otherPort1 SS status.."
logs "The process count for port $otherPort1 is [ $SS_otherPort1_count ]"

if [ "x$SS_otherPort1_count" != 'x1' ]
then
    logs "SS on port $otherPort1 has down, restart it!"
    /opt/shadowsocks-libev/bin/ss-server -s $hostIP -p $otherPort1 -k $ssKey -m aes-128-cfb -f /tmp/.shadowsocks_$otherPort1.pid

    SS_otherPort1_count_new=`ps -ef | grep ss-server | grep shadowsocks_$otherPort1.pid | wc -l`
    if [ "x$SS_otherPort1_count_new" != 'x1' ]
    then
        logs "Failed to start the SS on prot $otherPort1, please check"
    else
        logs "SS on port $otherPort1 has started successfully"
    fi
else
    logs "SS on port $otherPort1 is running fine"
fi
