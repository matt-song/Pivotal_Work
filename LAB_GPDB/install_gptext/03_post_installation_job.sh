#!/bin/bash

GP_PATH="/opt/greenplum_6.11.1/greenplum_path.sh"
GPTEXT_PATH="/opt/greenplum-text-3.5.0/greenplum-text_path.sh"
DB='demo'

source $GP_PATH
source $GPTEXT_PATH
# If you are using Greenplum Database 4.3.x or 5.x, you must first declare the GPText custom variable class by adding it to the Greenplum Database custom_variable_classes configuration parameter. The custom_variable_classes parameter is removed in Greenplum Database 6, so this step is unnecessary if you have Greenplum Database 6
GP_FAMILY=` psql -c 'select version()' | grep "Greenplum Database" | awk -F'Greenplum Database' '{print $2}' | awk '{print $1}' | sed 's/\..*//g'` 
if [ "x$GP_FAMILY" == 'x4' ] || [ "x$GP_FAMILY" == 'x5' ]
then
    gpconfig -c custom_variable_classes -v 'gptext'
fi

gptext-installsql $DB
echo "verifying the version..."
psql $DB -c "SELECT gptext.version();"

zkManager start
gptext-start
