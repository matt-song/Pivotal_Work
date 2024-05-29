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

Workflow:
1. cleanup all the old rpm of postgres - this will remove everything on server include pg_auto_failover
2. install HA proxy on monitor node
3. install the ETCD on all host
4. install patroni on allhost

Update:
- N/A
#############################################################################
=cut

use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use File::Basename;

my %opts; getopts('hf:Dym:d:', \%opts);
my $haProxyHost = $opts{'m'};
my $dataNodeHosts = $opts{'d'};   ## will also include etcd
my $installationFile=$opts{'f'};
my $ALL_YES = $opts{'y'};
my $DEBUG = $opts{'D'};

#### please review and edit below settings if needed ###
my $pgUser = 'postgres';
my $dataNodeDataFolder = "/data/database";
my $tempFolder = '/tmp';
my $workDir = "/tmp/setup_patroni.$$";
# my $PgAutoFailoverServiceConf = '/etc/systemd/system/pgautofailover.service';
my $bashrcInclude = "/home/postgres/.bashrc_patroni";

my $etcdVer = '3.4.32';
my $etcdDataFolder = '/data/etcd';

print_help() if $opts{'h'};

#### Start working ####

## Step01: check the input parameters
my $clusterInfo = doThePreCheck();

## Step02: clean up old pg autofailover cluster
cleanUp($clusterInfo);

## Step03: Setup ETCD
setupETCD($clusterInfo);




 
#### Functions ####

## Setup ETCD: refer to https://github.com/etcd-io/etcd/releases and https://etcd.io/docs/v3.5/op-guide/clustering/
sub setupETCD
{
    my $clusterInfo = shift;
    my $DownloadURL=qq(https://github.com/etcd-io/etcd/releases/download/v${etcdVer}/etcd-v${etcdVer}-linux-amd64.tar.gz);
    my $curlCMD = qq(curl -L -s ${DownloadURL} -o $workDir/etcd-v${etcdVer}-linux-amd64.tar.gz);
    ECHO_INFO("Downloading the etcd binary with version [$etcdVer], URL: $DownloadURL");
    run_command($curlCMD,1);

    ### Install ETCD ###
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'}))
    {
        installETCD($dataNode) ;
    }
    
    ### Setup ETCD, if we had odd number of nodes, then install etcd on each node
    ## if not odd number, then install etcd on single node.
    my $nodeCount = scalar (split(/,/,$clusterInfo->{'dataNodeList'}));   
    if ($nodeCount % 2 != 0 )
    {
        my $settings_initialcluster = "initial-cluster: '";
        foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'}))
        {
            $settings_initialcluster .= qq($dataNode=http://$dataNode:2380,);
        }
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
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'}))
    {
        startETCD($dataNode) ;
    }

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

    print_help("Can not find target rpm file [#installationFile]!") unless ( -f $installationFile);
    print_help("please HA proxy's hostname!") if (! $haProxyHost);
    print_help("please input data node's hostname!") if (! $dataNodeHosts);
    ECHO_INFO("Creating work directory [$workDir]");
    run_command("mkdir -p $workDir",1);  ## create work dir

    $clusterInfo->{'dataNodeList'} =  $dataNodeHosts;
    $clusterInfo->{'haProxyHost'} =  $haProxyHost;
    $clusterInfo->{'package'} = basename($installationFile);

    if ($clusterInfo->{'package'} =~ /^vmware-postgres(\d*)-(\d+\.\d+)-\d.*rpm$/)
    {
        $clusterInfo->{'majorVer'}=$1;  ## not used, just keep it here...
        $clusterInfo->{'pgVersion'}=$2;

    }
    else
    {
        ECHO_ERROR("Unable to determine the version of postgres, please check the file and try again", 1);
    }
    ECHO_SYSTEM("
##############################################
PG_AUTO_FAILOVER Cluster Installation Summary: 
##############################################

Target Version:    \t[$clusterInfo->{'pgVersion'}]
HA proxy host:     \t[$haProxyHost]
DataNode host:     \t[$clusterInfo->{'dataNodeList'}]
ETCD host:         will be installed on same hosts as data node.
DataNode's PGDATA: \t[$dataNodeDataFolder]

!!! WARNNING !!!
Once you choose to continue, We will delete all the content in above folder.
There is NO ROLLBACK! Please proceed with cautions!
");
    user_confirm("Do you want continue? <yes/no>");
    print Dumper $clusterInfo;
    return $clusterInfo;
}

sub cleanUp
{
    my $clusterInfo = shift;
    my $sshTimeout = 3;
    
    testSudo($clusterInfo->{'haProxyHost'});
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {testSudo($_);};

    ### deleteOldPgDataFolder($clusterInfo->{'haProxyHost'}, $monitorDataFolder);
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {deleteOldPgDataFolder($_, $dataNodeDataFolder );};

    ## check if the host is able to connect and able to sudo
    sub testSudo
    {
        my $host = shift;
        ECHO_INFO("testing if we have sudo privilege on host [$host]...");
        run_command(qq(ssh -o ConnectTimeout=$sshTimeout -o StrictHostKeyChecking=no ${pgUser}\@${host} "sudo uptime"), 1);
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
Usage:   $0 -f <installation file> -m <ha proxy hostname> -d <datanode1, datanode2, ...>
Example: $0 -f vmware-postgres15-15.2-1.el7.x86_64.rpm -m haproxy -d node1,node2,node3

Parameters:

    -f [vmware postgres installation file]
    -m ha proxy node
    -d datanode list, separate with comma
    -h print this message
    -D enable debug mode
    -y answer yes automatically
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