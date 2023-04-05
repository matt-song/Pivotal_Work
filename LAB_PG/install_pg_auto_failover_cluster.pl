#!/usr/bin/perl
=README 
#############################################################################
Author:         Matt Song
Creation Date:  2023.03.28

Description: 
- Automatically set up a pg_auto_failover cluster Postgres
- Work for vmware postgres only
- postgres user must have sudo privilege
- if failed, fix the error and re-run the script

Workflow:
1. cleanup all the old rpm of postgres
2. cleanup all the config file of previous pg_autofailover
3. install vmware postgre rpm
4. update the OS service settings /etc/systemd/system/pgautofailover.service
4. create the monitor 
5. create the data node
6. do some post settings after install
7. validation

Update:
- 2023.03.28 first draft

#############################################################################
=cut
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use File::Basename;
my %opts; getopts('hf:Dym:d:', \%opts);
my $monitorHost = $opts{'m'};
my $dataNodeHosts = $opts{'d'};
my $installationFile=$opts{'f'};
my $ALL_YES = $opts{'y'};
my $DEBUG = $opts{'D'};

### please review and edit below settings if needed ###
my $pgUser = 'postgres';
my $monitorDataFolder = "/data/monitor";
my $dataNodeDataFolder = "/data/database";
my @pgAutoFailoverConfFolder = ('~/.config', '~/.local');
my $tempFolder = '/tmp';
my $workDir = "/tmp/setup_pg_auto_failover.$$";
my $PgAutoFailoverServiceConf = '/etc/systemd/system/pgautofailover.service';


print_help() if $opts{'h'};




## Step01: check the input parameters
my $clusterInfo = doThePreCheck();

## Step02: clean up old pg autofailover cluster
cleanUp($clusterInfo);

## Step03: install pg_auto_failover binary
installPgAutoFailoverOnAllHosts($clusterInfo);

## step04: create the cluster
# createPgAutoFailoverCluster($clusterInfo)

## clean up
run_command("rm -rf $workDir",1) if ( -d $workDir);




