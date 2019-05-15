#!/bin/bash
# use this script to list existing GPDB status

SegmentList="/home/gpadmin/all_segment_hosts.txt"
GP_HOME="/opt"
GP_DATA_MASTER="/data/master"
#GP_DATA_SEGMENT="/data/segment"

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

print_help()
{
    scriptName=`basename $0`
    ECHO_SYSTEM "Usage: 
    $scriptName         list all installed GPDB
    $scriptName -f      list full output, included the usage
    $scriptName -h      print this message"
    exit 1
}



### Start the work ###
clear

### get the parameters ###
while getopts 'fh' opt
do
    case $opt 
    in
        f) fullOutput=1         ;;
        h) print_help           ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
  esac
done

ECHO_SYSTEM "Generating the list of installed GPDB...\n"

for build in `ls $GP_HOME | grep "^greenplum_"`
do
    gp_ver=`echo $build |  sed 's/greenplum_//g'`
    master_data="$GP_DATA_MASTER/master_${gp_ver}"
    port_md5_int=`echo "$gp_ver" | md5sum | awk '{print $1}' | tr a-f A-F `
    gp_port=`echo $port_md5_int % 9999 | bc`
    gp_data_id=`echo $gp_port % 2 + 1 | bc`
    gp_seg_data_folder="/data${gp_data_id}/segment_${gp_ver}"

    status="${green}Online${normal}"
    isRunning=`ps -ef | grep -w $build | grep -v grep | grep silent | wc -l `
    [ "x$isRunning" == 'x0' ] && status="${red}Offline${normal}"

    if [ "x$fullOutput" == 'x1' ]
    then
        echo "TBD"
    else 
        echo -e "    Build: [ ${yellow}${GP_HOME}/${build}${normal} ] \t Port: [ ${yellow}$gp_port${normal} ]   \t Status: [ $status ]"
    fi
done
echo ""

