echo "current gpss version"
gpss --version
echo "terminate the gpss"
ps -ef | grep gpss | grep -v grep | awk '{print $2}' | xargs kill
echo "remove gppkg package "
gppkg -r gpss-gpdb6
psql -c "drop extension gpss"


echo "install 1.10.4"
gppkg -i /data/packages/gpss-gpdb6-1.10.4-rhel7-x86_64.gppkg
echo "checking version"
gpss --version
psql -c "create extension gpss"


echo "start gpss"
nohup gpss ~/gpss/gpsscfg_ex.json --log-dir ./gpsslogs &
