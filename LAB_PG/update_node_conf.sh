#!/bin/bash

hostname=`hostname | awk -F'-' '{print $NF}'`

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
