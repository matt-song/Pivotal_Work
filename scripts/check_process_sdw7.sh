#!/bin/bash

### Checking kafaka processes ###
export PATH=$PATH:~/scripts:/opt/kafka_2.12-2.5.0/bin;
ZK_PID=`ps -ef | grep kafka | grep /opt/kafka_2.12-2.5.0/config/zookeeper.properties | grep -v grep | awk '{print $2}'`
KAFKA_PID=`ps -ef | grep kafka | grep /opt/kafka_2.12-2.5.0/config/server.properties  | grep -v grep  | awk '{print $2}'`

echo "=== Kakfa process list: ==="
[ "x$ZK_PID" == 'x' ] && echo "Zookeeper is not running" || echo "Zookeeper is running, pid: [$ZK_PID]"
[ "x$KAFKA_PID" == 'x' ] && echo "KAFKA is not running" || echo "KAFKA is running, pid: [$KAFKA_PID]"
echo ""

### checking hadoop processes ###
echo "=== Hadoop process list: ==="
for proc in NameNode DataNode SecondaryNameNode
do
    targetPid=`ps -ef | grep java | grep -w ${proc} |  awk '{print $2}'`
    [ "x$targetPid" == 'x' ] && echo "$proc is not running" || echo "$proc is running, pid: [$targetPid]"
done