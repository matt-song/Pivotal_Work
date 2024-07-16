#!/usr/bin/perl
=README 
#############################################################################
Author:         Matt Song
Creation Date:  2024.05.28

Features:
- Automatically set up a patroni cluster Postgres
- Work for vmware postgres only
- postgres user must have sudo privilege
- if failed, fix the error and re-run the script

Note:
- Assume there is no other postgres prodcut is running on same cluster, like pg_auto_failover.
- do not use this on pg_auto_ctl cluster, could skew things up!
- ETCD MUST enable v2! see: https://github.com/zalando/patroni/issues/2249

Workflow:
1. cleanup all the old rpm of postgres - this will remove everything on server include pg_auto_failover
2. install the ETCD on all host
3. install patroni on allhost

Others:
- will set below ENV:
    1. PATRONI_ETCD_HOSTS
    2. PATRONI_SCOPE
    2. PGDATA
    3. PATH

Update:
- N/A
#############################################################################
=cut

use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use File::Basename;

my %opts; getopts('hf:Dym:d:l:p:', \%opts);
my $haProxyHost = $opts{'m'};
my $dataNodeHosts = $opts{'d'};   ## will also include etcd
my $installationFile=$opts{'f'};
my $installationLibFile=$opts{'l'};
my $installationPatroniFile=$opts{'p'};
my $ALL_YES = $opts{'y'};
my $DEBUG = $opts{'D'};


#### please review and edit below settings if needed ###
my $pgUser = 'postgres';
my $patroniScope = 'patroni_cluster';
my $dataNodeDataFolder = "/data/database";
my $tempFolder = '/tmp';
my $workDir = "/tmp/setup_patroni.$$";
# my $PgAutoFailoverServiceConf = '/etc/systemd/system/pgautofailover.service';
my $bashrcInclude = "/home/postgres/.bashrc_patroni";
my $subNet = '10.216.2.0/24';


my $etcdVer = '3.4.32';
my $etcdDataFolder = '/data/etcd';
my $patroniFolder = '/data/patroni';
my $patroniYamlFile = "patroni.yml";

print_help() if $opts{'h'};

#### Start working ####

## Step01: check the input parameters
my $clusterInfo = doThePreCheck();

## Step02: clean up old pg autofailover cluster
cleanUp($clusterInfo);

## Step03: Setup ETCD
my $etcdUrl = setupETCD($clusterInfo);

## Step04: InstallPatroni
InstallPostgresRpm($clusterInfo);
InstallPatroni($clusterInfo,$etcdUrl);

## Step05: post installation, update bashrc
doPostInstallationTask($clusterInfo,$etcdUrl);


#### Functions ####

sub doPostInstallationTask
{
    my ($clusterInfo,$etcdUrl) = @_;
    my $path = "/opt/vmware/postgres/$clusterInfo->{'majorVer'}/bin";

    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {updateBashrc($_, $dataNodeDataFolder); };

    ## checking if we have ~/.bashrc updated
    sub updateBashrc
    {
        my ($host,$pgdata) = @_;
        ECHO_INFO("Update bashrc file for host [$host]...");
        my $cmd_CheckBashrc = qq(cat ~/.bashrc | grep $bashrcInclude | grep -w "\." |wc -l);
        my $result = run_command(qq(ssh ${pgUser}\@$host "$cmd_CheckBashrc"),1);

        my $content=qq(echo -e 'export PATRONI_ETCD_HOSTS=$etcdUrl\\nexport PATRONI_SCOPE=$patroniScope\\nexport PGDATA=$pgdata\\nexport PATH='$path':\\\$PATH' > $bashrcInclude);

        if ($result->{'output'} >= 1)
        {
            #my $content = qq(echo -e 'export PATRONI_CONFIGURATION=$patroniFolder/$patroniYamlFile\\nexport PGDATA=$pgdata\\nexport PATH='$path':\\\$PATH' > $bashrcInclude);
            run_command(qq(ssh ${pgUser}\@$host "$content"),1); 
        }
        else
        {
            my $contentBashrc = qq(echo -e '### Patroni environment\\nif [ -f $bashrcInclude ]; then\\n    . $bashrcInclude\\nfi' >> ~/.bashrc); 
            run_command(qq(ssh ${pgUser}\@$host "$contentBashrc"),1); 
            # my $contentExtraBashrc = qq(echo -e 'export PATRONI_CONFIGURATION=$patroniFolder/$patroniYamlFile\\nexport PGDATA=$pgdata\\nexport PATH='$path':\\\$PATH' > $bashrcInclude);
            run_command(qq(ssh ${pgUser}\@$host "$content"),1); 
        }
    }
}

