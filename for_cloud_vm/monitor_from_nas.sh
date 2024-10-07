#!/bin/bash
: ' 
Note: this script will monitor the performance and abnormal logs, send the report to target user. it will run from a monitoring host

== Crontab example ===
### health check
*/15 * * * * /bin/bash $HOME/scripts/monitor.sh > /dev/null 2>&1
### send daily report
00 13 * * * [ -f /tmp/.monitor_report.log ] && cat /tmp/.monitor_report.log | mail -s "Health check report for [`hostname`] at [`date`]" 'xxxxx@xxxx.com' > /dev/null 2>&1
'
serverList='x.x.x.x x.x.x.x'
mailList='xxxx@xxx.xx'
tmpReportFile="/tmp/.monitor_report.log"
needSendMail=0
sshPort=xxx
sshUser=root
ssrPortList='xxx xxx xxx'

for host in $serverList; 
do
    hostname=`ssh -o ConnectTimeout=5 -p $sshPort $sshUser@$host "hostname"`
    if [ "x$hostname" == 'x' ] 
    then 
        echo "Host [$host] is not reachable, skip!" | tee -a $tmpReportFile && continue
    fi
    echo "==== Checking server [$hostname] at [`date`] ====" | tee -a $tmpReportFile
    
    ### SSR Port ###
    echo -e "\n> Checking SSR ports on [$hostname]: \n" | tee -a $tmpReportFile
    for port in $ssrPortList
    do
        echo -en "  Testing on [$port]: \t" | tee -a $tmpReportFile
        nc -zv -w 5 $host $port > /dev/null 2>&1
        if [ "x$?" == "x0" ]
        then
            echo "[GOOD]" | tee -a $tmpReportFile
        else
            echo "[FAIL]" | tee -a $tmpReportFile
        fi 
    done

    ### load ###
    echo -e "\n> checking the load:" | tee -a $tmpReportFile
    cpuCount=`ssh -p $sshPort $sshUser@$host "cat /proc/cpuinfo | grep processor | wc -l"`
    loadLast1M=`ssh -p $sshPort $sshUser@$host "uptime | awk -F'load average:' '{print \\\$2}' | sed 's/,//g' | awk '{print \\\$1}'"`
    loadLast1mInt=`echo $loadLast1M | sed 's/\..*//g'`
    if [ $loadLast1mInt -ge $cpuCount ]
    then
        needSendMail=1
        echo -e "\n  The load on [$hostname] is [$loadLast1M], higer than CPU count [$cpuCount], output of the # uptime: " | tee -a $tmpReportFile
        ssh -p $sshPort $sshUser@$host "uptime"
    else
        echo -e "\n  Load on [$hostname] is good, last 1 min's load is: [$loadLast1M]" | tee -a $tmpReportFile
    fi 

    ### CPU ###
    limit=90; isAbnormal=0
    echo -e "\n> Checking the CPU usage:" | tee -a $tmpReportFile
    IFS=$'\n'
    for cpu_load in `ssh -p $sshPort $sshUser@$host "top -b -n 1 | grep '^ ' | sort -k 9 -nr | grep -v '^\s*PID ' | head -10"`
    do
        loadInt=`echo $cpu_load | awk '{print $9}' | sed 's/\..*//g'`
        [ $loadInt -ge $limit ] && isAbnormal=1        
    done
    unset IFS
    if [ "x$isAbnormal" = 'x1' ]
    then
        echo -e "\n  Some process has high cpu usage, please review and check further, details: \n" | tee -a $tmpReportFile
        needSendMail=1
    else
        echo -e "\n  All processes looks good, details: \n" | tee -a $tmpReportFile
    fi
    ssh -p $sshPort $sshUser@$host "top -b -n 1 | grep '^ ' | sort -k 9 -nr | head -10| grep -v '^\s*PID ' " | tee -a $tmpReportFile

    echo "" | tee -a $tmpReportFile
done

#if [ "x$needSendMail" == 'x1' ]
#then
#    # echo "Sending mail to [$mailList]..."
#    cat $tmpReportFile | mail -s "[Alert] Health check detect issue at [`date`]" $mailList
#fi