sub doThePreCheck
{
    my $clusterInfo = {};

    print_help("Can not find target rpm file [#installationFile]!") unless ( -f $installationFile);
    print_help("please input monitor's hostname!") if (! $monitorHost);
    print_help("please input data node's hostname!") if (! $dataNodeHosts);
    ECHO_INFO("Creating work directory [$workDir]");
    run_command("mkdir -p $workDir",1);  ## create work dir

    $clusterInfo->{'dataNodeList'} =  $dataNodeHosts;
    $clusterInfo->{'monitorHost'} =  $monitorHost;
    $clusterInfo->{'package'} = basename($installationFile);

    if ($clusterInfo->{'package'} =~ /^vmware-postgres(\d+)-(\d+\.\d+)-1.el7.x86_64.rpm$/)
    {
        $clusterInfo->{'majorVer'}=$1;
        $clusterInfo->{'pgVersion'}=$2;

    }
    else
    {
        ECHO_ERROR("Unable to determine the version of postgres, please check the file and try again", 1);
    }
    ECHO_SYSTEM("
Installation Summary: 

Target Version: $clusterInfo->{'pgVersion'}
Monitor host:   [$monitorHost],\tPGDATABASE: [$monitorDataFolder]
DataNode host:  [$clusterInfo->{'dataNodeList'}],\tPGDATABASE: [$dataNodeDataFolder]

!!! WARNNING !!!
Once you choose to continue, We will delete all the content in above folder, and will also destroy the previous pg_auto_ctl cluster (if exsits)
There is NO ROLLBACK! Please proceed with cautions!
");
    user_confirm("Do you want continue? <yes/no>");
    # print Dumper $clusterInfo;
=comment
$VAR1 = {
          'monitorHost' => 'paf-m',
          'majorVer' => '15',
          'pgVersion' => '15.2',
          'dataNodeList' => 'paf-n1,paf-n2'
        };
=cut
    return $clusterInfo;
}


sub cleanUp
{
    my $clusterInfo = shift;
    my $sshTimeout = 3;
    
    testSudo($clusterInfo->{'monitorHost'});
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {testSudo($_);};

    stopAutoFailverService($clusterInfo->{'monitorHost'});
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {stopAutoFailverService($_);};
    
    removeConfigFolder($clusterInfo->{'monitorHost'});
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {removeConfigFolder($_);};

    ## check if the host is able to connect and able to sudo
    sub testSudo
    {
        my $host = shift;
        ECHO_INFO("testing if we have sudo privilege on host [$host]...");
        run_command(qq(ssh -o ConnectTimeout=$sshTimeout -o StrictHostKeyChecking=no ${pgUser}\@${host} "sudo uptime"), 1);
    }

    ## stop pgautofailover service on host
    sub stopAutoFailverService
    {
        my $host = shift;
        ECHO_INFO("Stopping the pg_auto_failover service on host [$host]...");
        my $cmd_stopAutoFailoverService = q(sudo systemctl stop pgautofailover);
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_stopAutoFailoverService"));
        my $cmd_getPID = q(ps -ef | grep 'pg_autoctl run' | grep -v grep | awk '{print $2}' );
        my $return = run_command (qq(ssh ${pgUser}\@${host} "$cmd_getPID"));
        ECHO_ERROR("failed to stop the pg_autofailover on host [$host], please check the logs and try again",1) if ($return->{'output'});
    }

    ## delete old pg_auto_failover cluster
    sub removeConfigFolder
    {
        my $host = shift;
        ECHO_INFO("cleanup previous installed vmware postgres rpm package on host [$host]..");
        ##### note: adding echo here to eliminate unnecessary error, sort the output to let other package (like vmware-postgres13-devel-13.8-1.el7.x86_64) been removed first
        my $cmd_rpmQuery = qq(rpm -qa | grep vmware-postgres | sort -r || echo "");   
        my $return = run_command (qq(ssh ${pgUser}\@${host} "$cmd_rpmQuery"));

        foreach (split(/^/,$return->{'output'})) 
        {
            chomp(my $rpm = $_);
            my $cmd_rpmRemove = "sudo rpm -e $rpm";
            ECHO_INFO("Removing rpm [$rpm] on host [$host]...");
            run_command (qq(ssh ${pgUser}\@${host} "$cmd_rpmRemove"),1);
        }
        ## check again to make sure it has been removed
        my $return = run_command (qq(ssh ${pgUser}\@${host} "$cmd_rpmQuery"));
        ECHO_ERROR("Failed to remove the rpm on host [$host], we still have below files: $return->{'output'}...") if ($return->{'output'});

        ## delete the config folder
        foreach my $folder (@pgAutoFailoverConfFolder)
        {
            my $cmd_deleteConfig = qq([ -d $folder ] && rm -rf $folder || echo "No such folder [$folder]");
            my $return = run_command (qq(ssh ${pgUser}\@${host} "$cmd_deleteConfig"));
        }

    }
}

sub installPgAutoFailoverOnAllHosts
{
    my $clusterInfo = shift;

    ### install RPM on all host ###
    installRpm($clusterInfo->{'monitorHost'}, $clusterInfo->{'package'});
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) {installRpm($dataNode, $clusterInfo->{'package'});};

    ### Update /etc/systemd/system/pgautofailover.service ###
    updateOSServiceConfig($clusterInfo->{'monitorHost'},$clusterInfo->{'pgVersion'},$monitorDataFolder );
    foreach my $dataNode (split(/,/,$clusterInfo->{'dataNodeList'})) {updateOSServiceConfig($dataNode, $clusterInfo->{'pgVersion'}, $dataNodeDataFolder );};    

    sub installRpm
    {
        my ($host, $rpm)= @_;
        ECHO_INFO(qq(Copying [$installationFile] to server [$host]'s [$tempFolder]...));
        my $cmd_scpFile = qq(scp $installationFile ${pgUser}\@${host}:${tempFolder});
        run_command($cmd_scpFile,1);

        ECHO_INFO(qq(Installing [$rpm] on server [$host]...));
        my $cmd_installRpm = qq(sudo yum -y install ${tempFolder}/$rpm);
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_installRpm"),1);
    }

    sub updateOSServiceConfig 
    {
        my ($host,$version,$pgDataFolder )= @_;
        
        ECHO_INFO(qq(updating [$PgAutoFailoverServiceConf] on host [$host]...));
        
        ## find out the correct binary location, since 13.4 the location changed
        ## doc: https://postgres.docs.pivotal.io/13-4/release-notes.html
        my $pgAutoctlBin;
        my ($majorVer, $minorVer) = split(/\./,$version);
        ECHO_DEBUG("version: $version: [$majorVer], [$minorVer]");
        if ($majorVer >= 14)
        {
            $pgAutoctlBin = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
        }elsif(($majorVer == 13)&&($minorVer >= 4))
        {
            $pgAutoctlBin = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
        }else
        {
            $pgAutoctlBin = "/usr/pgsql-$majorVer/bin/pg_autoctl";
        }
        ECHO_DEBUG("Location of pg_auto_failover binary is [$pgAutoctlBin]");
        my $config=qq(
[Unit]
Description = pg_auto_failover

[Service]
WorkingDirectory = /home/postgres
Environment = 'PGDATA=$pgDataFolder'
User = postgres
ExecStart = $pgAutoctlBin run
Restart = always
StartLimitBurst = 0

[Install]
WantedBy = multi-user.target
);
        ECHO_DEBUG($config);
        open SvcFile,'>',"${workDir}/PgAutoFailoverServiceConf.txt" or do {ECHO_ERROR("unable to create file [${workDir}/PgAutoFailoverServiceConf.txt], exit!",1)};
        print SvcFile $config;
        close SvcFile;

        ### backup the config file first
        ECHO_INFO("Backup [$PgAutoFailoverServiceConf] to [${tempFolder}]...");
        my $fileName = basename($PgAutoFailoverServiceConf);
        my $cmd_BackupServiceConifg = qq([ -f $PgAutoFailoverServiceConf ] && sudo mv $PgAutoFailoverServiceConf ${tempFolder}${fileName}.bak.`date +\%F_\%H-\%M-\%S` || echo "No such file [$PgAutoFailoverServiceConf], skip");
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_BackupServiceConifg"),1);

        ECHO_INFO("Updating [$PgAutoFailoverServiceConf]...");
        my $cmd_ScpServiceConifg = qq(scp ${workDir}/PgAutoFailoverServiceConf.txt ${pgUser}\@${host}:$tempFolder/$fileName);
        run_command($cmd_ScpServiceConifg,1);

        my $cmd_UpdateServiceConifg = qq(sudo mv $tempFolder/$fileName $PgAutoFailoverServiceConf);
        run_command( qq(ssh ${pgUser}\@${host} "$cmd_UpdateServiceConifg"),1 );
    }
}



sub print_help
{
    my $err = shift;
    ECHO_ERROR("$err") if ($err);
    ECHO_SYSTEM("
Usage:   $0 -f <installation file> -m <monitor hostname> -d <datanode1, datanode2, ...>
Example: $0 -f vmware-postgres15-15.2-1.el7.x86_64.rpm -m monitor -d node1,node2   

Parameters:

    -f [vmware postgres installation file]
    -m monitor node
    -d datanode list, separate with comma
    -h print this message
    -D enable debug mode
");
    exit 1;
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