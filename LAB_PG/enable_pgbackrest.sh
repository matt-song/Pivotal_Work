#!/bin/bash
################################################################################
# Note:                                                                        #
#   - Use this script to enable pg_backrest on all nodes                       #
################################################################################
backupFolder='/data/pgbackrest'
pgbackrestConfFolder='/etc/pgbackrest'
pgbackrestLogFolder='/var/log/pgbackrest'
pgUser='postgres'
# monitorPGDATA=''
dataNodePGDATA='/data/database'
dataNodePort=5432
backupStanza='main'
db='postgres'
subnet='10.216.0.0/16'    ## the subnet for all cluster, TBD: will update here to automatic detect it later
workFolder=$(mktemp -d)

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
    $scriptName -m <monitor_host> -d <data_host_01, data_host_02, ...> 
    $scriptName -m <monitor_host> -d <data_host_01, data_host_02, ...> -D  ## enable debug mode"
    exit 1
}
### get the parameters ###
while getopts 'm:d:hD' opt
do
    case $opt 
    in
        m) monitor_host=${OPTARG}   ;;
        d) data_nodes=${OPTARG}     ;;
        D) DEBUG=1              ;;
        h) print_help           ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
    esac
done

if [ "x$monitor_host" == 'x' ]||[ "x$data_nodes" == 'x' ]; then
    print_help
fi

### Functions ###
print_warning()
{
    ECHO_WARN "monitor: $monitor_host, Data Nodes: $data_nodes"
}

run_remote_command()
{
    local host=$1
    local command=$2
    ECHO_DEBUG "Going to run [$command] on [$host]..."
    ssh $host "$command"
    if [ $? -ne 0 ]; then 
        ECHO_ERROR "Failed to run [$command] on [$host], exit!"
        exit 1
    fi 
}

prepare()
{
    ## check if connection is ok and if we can sudo 
    allHosts="$monitor_host `echo $data_nodes | sed 's/,/ /g'` "
    ECHO_DEBUG "host list: $allHosts"
    for host in $allHosts
    do 
        ECHO_SYSTEM "Testing root connection to [$host]..."
        run_remote_command "$host" "sudo uptime 2>&1 > /dev/null"
    done 

    ### Setup monitor folder
    ECHO_SYSTEM "Creating backup folder under [$backupFolder] on host [$monitor_host]..."
    run_remote_command $monitor_host "sudo mkdir -p $backupFolder; sudo chmod 750 $backupFolder; sudo chown -R $pgUser:$pgUser $backupFolder"
    ECHO_SYSTEM "Creating log folder under [$pgbackrestLogFolder] on host [$monitor_host]..."
    run_remote_command $monitor_host "sudo mkdir -p $pgbackrestLogFolder ; sudo chown $pgUser:$pgUser $pgbackrestLogFolder"
    ECHO_SYSTEM "Creating configuration folder under [$pgbackrestConfFolder] on host [$monitor_host]..."
    run_remote_command $monitor_host "sudo mkdir -p $pgbackrestConfFolder; sudo chown -R $pgUser:$pgUser $pgbackrestConfFolder"
    
    for dataHost in `echo $data_nodes | sed 's/,/ /g'` 
    do
        ECHO_SYSTEM "Creating configuration folder under [$pgbackrestConfFolder] on host [$dataHost]..."
        run_remote_command $dataHost "sudo mkdir -p $pgbackrestConfFolder; sudo chown -R $pgUser:$pgUser $pgbackrestConfFolder"
    done
}

