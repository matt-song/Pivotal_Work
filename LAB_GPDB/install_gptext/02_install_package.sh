#installFile="/data/packages/greenplum-text-3.4.2-rhel7_x86_64.bin"
installFile=$1
configFile="/data/package/install_gptext/gptext_install_config"

if [ !-f $installFile ]  
then
    echo "no such file [$installFile] !!!"  
    exit  1;
fi 

$installFile -c $configFile
