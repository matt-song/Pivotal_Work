etcdDataFolder=/data/etcd
for host in pat1 pat2 pat3
do
  count=`ssh $host " ps -ef | grep etcd | grep yaml | grep -v grep | wc -l"`
  if [ "x$count" = 'x0' ]
  then
    echo "start etcd on host $host..."
    ssh $host "nohup etcd --config-file $etcdDataFolder/conf/etcd_config.yaml > $etcdDataFolder/logs/etcd.log 2>&1 &"
  else
    echo "etcd on $host already started, skip"
  fi
done
