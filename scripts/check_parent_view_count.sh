#!/bin/bash

DB='gpadmin'
targetView='$1'

oid=`psql $DB -Atc "select '$targetView'::regclass::oid"`
echo "target oid is [$oid]"

find=0
getParentObject()
{
    targetOid=$1
    query="
SELECT a.refobjid,(select relkind from pg_class where oid = a.refobjid)  FROM
    pg_depend a,
    pg_depend b
WHERE  a.refclassid = 1259
       AND a.classid = 2618
       AND b.deptype = 'i'
       AND a.objid = b.objid
       AND a.classid = b.classid
       AND a.refclassid = b.refclassid
       AND a.refobjid <> b.refobjid
       AND b.refobjid=$targetOid;
"
    output=`psql $DB -Atc "$query"`
    findRelOid=`echo $output | awk -F'|' '{print $1}'`
    findRelkind=`echo $output | awk -F'|' '{print $2}'`

    echo "find [$findRelOid] with relkind [$findRelkind].."
    if [ "x$findRelkind" == 'xv' ]
    then
        find=$(($find+1))
        getParentObject $findRelOid 
    else
        echo -e "no more view, exit\n\n========="
    fi
}

getParentObject $oid
echo "the view [$targetView] has [$find] parent views"