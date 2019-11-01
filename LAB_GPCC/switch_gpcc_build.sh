#!/bin/bash
# switch the GPCC build on smdw

GPCC_HOME="/opt"
GPCC_PORT=28080

DEBUG=1

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
ECHO_SYSTEM "${green}Getting the installed build under [$GPCC_HOME]:\n${normal}"

stop_gpcc()
{
    build=$1   # example input: /opt/greenplum-cc-web-4.7.0
    gpcc_ver=`echo $build | awk -F'-' '{print $NF}'`
    gpcc_family=`echo $gpcc_ver | sed 's/\..*//g'`

    if [ $gpcc_family -le 3 ]
    then

    elif [ $gpcc_family -gt 3 ]

    else
    fi


    # Cur_GPCC_build=`lsof -p $cur_PID | grep greenplum-cc-web | grep $GPCC_HOME | awk '{print $NF}' | awk -F"/" '{print $3}' | sort -u | head -1`

    #        Cur_GPCC_folder=$GPCC_HOME"/$Cur_GPCC_build"
#           Cur_GPDB_port=`ps -ef | grep \`lsof -p $cur_PID | grep IPv4 | grep -v $GPCC_PORT | head -1 | awk -F":" '{print $2}' | sed 's/-.*//g'\` | awk -F'postgres:' '{print $2}' | awk '{print $1}' | sed 's/,//g'`
#        Cur_GPDB_folder=`ps -ef | grep $Cur_GPDB_port | grep /opt | grep postgres | awk '{print $8}' | sed 's/\/bin.*//g'`

#        ECHO_DEBUG "GPDB PORT: [$Cur_GPDB_port]; GPDB_Folder: [$Cur_GPDB_folder]"


        ### Stop the running GPCC ###

}

switch_gpcc()
{
    build=$1
    gpcc_home=${GP_HOME}/${build}
    gpcc_ver=`echo $build | awk -F"-" '{print $4}'`

    ECHO_DEBUG "target build: [$build], "
    
    ### check if other gpcc process has already started, currently we only support single gpcc instance running ###
    isRunning=`ps -ef | grep greenplum-cc-web | egrep -v "grep|ccagent|gpmonws"`
    if [ "x$isRunning" == 'x' ] 
    then
        cur_PID=`echo $isRunning | awk '{print $2}'`
        Cur_GPCC_folder=$GPCC_HOME"/"`echo $isRunning | awk '{print $8}' | awk -F '/' '{print $3}'`
        [ -L $Cur_GPCC_folder ] && Cur_GPCC_folder=`readlink $Cur_GPCC_folder` # is a link?
        
        ECHO_WARN "There is already a GPCC instance running: 
        PID:         $cur_PID
        Folder:      $Cur_GPCC_folder

        Do you want to stop it first? [Y/N]"
        read confirm
        if [ "x$confirm" = 'xy' ] || [ "x$confirm" = 'xyes' ] || [ "x$confirm" = 'xY' ] || [ "x$confirm" = 'xYes' ]
        then
            stop_gpcc $Cur_GPCC_folder
        else
            ECHO_WARN "Please stop the running GPCC instance first before swithing the version to [$build]"
            exit 1
        fi
    else
        #ECHO_SYSTEM "Switching build to [$gp_home]..."
        #source ${GP_HOME}/${build}/greenplum_path.sh
        # ECHO_SYSTEM "Done :)" 
        ### TBD: might need add some verification sql command to make sure the DB has been switched
    fi
}

### Start work here ###

count=0
unset GPDB_BUILD; declare -A GPDB_BUILD

for build in `ls $GPCC_HOME | grep "greenplum-cc-web-[0-9]"`
do
    count=$(($count+1))
    echo -e "    [$count]:  $build"
    GPCC_BUILD+=(["$count"]="$build")
done

ECHO_SYSTEM "\nplease choose which build you want to switch:"
read input
target_build=${GPCC_BUILD[$input]}

if [ "x$target_build" = 'x' ]
then
    ECHO_ERROR "Unable to find build with input [$input]!"
else
    switch_gpcc $target_build
fi


