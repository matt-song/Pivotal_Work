#!/bin/bash
: ' 
Note: this script will monitor the performance and abnormal logs, send the report to target user.
Crontab: 
### health check
*/15 * * * * /bin/bash $HOME/scripts/monitor.sh > /dev/null 2>&1
### send daily report
00 13 * * * [ -f /tmp/.monitor_report.log ] && cat /tmp/.monitor_report.log | mail -s "Health check report for [`hostname`] at [`date`]" 'xiaobo.song@broadcom.com' > /dev/null 2>&1
'
mailList='xxxx@xxx.xx'
tmpReportFile="/tmp/.monitor_report.log"
needSendMail=0

echo -e "
========================================================
System health check report
generated on:\t `date`
hostname:\t `hostname`
========================================================
" | tee $tmpReportFile

check_load()
{
    echo "=== Checking the CPU load for last mintue ===" | tee -a $tmpReportFile
    cpuCount=`cat /proc/cpuinfo | grep processor | wc -l`
    loadLast1M=`uptime | awk -F'load average:' '{print $2}' | sed 's/,//g' | awk '{print $1}'`
    loadLast1mInt=`echo $loadLast1M | sed 's/\..*//g'`
    if [ $loadLast1mInt -ge $cpuCount ]
    then
        needSendMail=1
        echo "The load [$loadLast1M] is pretty high, output of the # uptime: " | tee -a $tmpReportFile
        uptime | tee -a $tmpReportFile
    else
        echo "Load is good, last 1 min's load is: [$loadLast1M]" | tee -a $tmpReportFile
    fi 

    echo -e "\n=== Checking top 10 CPU consumer: ===" | tee -a $tmpReportFile
    top -b -n 1 | grep "^ " | sort -k 9 -nr | grep -v "^    PID" | head -10 | tee -a $tmpReportFile 

    ### check if any process having load greater than xx
    limit=90
    isAbnormal=0
    IFS=$'\n'
    for cpu_load in `top -b -n 1 | grep "^ " | sort -k 9 -nr | grep -v "^    PID" | head -10`
    do
        loadInt=`echo $cpu_load | awk '{print $9}' | sed 's/\..*//g'`
        [ $loadInt -ge $limit ] && isAbnormal=1        
    done
    unset IFS
    if [ "x$isAbnormal" = 'x1' ]
    then
        echo -e "\nSome process has high cpu usage, please review above output and check further" | tee -a $tmpReportFile
        needSendMail=1
    else
        echo -e "\nAll processes looks good" | tee -a $tmpReportFile
    fi
}

audit_log()
{
    today=`date | cut -c 5-10`
    echo -e "\n=== Checking security logs of [$today] ===" | tee -a $tmpReportFile 
    echo -e "\n=> session opened for user list: "  | tee -a $tmpReportFile 
    sudo cat /var/log/secure  | grep "$today" | grep sshd | grep "session opened for user" | awk '{print $11}' | sort | uniq -c | sort -nr  | tee -a $tmpReportFile 
    echo -e "\n=> Connection closed by authenticating user list: "  | tee -a $tmpReportFile  
    sudo cat /var/log/secure  | grep "$today" | grep sshd  | grep 'Connection closed by authenticating user' | awk '{print "user: "$11,"\thost:"$12}' | sort | uniq -c | sort -nr  | tee -a $tmpReportFile 
}

check_network()
{
    echo -e "\n=== Checking network connections" | tee -a $tmpReportFile 
    sudo netstat -antp 2>/dev/null | grep "^tcp" | awk '{print $6}' | sort | uniq -c | sort -nr | tee -a $tmpReportFile 
}

check_load
audit_log
check_network
echo "" | tee -a $tmpReportFile 

if [ "x$needSendMail" == 'x1' ]
then
    echo "Sending mail to [$mailList]..."
    cat $tmpReportFile | mail -s "Health check report for [`hostname`] at [`date`]" $mailList
fi

