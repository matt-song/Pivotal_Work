#!/bin/bash

hostname=`hostname | awk -F'-' '{print $NF}'`
PGDATA="/data/postgresql/$hostname"

### drop the node on monitor
ssh monitor "pg_autoctl drop node --hostname $hostname --pgport 5432 --force"

### cleanup the conf and data folder
sudo systemctl stop pgautofailover
rm -rf $PGDATA ~/.local ~/.config

### add the node
pg_autoctl create postgres     --pgdata $PGDATA     --auth trust     --ssl-self-signed     --username postgres     --hostname $hostname     --pgctl /opt/vmware/postgres/13/bin/pg_ctl     --monitor 'postgres://autoctl_node@monitor:5432/pg_auto_failover?sslmode=require'     --dbname matt
sudo systemctl start pgautofailover

### update metadata and priority
nodeID=`echo $hostname |sed 's/node//g'`
echo "Seting the node name to node_${nodeID}..."
pg_autoctl set node metadata  --name node_$nodeID

priority=$((100 - $nodeID * 10))
echo "Seting the priority to ${priority}..."
ssh monitor "pg_autoctl set node candidate-priority $priority --name node_$nodeID"

### check the result
pg_autoctl show state
pg_autoctl show settings
