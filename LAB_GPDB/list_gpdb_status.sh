#!/bin/bash
# use this script to list existing GPDB status
# I am too lazy to make code simple, no time for that, so will copy/paste duplicate code for 2 scenarios

SegmentList="/home/gpadmin/all_segment_hosts.txt"
GP_HOME="/opt"
GP_DATA_MASTER="/data/master"
#GP_DATA_SEGMENT="/data/segment"
hostname=`hostname`

## color variables
green="\e[1;32m"
red="\e[1;31m"
yellow="\e[1;33m"
normal="\e[0m"

ECHO_SYSTEM()
{
    message=$1
    echo -e "${green}${message}${normal}"
}
ECHO_WARN()
{
    message=$1
    echo -e "${yellow}${message}${normal}"
}
ECHO_ERROR()
{
    message=$1
    echo -e "${red}${message}${normal}"
}
ECHO_DEBUG()
{
    message=$1
    [ "x$DEBUG" == 'x1' ] && echo -e "[DEBUG] $message"
}

print_help()
{
    scriptName=`basename $0`
    ECHO_WARN "Usage:\n 
    $scriptName         list all installed GPDB
    $scriptName -f      list all installed GPDB along with space usage
    $scriptName -D      enable debug mode
    $scriptName -h      print this message"
    exit 1
}
get_port()
{
    gp_ver=$1

    ### get the port and data folder name on segment ###
    port_md5_int=`echo "$gp_ver" | md5sum | awk '{print $1}' | tr a-f A-F `
    gp_port=`echo $port_md5_int % 9999 | bc`

    ### if port < 1000 then add 0 at the end ###
    if [ $gp_port -lt 10 ] 
    then
        gp_port="${gp_port}000"
    elif [ $gp_port -lt 100 ]
    then
        gp_port="${gp_port}00"
    elif [ $gp_port -lt 1000 ]
    then
        gp_port="${gp_port}0"
    fi

    echo "$gp_port"
}

### Start the work ###

### get the parameters ###
while getopts 'Dhf' opt
do
    case $opt 
    in
        D) DEBUG=1              ;;
        f) get_space_usage=1    ;;
        h) print_help           ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
  esac
done

clear; ECHO_SYSTEM "Generating the report of installed GPDB, this might take few minutes...\n"


### Scenario#1, list everything ###
if [ "x$get_space_usage" == 'x1' ]
then
    for build in `ls $GP_HOME | grep "^greenplum_"`
    do
        gp_ver=`echo $build |  sed 's/greenplum_//g'`
        master_data="$GP_DATA_MASTER/master_${gp_ver}"

        ### get the gphome and master data folder's usage ###
        GPHOME_Usage=`du -s $GP_HOME/$build | awk '{print $1}'`
        MASTER_Usage=`du -s $GP_DATA_MASTER/master_${gp_ver} | awk '{print $1}'`
        [ "x$MASTER_Usage" = 'x' ] && MASTER_Usage=0    ## workaround for HW issue
        total_usage=$(($GPHOME_Usage+$MASTER_Usage))

        ECHO_DEBUG "GP version: [$gp_ver], Master folder: [$master_data] and usage: [$MASTER_Usage]; GPHOME: [$GP_HOME/$build]"

        gp_port=`get_port $gp_ver`

        gp_data_id=`echo $gp_port % 2 + 1 | bc`
        gp_seg_data_folder="/data${gp_data_id}/segment/segment_${gp_ver}"

        ### Check if GPDB is running ###
        status="${green}Online${normal}"
        isRunning=''

        gp_majorVer=`echo $gp_ver | cut -d'.' -f 1`
        if [ $gp_majorVer -le 6 ]
        then
            isRunning=`ps -ef | grep postgres | grep master | grep "\-D" | grep "$gp_ver" | grep $gp_port | wc -l`
        else
            isRunning=`ps -ef | grep postgres | grep "\-D" | grep -v grep | grep gp_role=dispatch | grep -w $gp_ver | wc -l`
        fi
        [ "x$isRunning" == 'x0' ] && status="${red}Offline${normal}"

        declare -A SegmentUsage     ### hash for store space usage for all segment

        for host in `cat $SegmentList | grep -v "^#"`
        do
            ### segment data folder usage ###
            usage_seg_data=`ssh $host "du -s $gp_seg_data_folder 2>/dev/null | awk '{print \\\$1}' "`
            [ "x$usage_seg_data" == 'x' ] && usage_seg_data=0
            ECHO_DEBUG "$host segment folder usage: [$usage_seg_data]"

            ### segment gphome folder usage ###
            usage_seg_gphome=`ssh $host "du -s $GP_HOME/$build 2>/dev/null | awk '{print \\\$1}' "`
            [ "x$usage_seg_gphome" == 'x' ] && usage_seg_gphome=0
            ECHO_DEBUG "$host segment gphome usage: [$usage_seg_gphome]"

            segment_total_usage=$(($usage_seg_data+$usage_seg_gphome))
            ECHO_DEBUG "$host total usage [$segment_total_usage]"
            SegmentUsage+=(["$host"]="$segment_total_usage")
            total_usage=$(($total_usage+$segment_total_usage));
        done
        total_usage_readable=`numfmt --from-unit=1024 --to=iec $total_usage`
        echo -e "    Build: [ ${yellow}${GP_HOME}/${build}${normal} ] \t Port: [ ${yellow}$gp_port${normal} ]   \t Status: [ $status ] \t Total usage: [ ${yellow}$total_usage_readable${normal} ]" 
    done
    echo ""

### Scenario#2, only list build/port/status ###
else
    #for build in `ls $GP_HOME | grep "^greenplum_"`
    for build in `ls -d $GP_HOME/greenplum_*/ | awk -F'/' '{print $3}'`    
    do
        gp_ver=`echo $build |  sed 's/greenplum_//g'`
        gp_port=`get_port $gp_ver`
        
        status="${green}Online${normal}"
        isRunning=''

        gp_majorVer=`echo $gp_ver | cut -d'.' -f 1`
        if [ $gp_majorVer -le 6 ]
        then
            isRunning=`ps -ef | grep postgres | grep master | grep "\-D" | grep "$gp_ver" | grep $gp_port | wc -l`
        else
            isRunning=`ps -ef | grep postgres | grep "\-D" | grep -v grep | grep gp_role=dispatch | grep -w $gp_ver | wc -l`
        fi
        [ "x$isRunning" == 'x0' ] && status="${red}Offline${normal}"

        ## check the last log time ##
        source ${GP_HOME}/${build}/greenplum_path.sh > /dev/null 2>&1 
	log_file=`find $MASTER_DATA_DIRECTORY/pg_log/ -size +0 | grep gpdb- | tail -1`; 
        # echo "DEBUG: logfile is [$log_file]"
        last_log_date=`tail -200 $log_file | grep "^[0-9]*-[0-9]*-[0-9]* "|tail -1 | awk '{print $1,$2}' | sed 's/\..*//g'`

        echo -e "    Build: [ ${yellow}${GP_HOME}/${build}${normal} ] \t Port: [ ${yellow}$gp_port${normal} ]   \t Status: [ $status ]   \t Last log time: [${yellow}$last_log_date${normal}]"
    done
    echo ""
fi





