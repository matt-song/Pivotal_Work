#!/bin/bash
#################################################################
# Author:      Matt Song                                        #
# Create Date: 2018.11.07                                       #
# Description: generate the DDL based on \d+ output from GPDB  #
#################################################################
IFS=$'\n'
output='';

### check if we have input file ###
dt_file=$1; 
[ ! -f $dt_file ] && echo "Usage: $0 [\d+ output]" && exit 1;

### get the name of the table
get_table_name()
{
    table_name=`cat $dt_file | grep "Table" | head -1 |  awk '{print $NF}' | sed 's/"//g'`;
    output="CREATE TABLE $table_name\n(\n";
}

### get columns ###
get_column()
{
    for i in `cat $dt_file | grep '|' | grep -v Column`;
    do
        name=`echo $i | awk -F'|' '{print $1}' | sed 's/[[:space:]]*$//g' | sed 's/^ //g'`
        type=`echo $i | awk -F'|' '{print $2}'| sed 's/[[:space:]]*$//g'| sed 's/^ //g'`
        modifier=`echo $i | awk -F'|' '{print $3}'| sed 's/[[:space:]]*$//g' | sed 's/^ //g'`

        output+="    $name $type ${modifier},\n"
    done
}

### get the index settings ###
check_index()
{
    index_type=`cat $dt_file | egrep "UNIQUE|PRIMARY KEY" | awk '{print $2}' | sed 's/,//g'`

    case $index_type in

        UNIQUE)   ### unique index
            
            unique_key=`cat $dt_file | grep UNIQUE | awk -F'(' '{print "("$NF}'`
            [ x"$unique_key != x " ] && output+="    UNIQUE $unique_key\n"
            ;;

        PRIMARY)   ### primary key
        
            primary_key=`cat $dt_file | grep PRIMARY | awk -F"(" '{print $NF}' | sed 's/)//g'`
            [ x"$primary_key" != x ] && output+="    PRIMARY KEY ($primary_key)\n"
            ;;
        
        "")
            ;;      ### no index, do nothing
        *)
            echo "found unknown index type [$index_type], please review the d+ output!"
            exit 1
            ;;
    esac

    output+=")"
}


### check if this is a ao table, if yes, check if this is a partition table ###
check_ao_table()
{

    table_type=`cat $dt_file | grep "Table" | head -1 | awk '{print $1}'`

    if [ "$table_type" == "Append-Only" ]    ### is AO table
    then
        Option=`cat $dt_file | grep Options | sed 's/Options: //g'`
        output+="\nWITH ($Option) "
    fi
}

### check the check_distribution key of the table ###
check_distribution()
{
    distribute_by=`cat $dt_file | grep "Distributed by" | awk -F"(" '{print $NF}' | sed 's/)//g'`
    
    if [ x"$distribute_by" != x ]
    then
        [ "$table_type" != "Append-Only" ] && output+="\n"
        output+="DISTRIBUTED BY ($distribute_by)"
    fi
}

: <<'end_comment' ### so far not able to generate partition table base on D+ output
### check if this is a if this is a partition table  table ###

check_partition_table()
{
    partition_by=`cat $dt_file  | grep "Partition by:" | awk '{print $NF}'`

    if [ x"$partition_by" != "x" ]
    then
        output+=" PARTITION BY RANGE${partition_by}\n    (\n"

        for table in `sed -n '/Child tables:/,$p' $dt_file | grep ",$" | sed "s/Child tables: //g" | sed 's/^[[:space:]]*//g' | sed 's/,$//g'`
        do
            #ms_getujikaikei_positive_1_prt_p_1408
            #t_partition=`echo $table | awk `
            echo "PARTITION $table
        done
    fi
}
end_comment

### print the DDL ###
print_ddl()
{
    output+=";"

    echo "
###################################################
All done! the DDL based on \d+ file was like below:
###################################################
"
    echo -e "$output"
    unset $IFS
}

### Start to work ###

get_table_name
get_column
check_index
check_ao_table
check_distribution
#check_partition_table
print_ddl








