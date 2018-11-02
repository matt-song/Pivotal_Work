#!/bin/bash
IFS=$'\n'

dt_file=$1; 
[ x"$dt_file" == x ] && echo "Usage: $0 [\d+ output]" && exit 1;

table_name=`cat $dt_file | grep Table | awk '{print $2}' | sed 's/"//g'`;

output="CREATE TABLE $table_name\n(\n";

for i in `cat $dt_file | grep '|' | grep -v Column`;
do
    name=`echo $i | awk -F'|' '{print $1}' | sed 's/[[:space:]]*$//g' | sed 's/^ //g'`
    type=`echo $i | awk -F'|' '{print $2}'| sed 's/[[:space:]]*$//g'| sed 's/^ //g'`
    modifier=`echo $i | awk -F'|' '{print $3}'| sed 's/[[:space:]]*$//g' | sed 's/^ //g'`

    output+="    $name $type ${modifier},\n"
done

### primary key ###
primary_key=`cat $dt_file | grep PRIMARY | awk -F"(" '{print $NF}' | sed 's/)//g'`

if [ x"$primary_key" != x ]
then
    output+="    PRIMARY KEY ($primary_key)\n"
fi
#output=`echo $output | sed 's/,$//g'`
output+=")\n"

### distribute by ###
distribute_by=`cat $dt_file | grep "Distributed by" | awk -F"(" '{print $NF}' | sed 's/)//g'`
if [ x"$distribute_by" != x ]
then
    output+="DISTRIBUTED BY ($distribute_by)"
fi

output+=";"

echo -e "$output"
unset $IFS
