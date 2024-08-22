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

### Start work here ###

count=0
unset GPDB_BUILD; declare -A GPDB_BUILD

#for build in `ls $GP_HOME | grep greenplum_`
for build in `ls -d $GP_HOME/greenplum_*/ | awk -F'/' '{print $3}'`
do
    count=$(($count+1))
    gp_ver=`echo $build |  sed 's/greenplum_//g'`
    gp_port=`get_port $gp_ver`

    isRunning=`ps -ef | grep postgres | grep master | grep "\-D" | grep "$gp_ver" | grep $gp_port | wc -l`
    if [ "x$isRunning" == 'x0' ]
    then
        status="Offline"
        printf "%-6s%-20s[ ${red}%s${normal} ]\n" "[$count]" "$build" "$status"
    else
        status="Online"
        printf "%-6s%-20s[ ${green}%s${normal} ]\n" "[$count]" "$build" "$status"
    fi
    # echo -e "  [$count]:  \t$build \t[$status]"
    # printf "%-6s%s  [$status]\n" "[$count]" "$build"
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


