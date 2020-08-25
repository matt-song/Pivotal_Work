#!/bin/bash

### get the parameters ###
while getopts 'f:s:hD' opt
do
    case $opt 
    in
        f) log_file=${OPTARG}   ;;
        s) target_session=${OPTARG}   ;;
        D) DEBUG=1              ;;
        h) print_help           ;;
        *) echo "Wrong input, please check the usage with [$0 -h]" ;;
  esac
done

print_help()
{
    echo "Usage: `basename $0` -s [target_session_id] -f [log_file]"
    exit 1;
}

check_input()
{
    if [ "x$log_file" == 'x' ]
    then 
        echo "missing log file, please run `basename $0` -h to check the usage"
        print_help
    elif [ "x$target_session" == 'x' ] 
    then
        echo "No target session ID specified, listing all logs from [$log_file]..."
        grep "The previous session was reset because its gang was disconnected" $log_file
    fi
}

#original_session=''
find_original_session()
{
    session=$1
    echo "Searching the log file [$log_file] with session ID [$session]..."

    filter_word="The previous session was reset because its gang was disconnected"
    sessID="con${session}"
    next_session=`grep $sessID $log_file | grep "$filter_word" | awk -F',' '{print $19}' | awk -F'=' '{print $2}' | sed 's/).*//g' | sed 's/ //g'`
    if [ "x${next_session}" != 'x' ]
    then
        echo "Find session [$next_session], checking next..."
        find_original_session $next_session
    else
        echo "no more sessions, the original session is [$session]"
        echo -e "\n========================================"
        echo "Below is the logs of session [$session]..."
        echo -e "========================================\n"
        grep "con${session}" $log_file | grep ERROR
    fi
}


### start the work ###

check_input
find_original_session $target_session