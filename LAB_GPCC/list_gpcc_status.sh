#!/bin/bash

# SegmentList="/home/gpadmin/all_segment_hosts.txt"
GPCC_HOME="/opt"

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
    $scriptName         list all installed GPCC
    $scriptName -D      enable debug mode
    $scriptName -h      print this message"
    exit 1
}
### Start the work ###

### get the parameters ###
while getopts 'Dh' opt
do
    case $opt 
    in
        D) DEBUG=1              ;;
        h) print_help           ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
  esac
done

clear; ECHO_SYSTEM "Generating the report of installed GPCC...\n"

for gpcc_build in `ls $GPCC_HOME | grep "greenplum-cc-web-[0-9]"`
do
        gpcc_ver=`echo $build | awk -F"-" '{print $4}'`
        echo -e "[ ${yellow}${GPCC_HOME}/${gpcc_build}${normal} ]"
done