#!/bin/bash

logs()
{
    message=$1
    date=`date +"%F %R"`
    echo "${date} ${message}"

}

### start work ###

# SS server INFO
ss_password='xxxxxxxxxx'
ss_bin='/opt/shadowsocks-libev/bin/ss-server'
ss_port_v2ray='80'
ss_port_normal='8001'
ss_encryption='aes-128-gcm'
ss_plugin='/opt/v2ray-plugin/v2ray-plugin'
ss_pluginOpt='server'
ss_listenAddr=`ip a | grep eth0 | grep inet | awk '{print $2}' | sed 's/\/.*//g'`
ss_pidFile_v2ray="shadowsocks_${ss_port_v2ray}.pid"
ss_pidFile_normal="shadowsocks_${ss_port_normal}.pid"

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
SS_v2ray_count=`ps -ef | grep ss-server | grep $ss_pidFile_v2ray | wc -l`
SS_normal_count=`ps -ef | grep ss-server | grep $ss_pidFile_normal | wc -l`

### check port of v2ray ###
logs "Checking port $ss_port_v2ray SS status.."
logs "The process count for port $ss_port_v2ray is [ $SS_v2ray_count ]"

if [ "x$SS_v2ray_count" != 'x1' ]
then
    logs "SS on port $ss_port_v2ray has down, restart it!"
    $ss_bin -s $ss_listenAddr -p $ss_port_v2ray -k $ss_password -m $ss_encryption --plugin $ss_plugin --plugin-opts $ss_pluginOpt -f /tmp/.${ss_pidFile_v2ray}

    SS_v2ray_count_new=`ps -ef | grep ss-server | grep $ss_pidFile_v2ray | wc -l`
    if [ "x$SS_v2ray_count_new" != 'x1' ]
    then
        logs "Failed to start the SS on prot $ss_port_v2ray, please check"
    else
        logs "SS on port $ss_port_v2ray has started successfully"
    fi
else
    logs "SS on port $ss_port_v2ray is running fine"
fi

### check port of no-plugin ###
logs "Checking port $ss_port_normal SS status.."
logs "The process count for port $ss_port_normal is [ $SS_normal_count ]"

if [ "x$SS_normal_count" != 'x1' ]
then
    logs "SS on port $ss_port_normal has down, restart it!"
    $ss_bin -s $ss_listenAddr -p $ss_port_normal -k $ss_password -m $ss_encryption -f /tmp/.${ss_pidFile_normal}

    SS_normal_count_new=`ps -ef | grep ss-server | grep $ss_pidFile_normal | wc -l`
    if [ "x$SS_normal_count_new" != 'x1' ]
    then
        logs "Failed to start the SS on prot $ss_port_normal, please check"
    else
        logs "SS on port $ss_port_normal has started successfully"
    fi
else
    logs "SS on port $ss_port_normal is running fine"
fi