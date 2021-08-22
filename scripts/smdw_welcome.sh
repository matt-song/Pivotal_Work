#!/bin/bash

## color variables
green="\e[1;32m"
normal="\e[0m"
Blcyan="\e[1;96m"
cyan="\e[36m"
yellow="\e[33m"

ECHO_GREEN()
{
    message=$1
    echo -e "${green}${message}${normal}"
}
ECHO_LightCyan()
{
    message=$1
    echo -e "${Blcyan}${message}${normal}"
}
ECHO_Cyan()
{
    message=$1
    echo -e "${cyan}${message}${normal}"
}
ECHO_Yellow()
{
    message=$1
    echo -e "${yellow}${message}${normal}"
}


title=`figlet -w 1000  "Welcome to Shanghai LAB"`

ECHO_GREEN "${title}"

ECHO_LightCyan "########### Some tips ###########\n"

ECHO_LightCyan "- To list all installed GPDB status"
ECHO_Cyan "  # bash ~/scripts/list_gpdb_status.sh\n"

ECHO_LightCyan "- To switch gpdb build:"
ECHO_Cyan "  # gpdb\n"

ECHO_LightCyan "- To download a new gpdb installation package:"
ECHO_Cyan "  # bash  ~/scripts/download_gpdb.sh\n"

ECHO_LightCyan "- To install a new build of gpdb:"
ECHO_Cyan "  # perl ~/scripts/install_gpdb.pl -f ~/packages/greenplum-db-4.3.31.0-rhel5-x86_64.zip\n"

ECHO_LightCyan "- To uninstall a build of gpdb:"
ECHO_Cyan "  # bash ~/scripts/uninstall_GPDB.sh\n"

ECHO_LightCyan "- To check the space usage for each cluster"
ECHO_Cyan "  # bash ~/scripts/list_gpdb_status.sh -f\n"

ECHO_LightCyan "- GPTEXT INFO"
ECHO_Cyan "  1. run #gpdb then choose 6.12.1\n  2. # source /opt/greenplum-text-3.5.0/greenplum-text_path.sh\n  3. use DB [demo] to test the index\n"

ECHO_LightCyan "- HDFS INFO: "
ECHO_Cyan "  host: sdw7 (172.28.8.7)\n  port: 9000\n  example: /opt/hadoop-3.3.0/bin/hdfs dfs -ls hdfs://sdw7:9000/\n"

ECHO_LightCyan "- Kerberos INFO: "
ECHO_Cyan "  host: sdw7 (172.28.8.7)\n  config file: /etc/krb5.conf\n  keytab: /opt/pxf-5.14.0/greenplum-pxf/keytabs/nn.service.keytab\n  principal for hdfs: nn/hdfs@lab.vmware.com\n  to test: # kinit -kt /etc/security/keytab/nn.service.keytab nn/hdfs\n"

ECHO_LightCyan "- PXF INFO: "
ECHO_Cyan "  1. run [# gpdb], then select 6.10\n  2. check if pxf is started [# pxf cluster status], if not, start it via [# pxf cluster start]\n"

ECHO_LightCyan "- PATRONI INFO: "   ##Added by Jimmy 20200830
ECHO_Cyan "  1. switch to user postgres [# sudo su - postgres]\n  2. check cluster status [# patronictl -c /var/lib/pgsql/patroni_etcd_conf.d/postgres_member1.yaml list]\n  3. configuration files are located in /var/lib/pgsql/patroni_etcd_conf.d\n  4. patroni doc: https://patroni.readthedocs.io/en/latest/SETTINGS.html\n"

ECHO_Yellow "Important: Please do not remove the file [all_segment_hosts.txt] and [all_hosts.txt] under gpadmin's home folder, it was required by above scripts\n"