sub InstallPatroni
{
    my ($clusterInfo,$etcdHostList) = @_;

    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) 
    {
        setupDependency($dataNode);
        setupPatroni($dataNode);
        startPatroni($dataNode, $clusterInfo->{'majorVer'})
    }
    sleep(5); ## wait for all node sync up
    verifyPatroni((split(/,/,$clusterInfo->{'dataNodeList'}))[0], $clusterInfo->{'majorVer'});

    ## end ##

    sub verifyPatroni
    {
        my ($host,$ver) = @_;
        ECHO_INFO("Installation finished, verifying the cluster state...");
        my $result = run_command(qq(ssh ${pgUser}\@${host} "/opt/vmware/postgres/$ver/bin/patronictl -c $patroniFolder/$patroniYamlFile list"));
        ECHO_SYSTEM($result->{'output'});
    }
    sub startPatroni
    {

        my ($host,$ver) = @_;
        my $cmdStartPartoni = qq(export PATH=\\\$PATH:/opt/vmware/postgres/$ver/bin; nohup patroni $patroniFolder/$patroniYamlFile > $patroniFolder/patroni.log 2>&1  &);
        run_command(qq(ssh ${pgUser}\@${host} "$cmdStartPartoni"),1);
        my $processCount = run_command(qq(ssh ${pgUser}\@${host}  "ps -ef | grep patroni | grep python | grep -v grep | wc -l"));
        if ($processCount == 0) 
        {
            ECHO_ERROR("Failed to start Patroni on host [$host]",1);
        }
        my $retry = 5;
        for my $i (1..$retry)
        {
            my $isReady = run_command(qq(ssh ${pgUser}\@${host}  "/opt/vmware/postgres/$ver/bin/pg_isready |grep -w 'accepting connections' | wc -l"),1);
            if ($isReady->{'output'} = 0)
            {
                ECHO_SYSTEM("Postgres on [$host] has not ready yet, will wait and retry");
                sleep(5);
            }else{
                ECHO_INFO("Postgres on [$host] has ready");
                last;
            }
            $i++;
            if ($i == $retry)
            {
                ECHO_ERROR("Reached maxium retry count, postgres not ready yet, please check the logs and retry",1);
            }
        }
    }
    
    sub setupPatroni
    {
         my $host = shift;
         my $patroniYaml = qq(
scope: $patroniScope
name: $host
restapi:
  listen: '$host:8008'
  connect_address: '$host:8008'
etcd:
  hosts: '$etcdHostList'
bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        hot_standby: 'on'
        wal_keep_segments: 20
        max_wal_senders: 8
        max_replication_slots: 8
        log_destination: csvlog
        log_directory: log
        log_statement: all
        logging_collector: on
    slots:
      patroni_standby_leader:
        type: physical
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator $subNet md5
    - host all all $subNet trust
  users:
    admin:
      password: abc123
      options:
        - createrole
        - createdb
postgresql:
  listen: '$host:5432'
  connect_address: '$host:5432'
  data_dir: $dataNodeDataFolder
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: rep-pass
    superuser:
      username: postgres
      password: postgres
    rewind:
      username: rewind_user
      password: rewind_password
tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
         );
    ECHO_INFO("Generating paroni config file for host [$host]...");
    open YAMLFILE,'>',"$workDir/$patroniYamlFile" or die {ECHO_ERROR("Failed to write into temp patroni config file [$workDir/etcd_config.yaml]",1)};
    print YAMLFILE $patroniYaml;
    close YAMLFILE;
    my $cmd_scpYamlFile = qq(scp $workDir/$patroniYamlFile ${pgUser}\@${host}:${patroniFolder}/${patroniYamlFile});
    run_command($cmd_scpYamlFile,1);
    }
    
    sub setupDependency
    {
        my $host = shift;

        ECHO_INFO("Installing python on host [$host]...");
        my $yumCMD = qq(sudo yum install -y python3 python3-devel gcc);
        run_command(qq(ssh ${pgUser}\@${host} "$yumCMD"),1);

        ECHO_INFO("Installing python package on host [$host]...");
        open requirements,'>',"$workDir/requirements.txt"  or die {ECHO_ERROR("Failed to write into temp file [$workDir/requirements.txt]",1)};
        my $requirementsFile = qq(
PyYAML
click>=4.1
prettytable>=0.7
psutil>=2.0.0
python-dateutil
python-etcd>=0.4.3,<0.5
requests
six >= 1.7
urllib3>=1.19.1,!=1.21
ydiff>=1.2.0
cdiff
        );
        print requirements $requirementsFile;
        close requirements;
        my $cmd_scpRequirementsFile = qq(scp $workDir/requirements.txt ${pgUser}\@${host}:${tempFolder});
        run_command($cmd_scpRequirementsFile,1);
        # my $cmd_installRpm = qq(sudo yum -y install ${tempFolder}/$rpm);
        run_command(qq(ssh ${pgUser}\@${host} "pip3 install --user -r ${tempFolder}/requirements.txt"),1);
        ## clean up the temp installation file 
        run_command(qq(ssh ${pgUser}\@${host} "[ -f ${tempFolder}/requirements.txt ] && rm -f ${tempFolder}/requirements.txt || echo 'file not found [${tempFolder}/requirements.txt], skip' "),1);
    }
}


