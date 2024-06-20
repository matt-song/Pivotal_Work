for host in pat1 pat2 pat3
do
    echo "terminating etcde on $host..."
#     ssh $host "ps -ef | grep etcd | grep yaml | grep -v grep"
    ssh $host "ps -ef | grep etcd | grep yaml | grep -v grep|  awk '{print \$2}' |  xargs kill"
    sleep 2
done
