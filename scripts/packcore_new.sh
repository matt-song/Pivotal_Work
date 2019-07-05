#!/bin/bash

### get the parameters ###
while getopts 's:d:hD' opt
do
    case $opt 
    in
        c) coreFile=${OPTARG}       ;;
        g) GPHOME=${OPTARG}         ;;
        f) targetFolder=${OPTARG}   ;;
        D) DEBUG=1                  ;;
        h) print_help               ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
  esac
done

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

checkCoreFile()
{
    if [ ! -f $coreFile ]
    then
        ECHO_ERROR "No such file [$coreFile], exit!"
        exit 1
    fi
}

checkGPHOME()
{
    if [ "x$GPHOME" != "x" ]
    then
        if [ -f "$GPHOME/greenplum_path.sh" ]
            source "$GPHOME/greenplum_path.sh"
        else
            
    else 

}



checkGPHOME

### Start work ###