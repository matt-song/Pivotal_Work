#!/bin/bash
###########################################################################################
# Author:      Matt Song                                                                  #
# Create Date: 2019.05.02                                                                 #
# Description:                                                                            #
# use this script to clear existing GPDB package and data, run this one on master server  #
###########################################################################################

SegmentList="/home/gpadmin/all_segment_hosts.txt"
GP_HOME="/opt"
GP_DATA_MASTER="/data/master"
GP_DATA_SEGMENT="/data/segment"
GP_ORI_HOME='/usr/local'

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

clear
ECHO_SYSTEM "Getting the installed build under [$GP_HOME]:\n"

count=0
declare -A GPDB_BUILD

check_gpdb_running()
{
    build=$1
    gp_ver=`echo $build | sed 's/greenplum_//g'`
    
    isRunning=''
    gp_majorVer=`echo $gp_ver | cut -d'.' -f 1`
    if [ $gp_majorVer -le 6 ]
    then
        isRunning=`ps -ef | grep postgres | grep master | grep "\-D" | grep "$gp_ver" | wc -l`
    else
        isRunning=`ps -ef | grep postgres | grep "\-D" | grep -v grep | grep gp_role=dispatch | grep -w $gp_ver`
    fi

    if [ "x$isRunning" != 'x0' ]
    then
        ECHO_WARN "GPDB installed in [/opt/$build] is running! Please stop the DB first, exit!"
        ECHO_WARN "Command: # source /opt/$build/greenplum_path.sh; gpstop -a -M fast"
        exit
    else
        return 0
    fi
}

uninstallGPDB()
{
    build=$1
    gp_ver=`echo $build | sed 's/greenplum_//g'`

    gp_home=${GP_HOME}/${build}
    master_data_folder="${GP_DATA_MASTER}/master_${gp_ver}"
    segment_data_folder="${GP_DATA_SEGMENT}/segment_${gp_ver}"

    ### special design for smdw ###
    hostname=`uname -n`
    if [ "x$hostname" == 'xmdw' ] 
    then 
        port_md5_int=`echo "$gp_ver" | md5sum | awk '{print $1}' | tr a-f A-F `; port=`echo $port_md5_int % 9999 | bc`
        data_id=`echo $port % 2 + 1 | bc`
        segment_data_folder="/data${data_id}/segment/segment_${gp_ver}"
    fi
    ### end ###

    ECHO_WARN "Going to uninstall GPDB installed under [$gp_home]"
    ECHO_SYSTEM "
Below folder will be removed if exists:

    ${master_data_folder} on [$hostname]
    ${gp_home} on all segment listed in [$SegmentList] 
    ${segment_data_folder} on all segment listed in [$SegmentList] 

Please confirm if you would like to continue: [y/n]"

    read confirm
    if [ "x$confirm" = 'xy' ] || [ "x$confirm" = 'xyes' ] || [ "x$confirm" = 'xY' ] || [ "x$confirm" = 'xYes' ]
    then

        [ -d ${gp_home} ] && rm -rf $gp_home && echo "Removed [$gp_home]"
        [ -d ${master_data_folder} ] && rm -rf $master_data_folder && echo "Removed [$master_data_folder]"
        
        ECHO_WARN "Check if there is any rpm package for [$gp_ver], might need root privilege (sudo) to remove the rpm..."
        ## no need to check version since it will skip if did no find rpm package
        [ `rpm -qa | grep greenplum-db | grep ${gp_ver} | wc -l` -gt 0 ] && sudo rpm -e `rpm -qa | grep greenplum-db | grep ${gp_ver}` || :

        for server in `cat $SegmentList | grep -v "^#"`
        do
            if [ "x`echo $gp_ver | sed 's/\..*//g'`" == 'x6' ] || [ "x`echo $gp_ver | sed 's/\..*//g'`" == 'x7' ]
            then
                sudo ssh $server "[ `rpm -qa | grep greenplum-db | grep ${gp_ver} | wc -l` -gt 0 ] && rpm -e `rpm -qa | grep greenplum-db | grep ${gp_ver}` || : "
                ## remove the folder on /opt, it is a link
		ssh $server "[ -h ${gp_home} ] && rm -f $gp_home && echo \"Removed [$gp_home] on segment host [$server]\""
		## remove the folder on /usr/local
                ssh $server "[ -d ${GP_ORI_HOME}/greenplum-db-${gp_ver} ] && sudo rm -rf ${GP_ORI_HOME}/greenplum-db-${gp_ver} && echo \"Removed [${GP_ORI_HOME}/greenplum-db-${gp_ver}] on segment host [$server]\""
            else ## not rpm install, just remove the data folder
                ssh $server "[ -d ${segment_data_folder} ] && rm -rf $segment_data_folder && echo \"Removed [$segment_data_folder] on segment host [$server]\""
                ssh $server "[ -d ${gp_home} ] && rm -rf $gp_home && echo \"Removed [$gp_home] on segment host [$server]\""
            fi            
            #echo "Removed $segment_data_folder on segment host [$server]"
        done
    else
        ECHO_ERROR "Cancelled by user, exit.."
    fi
}

for build in `ls $GP_HOME | grep greenplum_`
do
    count=$(($count+1))
    ECHO_WARN "    [$count]:  $build"
    GPDB_BUILD+=(["$count"]="$build")
done

ECHO_SYSTEM "\nplease choose which build you want to uninstall:"
read input
build_2_remove=${GPDB_BUILD[$input]}

if [ "x$build_2_remove" = 'x' ]
then
    ECHO_ERROR "Unable to find build with input [$input], exit!"
    exit 1
else
    check_gpdb_running $build_2_remove
    uninstallGPDB $build_2_remove
fi


