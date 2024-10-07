#!/bin/bash
checkPortScript="$HOME/scripts/check_ssr_port.sh"
checkServerScript="$HOME/scripts/monitor_from_nas.sh"
scriptDir="$HOME/git/my_ss_report"
reportDir="$HOME/git/my_ss_report/reports"

echo "Generating report with [$checkPortScript]..."
if [ -f $checkPortScript ]
then 
    bash $checkPortScript > $reportDir/report_ports.txt 2>&1
fi

echo "Generating report with [$checkServerScript]..."
if [ -f $checkServerScript ]
then 
    bash $checkServerScript > $reportDir/report_servers.txt 2>&1
fi

cd $scriptDir
DATE_NOW=`date`
git add *
git commit -m "Updated at $DATE_NOW"
git push