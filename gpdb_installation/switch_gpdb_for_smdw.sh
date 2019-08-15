#!/bin/bash
# switch the gpdb build on smdw

SegmentList="/home/gpadmin/all_segment_hosts.txt"
GP_HOME="/opt"

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

clear
ECHO_SYSTEM "${green}Getting the installed build under [$GP_HOME]:\n${normal}"

switch_gpdb()
{
    build=$1
    gp_home=${GP_HOME}/${build}
    gp_ver=`echo $build |  sed 's/greenplum_//g'`
    
    isRunning=`ps -ef | grep postgres | grep master | grep "\-D" | grep "$gp_ver" | wc -l`
    if [ "x$isRunning" == 'x0' ] 
    then
        ECHO_WARN "GPDB installed in [/opt/$build] is not running! Do you want to start the DB first?"
        read confirm
        if [ "x$confirm" = 'xy' ] || [ "x$confirm" = 'xyes' ] || [ "x$confirm" = 'xY' ] || [ "x$confirm" = 'xYes' ]
        then
            source /opt/$build/greenplum_path.sh; gpstart -a
        else
            ECHO_WARN "Please use below command to start DB first if you would like to swith to [$build]\n"
            ECHO_WARN "=== Command === \n# source /opt/$build/greenplum_path.sh \n# gpstart -a"
        fi
    else
        ECHO_SYSTEM "Switching build to [$gp_home]..."
        source ${GP_HOME}/${build}/greenplum_path.sh
        ECHO_SYSTEM "Done :)" 
        ### TBD: might need add some verification sql command to make sure the DB has been switched
    fi
}

### Start work here ###

count=0
unset GPDB_BUILD; declare -A GPDB_BUILD

for build in `ls $GP_HOME | grep greenplum_`
do
    count=$(($count+1))
    echo -e "    [$count]:  $build"
    GPDB_BUILD+=(["$count"]="$build")
done

ECHO_SYSTEM "\nplease choose which build you want to switch:"
read input
target_build=${GPDB_BUILD[$input]}

if [ "x$target_build" = 'x' ]
then
    ECHO_ERROR "Unable to find build with input [$input]!"
else
    switch_gpdb $target_build
fi


