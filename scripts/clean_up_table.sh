#!/bin/bash
oid=$1
work_folder=/tmp/work/${oid}
sql_file=/tmp/work/${oid}/backup_and_drop_${oid}.sql
backup_folder=/tmp/work/${oid}/backup_`date +%s`

### usage: 
### 0. get the table name <schema.table>
### 1. find out the oid of the table and its index:  SELECT indexrelid, indrelid  from pg_index where indrelid = 'big_table_5013'::regclass::oid;
### 2. run the script against both oid.
### 3. delete the table oid in gp_distribution_policy on master  DELETE FROM gp_distribution_policy where localoid = 45374;
### 4. check the pg_depend table. get the full query from gpcheckcat -v output, then get the objid based on the result: SELECT * from pg_depend where objid = 20180;

[ x${oid} == 'x' ] && echo "usage $0 <OID>" && exit

echo "creating the work_folder [$work_folder]"
mkdir -pv $backup_folder 

echo "-- this script will backup and droping object which belongs to oid [${oid}]" > $sql_file

### show the content ###

echo "generating the sql to checking content of catalog table"
echo "-- check the content of catalog table" >> $sql_file
echo "SELECT * from pg_class where oid in (${oid});" >> $sql_file
echo "SELECT * from pg_attribute where attrelid in (${oid});" >> $sql_file
echo "SELECT * from pg_type where typrelid in ( ${oid} );" >> $sql_file
echo "SELECT * from pg_index where indrelid in ( ${oid} );" >> $sql_file

### backup the table ###
echo "generating the sql to backup the object"
echo "-- backup the catalog table" >> $sql_file
echo "copy (SELECT oid,* from pg_class where oid in (${oid}) ) to '${backup_folder}/pg_class.txt' ;" >> $sql_file
echo "copy (SELECT * from pg_attribute where attrelid in (${oid}) ) to '${backup_folder}/pg_attribute.txt' ;" >> $sql_file
echo "copy (SELECT oid,* from pg_type where typrelid in ( ${oid} ) ) to '${backup_folder}/pg_type.txt' ;" >> $sql_file
echo "copy (SELECT * from pg_index where indrelid in ( ${oid} ) ) to '${backup_folder}/pg_index.txt' ;" >> $sql_file

### delete the content 
echo "generating the sql to backup the object to delete the content"

echo "-- delete the objects belongs to oid [$oid]" >> $sql_file
echo "set allow_system_table_mods to dml;" >> $sql_file
echo "delete from pg_class where oid in (${oid});"  >> $sql_file
echo "delete from pg_attribute where attrelid in (${oid});" >> $sql_file
echo "delete from pg_type where typrelid in ( ${oid} );"  >> $sql_file
echo "delete from pg_index where indrelid in ( ${oid} );"  >> $sql_file