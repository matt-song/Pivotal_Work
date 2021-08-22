id=`echo $RANDOM`
db=$1
count=$2

[ "x$db" == 'x' ] && echo "usage $0 [db] [count]" && exit 1;
[ "x$count" == 'x' ] && count=10000

psql $db -c "create table big_table_$id (
    id int,
    c1 text,
    c2 text,
    c3 text,
    c4 text,
    c5 text,
    c6 text,
    c7 text,
    c8 text,
    c9 text,
    c10 text,
    c11 text,
    c12 text,
    c13 text,
    c14 text,
    c15 text
) with (appendonly = true) distributed by (id);"

/home/gpadmin/mockd-linux greenplum -t big_table_$id -u gpadmin -d $db -p $PGPORT -n $count
