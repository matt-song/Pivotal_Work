#!/bin/bash
##################################################################################################
# Created by Matt @ Jan 15th:                                                                    #
# 1. add the parameter so we can specific which particular segment to run                        #
# 2. change the output to 1 file and we should also print the output to STDOUT                   #
# 3. Added Debug mode and allow user to pass the parameter to script.                            #
# 4. the script will no longer select a master as target since we always on master               #
# 5. will ask user to input yes before actually do anything                                      #
# 6. changed to let user input the sql, do a syntax check on master before acturally run that.   #
##################################################################################################

### print the help message ###
print_help()
{
    echo "
    Usage:  $0                                  - Work on all segment on default DB (gpadmin)
            $0 -d gpadmin                       - Work on database: gpadmin
            $0 -s "2,30,31"                     - Work on segment with content ID 2,30,31
            $0 -s "2,30,31" -d gpadmin          - Work on segment with content ID 2,30,31 on DB gpadmin 
"
    exit 1;
}
### define colorful print ###
ECHO_COLOR()
{
    color = $1
    message = $2

    ## color variables
    green="\[\e[1;32m\]"
    red="\[\e[1;31m\]"
    yellow="\[\e[1;33m\]"
    normal="\[\e[0m\]"

    [ "x${color}" == 'x' ] && color = normal
    echo "${color}${message}$normal"
}
ECHO_SYSTEM()
{
    message=$1;
    ECHO_COLOR "green" "$message"
}
ECHO_WARN()
{
    message=$1;
    ECHO_COLOR "yellow" "$message"
}
ECHO_ERROR()
{
    message=$1;
    ECHO_COLOR "red" "$message"
    exit 1;
}

### print DEBUG message ###
DEBUG()
{
    message=$1
    [ "x${DEBUG}" == "x1" ] && echo "[DEBUG] $message"
}

### get the segment list, if user not specific, return all primary segment, not include master ###
SQL_getAllSegment=''
get_seg_list()
{
    seg_to_work='';

    if [ "x${SEG_LIST}" == 'x' ]
    then 
        SQL_getAllSegment="select hostname || ' ' || port from gp_segment_configuration where role = 'p' and content >=0;"
    else
        for segID in `echo $SEG_LIST | sed 's/,/ /g' | tr " " "\n"|sort -nu|tr "\n" " "`
        do
            seg_to_work="$seg_to_work,$segID"
        done
        seg_to_work=`echo $seg_to_work | sed 's/^,//g'`
        SQL_getAllSegment="select hostname || ' ' || port from gp_segment_configuration where role = 'p' and content in ($seg_to_work);"
    fi
    DEBUG "The segment list is: [$seg_to_work]"
    DEBUG "The SQL to get segment list is [$SQL_getAllSegment]"
}

### Let user input the SQL to execute, do a syntax check before really execute it.
SQL_toExecute=''
get_sql_from_input()
{
    ECHO_WARN "!!! Please be cautious before running any SQL that may modify the data !!!\n"
    ECHO_SYSTEM "Please input the SQL you would like to run: "
    read input_sql
    DEBUG "User input SQL is [$input_sql]"

    ### Syntax check, explain the sql, if return non-zero then the the SQL probably is wrong. ###
    ECHO_SYSTEM "Checking the syntax...\n"
    psql -c "EXPLAIN $input_sql" 1>/dev/null 
    if [ $? == 0 ]
    then
        ECHO_SYSTEM "Syntax look good, continue..."
    else
        ECHO_ERROR "Syntax is wrong, check the error message for more detail, exit!"
    fi
    SQL_toExecute=$input_sql
}

### Let user confirm it he/she is ok with the command ###
show_warning()
{
    ECHO_SYSTEM "Will run SQL command [$SQL_toExecute] on below host:"
    IFS=$'\n';
    for line in `psql -Atc "${SQL_getAllSegment}" $DATABASE`
    do 
        echo $line | awk '{print "Host: [",$1,"] Porr: [", $2." ]"}'
    done
    unset IFS;

    ECHO_SYSTEM "Please confirm if you would like to continue [y/n]"
    read confirm
    if [ "x${confirm}" == 'xyes' ] || [ "x${confirm}" == 'xy' ] || [ "x${confirm}" == 'xY' || [ "x${confirm}" == 'xYes' ]
    then
        ECHO_SYSTEM "Start to work..."
    else
        ECHO_ERROR "Cancelled by user, exit"
    fi
}

### run the SQL ###
run_SQL_on_segment()
{
    export PGOPTIONS="-c gp_session_role=utility"

    # Loop over segments
    psql -Atc "${sql_segments}" postgres | while read host port;
    do
        ECHO_ "Executing the SQL on host: [$host] port: [$port]";
        #nohup psql -a -h ${host} -p ${port} postgres > ${prefix}_${host}_${port}.${now}.${suffix} 2>&1 <<EOF
        #${sqls_to_execute}
    done
    export PGOPTIONS=""   
}

### get the parameters ###
while getopts 's:d:hD' opt
do
    case $opt 
    in
        s) SEG_LIST=${OPTARG}   ;;
        d) DATABASE=${OPTARG}   ;;
        D) DEBUG=1              ;;
        h) print_help           ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
  esac
done

### Check the input for DB, if no input then use gpadmin as default.
[ x"$DATABASE" == 'x' ] && DATABASE='gpadmin'
DEBUG "The target DB is [$DATABASE]"

### check the input for seg list, should only contain [0-9] and ','
is_valid=`echo $SEG_LIST | sed 's/[0-9]//g' | sed 's/,//g'`
if [ "x${is_valid}" != 'x' ]
then 
    echo "Invalid input [$SEG_LIST], exit"
    print_help
fi
DEBUG "The target segment is [$SEG_LIST]"

####################################
#      Start the work at here      #
####################################

clear

get_seg_list
get_sql_from_input

show_warning

#run_SQL_on_segment




