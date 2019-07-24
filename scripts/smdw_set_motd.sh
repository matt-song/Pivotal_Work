#!/bin/bash

## color variables
green="\e[1;32m"
normal="\e[0m"
Blcyan="\e[1;96m"
cyan="\e[36m"
yellow="\e[33m"

ECHO_GREEN()
{
    message=$1
    echo -e "${green}${message}${normal}"
}
ECHO_LightCyan()
{
    message=$1
    echo -e "${Blcyan}${message}${normal}"
}
ECHO_Cyan()
{
    message=$1
    echo -e "${cyan}${message}${normal}"
}
ECHO_Yellow()
{
    message=$1
    echo -e "${yellow}${message}${normal}"
}


title=`figlet -w 1000  "Welcome to Shanghai LAB"`

ECHO_GREEN "${title}"

ECHO_LightCyan "########### Some tips ###########\n"

ECHO_LightCyan "- To list all installed GPDB status"
ECHO_Cyan "  # bash ~/scripts/list_gpdb_status.sh\n"

ECHO_LightCyan "- To switch gpdb build:"
ECHO_Cyan "  # gpdb\n"

ECHO_LightCyan "- To download a new gpdb installation package:"
ECHO_Cyan "  # bash  ~/scripts/download_gpdb.sh\n"

ECHO_LightCyan "- To install a new build of gpdb:"
ECHO_Cyan "  # perl ~/scripts/install_gpdb_for_smdw.pl -f ~/packages/greenplum-db-4.3.31.0-rhel5-x86_64.zip\n"

ECHO_LightCyan "- To uninstall a build of gpdb:"
ECHO_Cyan "  # bash ~/scripts/uninstall_GPDB.sh\n"

ECHO_LightCyan "- To check the space usage for each cluster"
ECHO_Cyan "  # bash ~/scripts/list_gpdb_status.sh -f\n"

ECHO_Yellow "Important: Please do not remove the file [all_segment_hosts.txt] and [all_hosts.txt] under gpadmin's home folder, it was required by above scripts\n"
