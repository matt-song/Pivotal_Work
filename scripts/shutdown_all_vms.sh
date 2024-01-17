for host in `vmlist | grep RUNNING | awk '{print $1}'`; do vmstop $host ;done
