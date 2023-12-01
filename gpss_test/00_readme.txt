### readme

1. run switch_to_xxx.sh to switch to target version of gpss
2. create the table if it does not exists: 

create extension dataflow
create role etl_user login;
alter role etl_user with password 'abc123';
ALTER ROLE etl_user CREATEEXTTABLE(type = 'readable', protocol = 'gpfdist');

CREATE TABLE public.gpss_from_kafka (
    id integer,
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
)
DISTRIBUTED RANDOMLY;

ALTER TABLE public.gpss_from_kafka OWNER TO etl_user;

3. add pg_hba.conf if not exists

echo "host    all   etl_user    192.168.6.0/24 md5" >> $MASTER_DATA_DIRECTORY/pg_hba.conf
gpstop -u

4. start the gpss job
