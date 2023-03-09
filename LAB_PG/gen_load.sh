#!/bin/bash

tableName="test_table_$RANDOM"

hostList="node1 node2 node3"
for host in $hostList; 
do
    isReadOnly=`ssh postgres@$host "psql -Atc 'show transaction_read_only;'"`
    ## echo "host [$host] read only state is [$isReadOnly]"
    if [ "x$isReadOnly" = 'xoff' ]
    then
        echo "Find primary host [$host], start loading data"
        echo -n ">> "; ssh $host "psql -c 'create table $tableName as select generate_series(1,10000); ' "
        echo -n ">> "; ssh $host "psql -c 'drop table if exists $tableName;'"
        echo "Done"
    fi
done 