update_pgbackrest_conf()
{
    ECHO_SYSTEM "Generating monitor's pgbackrest.conf.."
    monitorConfFile=$workFolder/monitor_pgbackrest.conf
    echo "[main]" > $monitorConfFile
    count=1
    for host in `echo $data_nodes | sed 's/,/\n/g' | sort -n`
    do
        echo "
pg$count-path=$dataNodePGDATA
pg$count-port=$dataNodePort
pg$count-host=$host
pg$count-socket-path=/tmp" >> $monitorConfFile
    count=$((count+=1))
    done
    
    echo "
[global]
repo1-path=$backupFolder
repo1-retention-full=2
start-fast=y
"  >> $monitorConfFile 
    ECHO_DEBUG "the content of monitor's pgbackrest.conf is [\n`cat $monitorConfFile`]"
    ECHO_SYSTEM "Updating monitor's pgbackrest.conf.."
    scp $monitorConfFile "$monitor_host:$pgbackrestConfFolder/pgbackrest.conf" || { ECHO_ERROR "Failed to update the monitor's pgbackrest.conf!" ; exit 1; }

    ECHO_SYSTEM "Generating DataNode's pgbackrest.conf.."
    dataNodeConfFile=$workFolder/dataNode_pgbackrest.conf
    echo "
[main]
pg1-path=$dataNodePGDATA
pg1-socket-path=/tmp
pg1-port=$dataNodePort

[global]
log-level-file=detail
repo1-host=$monitor_host
repo1-host-user=$pgUser
" > $dataNodeConfFile
    ECHO_DEBUG "the content of dataNode's pgbackrest.conf is [\n`cat $dataNodeConfFile`]"
    for host in `echo $data_nodes | sed 's/,/ /g'`
    do
        ECHO_SYSTEM "Updating pgbackrest.conf on [$host].."
        scp $dataNodeConfFile "$host:$pgbackrestConfFolder/pgbackrest.conf" || { ECHO_ERROR "Failed to update the pgbackrest.conf on host [$host]!!" ; exit 1; }
    done
}

enable_Archive_On_DataNode()
{
    ### set all standby to maintaince mode first 
    ECHO_SYSTEM "Setting all standby node to maintainence mode..."
    for host in `echo $data_nodes | sed 's/,/ /g'`
    do  
        isStandby=`ssh $host "pg_controldata $dataNodePGDATA | grep 'Database cluster state:' | grep 'in production' | wc -l"`
        if [ $isStandby -eq 0 ]; then 
            ECHO_SYSTEM "Setting [$host] to maintainence mode..."
            run_remote_command $host "pg_autoctl enable maintenance"
        fi 
    done

    for host in `echo $data_nodes | sed 's/,/ /g'`
    do 
        pgHome=`ssh $host "ps -ef | grep postgres | grep vmware | grep D | grep -v bash | awk '{print \\\$8}' | sed 's/postgres$//g' "`
        if [ "x$pgHome" != 'x' ]; then 
            pgbackrestBin="${pgHome}pgbackrest"
        else
            ECHO_ERROR "Failed to locate the binary of pgbackrest, please check and try again!"
            exit 1
        fi
        run_remote_command $host "psql -d $db -c \"alter system set archive_command = '$pgbackrestBin --stanza=$backupStanza archive-push %p';\""
        run_remote_command $host "psql -d $db -c \"alter system set archive_mode = 'true';\""
        
        ## update pg_hba.conf 
        run_remote_command $host "echo \"host    all             $pgUser             $subnet            trust\" >> $dataNodePGDATA/pg_hba.conf"

        ## restart pgautofailover
        run_remote_command $host "sudo systemctl restart pgautofailover;"

    done 

    ### remove the maintaince mode 
    ECHO_SYSTEM "Setting all standby node to normal mode..."
    for host in `echo $data_nodes | sed 's/,/ /g'`
    do  
        isStandby=`ssh $host "pg_controldata $dataNodePGDATA | grep 'Database cluster state:' | grep 'in production' | wc -l"`
        if [ $isStandby -eq 0 ]; then 
            ECHO_SYSTEM "Setting [$host] to normal mode..."
            run_remote_command $host "pg_autoctl disable maintenance"
        fi 
    done
}
createStanza()
{
    ECHO_SYSTEM "Creating Stanza on repo host [$monitor_host]..."
    run_remote_command $monitor_host "pgbackrest --stanza=$backupStanza --log-level-console=info stanza-create"

    ### check from node: pgbackrest --stanza=main --log-level-console=info check
}
# validate()
# {
#
# }

cleanup()
{
    ECHO_SYSTEM "Cleanup all temp work file and folder..."
    if [ -d $workFolder ]; then 
        rm -rf $workFolder
    fi
}


### Start the work ###
prepare                         ## 01: precheck and create the related folder if not there
update_pgbackrest_conf          ## 02: generate conf file for pgbackrest
createStanza                    ## 03: create the Stanza
enable_Archive_On_DataNode      ## 04: enable the archive on all datanode

cleanup                         ## remove the temp work folder