## Install Patroni, refer to https://docs.vmware.com/en/VMware-Postgres/16.2/vmware-postgres/bp-patroni-setup.html
sub InstallPostgresRpm
{
    my $clusterInfo = shift;

    ### install RPM on all host ###
    ### TBD: if v16, need install  vmware-postgres16-libs-16.3-1.el8.x86_64.rpm first
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) 
    {
        if ($clusterInfo->{'majorVer'} >= 16)
        {
            installRpm($dataNode, $installationLibFile);
        }
        installRpm($dataNode, $installationFile);
        installRpm($dataNode, $installationPatroniFile);
    };

    sub installRpm
    {
        my ($host, $rpm)= @_;
        ECHO_INFO(qq(Copying [$rpm] to server [$host]'s [$tempFolder]...));
        my $cmd_scpFile = qq(scp $rpm ${pgUser}\@${host}:${tempFolder});
        run_command($cmd_scpFile,1);

        ECHO_INFO(qq(Installing [$rpm] on server [$host]...));
        my $cmd_installRpm = qq(sudo yum -y install ${tempFolder}/$rpm);
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_installRpm"),1);

        ## clean up the temp installation file 
        run_command(qq(ssh ${pgUser}\@${host} "[ -f ${tempFolder}/$rpm ] && rm -f ${tempFolder}/$rpm || echo 'file not found [${tempFolder}/$rpm], skip' "),1);
    }
}

## Setup ETCD: refer to https://github.com/etcd-io/etcd/releases and https://etcd.io/docs/v3.5/op-guide/clustering/
sub setupETCD
{
    my $clusterInfo = shift;
    my $DownloadURL=qq(https://github.com/etcd-io/etcd/releases/download/v${etcdVer}/etcd-v${etcdVer}-linux-amd64.tar.gz);
    my $curlCMD = qq(curl -L -s ${DownloadURL} -o $workDir/etcd-v${etcdVer}-linux-amd64.tar.gz);
    ECHO_INFO("Downloading the etcd binary with version [$etcdVer], URL: $DownloadURL");
    run_command($curlCMD,1);

    ### Install ETCD ###
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) { installETCD($dataNode) } ;
    
    ### Setup ETCD, if we had odd number of nodes, then install etcd on each node
    ## if not odd number, then install etcd on single node.
    my $nodeCount = scalar (split(/,/,$clusterInfo->{'dataNodeList'}));   
    if ($nodeCount % 2 != 0 )
    {
        ### Generate initial-cluster settings for ETCD
        my $settings_initialcluster = "initial-cluster: '";
        foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) { $settings_initialcluster .= qq($dataNode=http://$dataNode:2380,); }
        $settings_initialcluster =~ s/,$/'/;
        ECHO_DEBUG("the settings_initialcluster is [$settings_initialcluster]");

        foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'}))
        {
            cleanUpOldEtcdFolder($dataNode);
            configETCD($dataNode, $settings_initialcluster);
        }
    }else{
        ## TDB
        ECHO_ERROR("Must have odd number of nodes, we do not support non-odd number yet, TDB",1);
    }

    ### start ETCD ###
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) { startETCD($dataNode); }

    ### validate ###
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'}))
    {
        ECHO_INFO("Validating the etcd on host [$dataNode]...");
        my $cmd_validate = qq(etcdctl --endpoints=http://$dataNode:2380 endpoint health);
        run_command(qq(ssh ${pgUser}\@${dataNode} "$cmd_validate" ),1);
    }
    ECHO_INFO("All good, the ETCD cluster is now ready to use, summary: ");
    my $etcdNode=(split(/,/,$clusterInfo->{'dataNodeList'}))[0];
    my $cmd_etcdCluster = qq(etcdctl endpoint status --write-out=table --endpoints=http://$etcdNode:2379 --cluster);
    my $result = run_command(qq(ssh ${pgUser}\@${etcdNode} "$cmd_etcdCluster" ),1);
    ECHO_SYSTEM($result->{'output'});

    ## generate etcd url: 'pat1:2379,pat2:2379,pat3:2379'
    my $etcdUrl = '';
    foreach my $node (split(/,/,$clusterInfo->{'dataNodeList'}))
    {
        $etcdUrl .= "${node}:2379,"
    }
    $etcdUrl =~ s/,$//;
    # ECHO_SYSTEM($etcdUrl);
    return $etcdUrl;


    sub installETCD
    {
        my $host = shift;
        ## check if the etcd has been installed
        my $cmd_getCurrentEtcdVer = qq(etcd --version 2>&1 | grep 'etcd Version:' | awk '{print \\\$3}');
        my $curEtcdVer = run_command(qq(ssh ${pgUser}\@${host} "$cmd_getCurrentEtcdVer" ),1);
        ECHO_DEBUG("Current version of ETCD is [$curEtcdVer->{'output'}]");
        
        if ($curEtcdVer->{'output'} eq $etcdVer)
        {
            ECHO_INFO("ETCD with version [$etcdVer] on host [$host] has already been installed, skip");
        }
        else
        {
            my $cmd_scpBinary = qq(scp $workDir/etcd-v${etcdVer}-linux-amd64.tar.gz ${pgUser}\@${host}:$tempFolder);
            run_command($cmd_scpBinary);

            my $cmd_decompress_tar = qq(sudo tar zxf $tempFolder/etcd-v${etcdVer}-linux-amd64.tar.gz -C $tempFolder);
            run_command(qq(ssh ${pgUser}\@${host} "$cmd_decompress_tar" ),1);

            my $cmd_cpEtcdBinary = qq(sudo cp -rp $tempFolder/etcd-v${etcdVer}-linux-amd64/etcd* /usr/local/bin/);
            run_command(qq(ssh ${pgUser}\@${host} "$cmd_cpEtcdBinary" ),1);
            
            my $installedEtcdVer = run_command(qq(ssh ${pgUser}\@${host} "$cmd_getCurrentEtcdVer" ),1);
            
            ECHO_ERROR(qq(Failed to install ETCD with version [$etcdVer] on host [$host], detected version is [$installedEtcdVer->{'output'}], review the logs and try again),1) if ($installedEtcdVer->{'output'} ne $etcdVer);
        }
    }
    sub cleanUpOldEtcdFolder 
    {
        my $host = shift;
        ECHO_INFO("Cleanup old ETCD data on server [$host]...");
        my $isEtcdStarted = run_command(qq(ssh ${pgUser}\@${host}  "ps -ef | grep etcd | grep -v grep | wc -l"),1);
        if ($isEtcdStarted->{'output'} gt 0)
        {
            ECHO_INFO("Found old ETCD process on [$host], stopping it first...");
            run_command(qq(ssh ${pgUser}\@${host} "sudo killall etcd"),1);
        }

        my $cmd_CleanOldEtcdDataFolder = qq(sudo rm -rf $etcdDataFolder &&  sudo mkdir -p $etcdDataFolder/{conf,logs} && sudo chown -R postgres:postgres $etcdDataFolder);
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_CleanOldEtcdDataFolder"),1 );
    }
    sub configETCD
    # refer to https://github.com/etcd-io/etcd/blob/main/etcd.conf.yml.sample
    {
        my ($host,$initialcluster) = @_;      
        ECHO_INFO("Creating ETCD config file on host [$host]...");

        my $ipAddr = run_command( qq(ssh ${pgUser}\@${host} "ping -c 1 $host  | grep from | awk '{print \\\$5}' | sed 's/(//g' | sed 's/)://g'"),1);

        open ETCD_CONF,'>',"$workDir/etcd_config.yaml" or die {ECHO_ERROR("Failed to write into temp etcd config file [$workDir/etcd_config.yaml]",1)};
        my $etcdConfig = qq(
name: $host
listen-peer-urls: 'http://$ipAddr->{'output'}:2380'
listen-client-urls: 'http://$ipAddr->{'output'}:2379,http://127.0.0.1:2379'
initial-advertise-peer-urls: 'http://$host:2380'
advertise-client-urls: 'http://$host:2379'

$initialcluster
initial-cluster-state: 'new'
initial-cluster-token: 'etcd-cluster'

enable-v2: true
data-dir: $etcdDataFolder
);
    print ETCD_CONF $etcdConfig;
    close ETCD_CONF;
    ECHO_DEBUG("the config on host [$host] is \n $etcdConfig");
    run_command("scp $workDir/etcd_config.yaml ${pgUser}\@${host}:$etcdDataFolder/conf",1);
    
    }

    sub startETCD
    {
        my $host = shift;    
        ECHO_INFO("Starting ETCD on host [$host]...");
        my $restartCMD = qq(nohup etcd --config-file $etcdDataFolder/conf/etcd_config.yaml > $etcdDataFolder/logs/etcd.log 2>&1 &);
        run_command(qq(ssh ${pgUser}\@${host} "$restartCMD" ),1);
    }
}


sub doThePreCheck
{
    my $clusterInfo = {};

    print_help("Can not find target rpm file [$installationFile]!") unless ( -f $installationFile);
    print_help("Can not find target patroni rpm file [$installationPatroniFile]!") unless ( -f $installationPatroniFile);
    print_help("please HA proxy's hostname!") if (! $haProxyHost);
    print_help("please input data node's hostname!") if (! $dataNodeHosts);
    ECHO_INFO("Creating work directory [$workDir]");
    run_command("mkdir -p $workDir",1);  ## create work dir

    $clusterInfo->{'dataNodeList'} =  $dataNodeHosts;
    $clusterInfo->{'haProxyHost'} =  $haProxyHost;
    $clusterInfo->{'package'} = basename($installationFile);
    # $clusterInfo->{'patroniPackage'} = $installationPatroniFile;
    

    if ($clusterInfo->{'package'} =~ /^vmware-postgres(\d*)-(\d+\.\d+)-\d.*rpm$/)
    {
        $clusterInfo->{'majorVer'}=$1;  
        $clusterInfo->{'pgVersion'}=$2;
    }
    else
    {
        ECHO_ERROR("Unable to determine the version of postgres, please check the file and try again", 1);
    }

    ### In PG16 we must install lib first
    if ($clusterInfo->{'majorVer'} >= 16)
    {
        ECHO_ERROR("We are installing VMware PG >= 16, must install vmware-postgres*-libs-*.rpm first!, please assign the correct package location with -l ",1) unless (-f $installationLibFile);
=remove
        if( -f $installationLibFile )
        {
            $clusterInfo->{'libPackage'} =  $installationLibFile;
        }
        else
        {
            ECHO_ERROR("We are installing VMware PG >= 16, must install vmware-postgres*-libs-*.rpm first!, please assign the correct package location with -l ",1)
        }
=cut
    }

    ECHO_SYSTEM("
##############################################
PG_AUTO_FAILOVER Cluster Installation Summary: 
##############################################

Installation source:

    VmwarePostgres:    \t$installationFile
    LibPackage:        \t$installationLibFile
    PatroniPackage:    \t$installationPatroniFile

Cluster settings:

    Target Version:    \t[$clusterInfo->{'pgVersion'}]
    HA proxy host:     \t[$haProxyHost]
    DataNode host:     \t[$clusterInfo->{'dataNodeList'}]
    ETCD host:         \t[$clusterInfo->{'dataNodeList'}]
    DataNode's PGDATA: \t[$dataNodeDataFolder]

!!! WARNNING !!!
Once you choose to continue, We will delete all the content in above folder.
There is NO ROLLBACK! Please proceed with cautions!
");
    user_confirm("Do you want continue? <yes/no>");
    print Dumper $clusterInfo if $DEBUG;
    return $clusterInfo;
}

sub cleanUp
{
    my $clusterInfo = shift;
    my $sshTimeout = 3;
    
    testSudo($clusterInfo->{'haProxyHost'});
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {testSudo($_);};
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {cleanOldPatroni($_);};
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {removeOldRPM($_);};
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {deleteOldPgDataFolder($_, $dataNodeDataFolder );};

    
    ## check if the host is able to connect and able to sudo
    sub testSudo
    {
        my $host = shift;
        ECHO_INFO("testing if we have sudo privilege on host [$host]...");
        run_command(qq(ssh -o ConnectTimeout=$sshTimeout -o StrictHostKeyChecking=no ${pgUser}\@${host} "sudo uptime"), 1);
    }
    
    ## clean up all old patroni process
    sub cleanOldPatroni
    {
        my $host = shift;
        ECHO_INFO("Cleaning up old patroni settings and files...");
        my $processCount = run_command(qq(ssh ${pgUser}\@${host}  "ps -ef | grep patroni | grep python | grep -v grep | wc -l"));
        if ($processCount->{'output'} > 0)
        {
            run_command(qq(ssh ${pgUser}\@${host}  "ps -ef | grep patroni | grep python | grep -v grep | awk '{print \\\$2}' | xargs kill"),1);
            sleep(2);
            my $newProcessCount = run_command(qq(ssh ${pgUser}\@${host}  "ps -ef | grep patroni | grep python | grep -v grep | wc -l"),1);
            if ($newProcessCount->{'output'} > 0)
            {
                ECHO_ERROR('Failed to terminated the old patroni process, please check and try again!',1 ) if ($newProcessCount != 0);
            }
        }
        ### Recreate folder:
        my $cmdDeleteDir = qq( [ -d $patroniFolder ] && rm -rf $patroniFolder || echo "No such folder [$patroniFolder], skip...");
        run_command(qq(ssh ${pgUser}\@${host} "$cmdDeleteDir"),1);
        run_command(qq(ssh ${pgUser}\@${host} "mkdir -p $patroniFolder"),1);
        
    }
    sub removeOldRPM
    {
        my $host = shift;
        ECHO_INFO("Clean up old postgres package on host [$host]...");
        
        my $checkCountCMD = qq(sudo yum list| grep "^vmware-postgres" | grep -v grep | wc -l);
        my $packageCount = run_command(qq(ssh ${pgUser}\@${host} "$checkCountCMD"),1);
        if ($packageCount->{'output'} > 0)
        {
            my $cmdYumRemove = qq(sudo yum list| grep "^vmware-postgres" | awk '{print \\\$1}' | xargs sudo  yum -y remove);
            run_command(qq(ssh ${pgUser}\@${host} "$cmdYumRemove"),1);
            my $newPackageCount =  run_command(qq(ssh ${pgUser}\@${host} "$checkCountCMD"),1);
            ECHO_ERROR("Failed to clean up old vmware postgres package!",1) if ($newPackageCount->{'output'} > 0);
        }
    }    
    sub deleteOldPgDataFolder
    {
        my ($host, $folder) = @_;
        ECHO_INFO("Deleting PGDATA [$folder] on host [$host]...");
        my $cmd_DeletePGData = qq([ -d $folder ] && sudo rm -rf $folder || echo "no such folder [$folder], skip");
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_DeletePGData"),1 );
    }
}

sub print_help
{
    my $err = shift;
    ECHO_ERROR("$err") if ($err);
    ECHO_SYSTEM("
Usage:   $0 -f <installation file> -m <ha proxy hostname> -d <datanode1, datanode2, ...> -p <patroni rpm> -l <lib rpm>
Example:
    -- if we put all package in same folder
    $0 -f vmware-postgres15-15.2-1.el7.x86_64.rpm -m haproxy -d node1,node2,node3

    -- if we did not put all package in same folder
    $0 -f /path/to/vmware-postgres16-16.3-1.el8.x86_64.rpm -m haproxy -d node1,node2,node3 -l /path/to/vmware-postgres16-libs-16.3-1.el8.x86_64.rpm -p /path/to/vmware-postgres16-patroni-3.3.0-1.el8.x86_64.rpm
    
    -- if install version >= 16, then must assign the lib package's location, for example:
    $0 -f vmware-postgres16-16.3-1.el8.x86_64.rpm -m haproxy -d node1,node2,node3 -l vmware-postgres16-libs-16.3-1.el8.x86_64.rpm

Parameters:

    -f [vmware postgres installation file]
    -m ha proxy node
    -d datanode list, separate with comma
    -h print this message
    -D enable debug mode
    -y answer yes automatically
    -l the package of postgres lib, for example: vmware-postgres16-libs-16.3-1.el8.x86_64.rpm
    -p the package of patroni installion rpm, for example: vmware-postgres16-patroni-3.3.0-1.el8.x86_64.rpm
");
    exit 1;
}

sub run_command
{
    my ($cmd, $err_out) = @_;
    my $run_info;
    $run_info->{'cmd'} = $cmd;

    ECHO_DEBUG("will run command [$cmd]..");
    chomp(my $result = `$cmd 2>&1` );
    my $rc = "$?";
    ECHO_DEBUG("Return code [$rc], Result is [$result]");

    $run_info->{'code'} = $rc;
    $run_info->{'output'} = $result;

    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is $rc");
        ECHO_ERROR("ERROR: [$run_info->{'output'}]", $err_out);
    }
    else
    {
        ECHO_DEBUG("Command excute successfully, return code is [$rc]");
        ECHO_DEBUG("The result is [$run_info->{'output'}]");
    }
    return $run_info;

}

sub user_confirm
{
    my $msg = shift;

    my $input;
    if ($ALL_YES)
    {
        $input = 'yes';
    }
    else
    {
        ECHO_SYSTEM("\n$msg");
        $input = (<STDIN>);
    }

    if ($input =~ /no|n/i)
    {
        ECHO_ERROR("Cancelled by user, exit!", 1);
    }
    elsif ($input =~ /yes|y/i)
    {
        return 0;
    }
    else
    {
        ECHO_ERROR("Please input 'yes' or 'no'!");
        &user_confirm($msg);
    }
}

### define function to make the world more beautiful ###
sub ECHO_SYSTEM
{
    my ($message) = @_;
    printColor('yellow',"$message"."\n");
}
sub ECHO_DEBUG
{
    my ($message) = @_;
    printColor('cyan',"[DEBUG] $message"."\n") if $DEBUG;
}
sub ECHO_INFO
{
    my ($message, $no_return) = @_;
    printColor('green',"[INFO] $message");
    print "\n" if (!$no_return);
}
sub ECHO_ERROR
{
    my ($Message,$ErrorOut) = @_;
    printColor('red',"[ERROR] $Message"."\n");
    if ($ErrorOut == 1)
    {
        ECHO_INFO("Removing the working directory [$workDir]");
        run_command("rm -rf $workDir",1) if ( -d $workDir);
        exit(1);
    }
    else{return 1;}
}
sub printColor
{
    my ($Color,$MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}