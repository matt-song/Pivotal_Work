#!/usr/bin/perl
=README 
#############################################################################
Author:         Matt Song
Creation Date:  2023.03.28

Features:
- Automatically set up a pg_auto_failover cluster Postgres
- Work for vmware postgres only
- postgres user must have sudo privilege
- if failed, fix the error and re-run the script
- tested on CentOS7 Only

Workflow:
1. cleanup all the old rpm of postgres
2. cleanup all the config file of previous pg_autofailover
3. install vmware postgre rpm
4. update the OS service settings /etc/systemd/system/pgautofailover.service
4. create the monitor 
5. create the data node
6. do some post settings after install
7. update the bashrc
8. validation

VMWare Postgres version has been tested: 
 > vmware-postgres-10.17-0.el7.x86_64.rpm
 > vmware-postgres-11.12-0.el7.x86_64.rpm
 > vmware-postgres-12.7-0.el7.x86_64.rpm
 > vmware-postgres-13.3-0.el7.x86_64.rpm
 > vmware-postgres10-10.23-1.el7.x86_64.rpm
 > vmware-postgres11-11.19-1.el7.x86_64.rpm
 > vmware-postgres12-12.14-1.el7.x86_64.rpm
 > vmware-postgres13-13.10-1.el7.x86_64.rpm
 > vmware-postgres14-14.7-1.el7.x86_64.rpm
 > vmware-postgres15-15.2-1.el7.x86_64.rpm

Update:
- 2023.03.28 first draft
- 2023.04.05 adding code to update ~/.bashrc file after new setup
#############################################################################
=cut
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use File::Basename;
# use Switch;
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
# my $baseBackupDir= "/data/backup"; ## this is for pg_autoctl replication, see: https://pg-auto-failover.readthedocs.io/en/latest/ref/configuration.html
my @pgAutoFailoverConfFolder = ('~/.config', '~/.local');
my $tempFolder = '/tmp';
my $workDir = "/tmp/setup_pg_auto_failover.$$";
my $PgAutoFailoverServiceConf = '/etc/systemd/system/pgautofailover.service';
my $bashrcInclude = "/home/postgres/.bashrc_auto_failover";


print_help() if $opts{'h'};

## Step01: check the input parameters
my $clusterInfo = doThePreCheck();

## Step02: clean up old pg autofailover cluster
cleanUp($clusterInfo);

## Step03: install pg_auto_failover binary
installPgAutoFailoverOnAllHosts($clusterInfo);

## step04: create the cluster
createPgAutoFailoverCluster($clusterInfo);

## Step05: post setup
postSetup($clusterInfo);

## clean up
run_command("rm -rf $workDir",1) if ( -d $workDir);

sub postSetup
{
    my $clusterInfo = shift;
    my $binaryLocation = findBinLocation($clusterInfo->{'pgVersion'});
    my $path=dirname($binaryLocation->{'pgCtlBin'});

    updateBashrc($clusterInfo->{'monitorHost'}, $monitorDataFolder);
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {updateBashrc($_, $dataNodeDataFolder);};

    ## checking if we have ~/.bashrc updated
    sub updateBashrc
    {
        my ($host,$pgdata) = @_;
        ECHO_INFO("Update bashrc file for host [$host]...");
        my $cmd_CheckBashrc=qq( cat ~/.bashrc | grep $bashrcInclude | grep -w "\." |wc -l);
        my $result = run_command(qq(ssh ${pgUser}\@$host "$cmd_CheckBashrc"),1);

        if ($result->{'output'} >= 1)
        {
            my $content = qq(echo -e 'export PGDATA=$pgdata\\nexport PATH='$path':\\\$PATH' > $bashrcInclude);
            run_command(qq(ssh ${pgUser}\@$host "$content"),1); 
        }
        else
        {
            my $contentBashrc = qq(echo -e '### pg_auto_failover environment\\nif [ -f $bashrcInclude ]; then\\n    . $bashrcInclude\\nfi' >> ~/.bashrc); 
            run_command(qq(ssh ${pgUser}\@$host "$contentBashrc"),1); 
            my $contentExtraBashrc = qq(echo -e 'export PGDATA=$pgdata\\nexport PATH='$path':\\\$PATH' > $bashrcInclude);
            run_command(qq(ssh ${pgUser}\@$host "$contentExtraBashrc"),1); 
        }
    }
}
sub update_monitor_pghba
{
    ### hostssl "pg_auto_failover" "autoctl_node" 10.216.2.6/32 trust #
    my $clusterInfo = shift;
    
    ECHO_INFO("Updating monitor's pg_hba.conf...");
    my $monitor_hostname = $clusterInfo->{'monitorHost'};
    my $netmask = '16';
    my $monitor_subnet = run_command(qq(ping monitor -c1 | grep "PING" | awk '{print \$3}' | sed 's/(//g' | sed 's/)//g' | awk -F'.' '{print $1"."$2".0.0"}'), 1);
    my $pghba_line = qq(hostssl "pg_auto_failover" "autoctl_node" $monitor_subnet->{'output'}/$netmask trust);
    ECHO_INFO("Adding [$pghba_line] to $monitorDataFolder/pg_hba.conf...");
    open PGHBA,'>>', "$monitorDataFolder/pg_hba.conf" or do {ECHO_ERROR("unable to append to pg_hba.conf, exit!",1)};
    print PGHBA "#### updated by installation script, allow work node to connect to mointor \n$pghba_line\n";
    close PGHBA;

    ECHO_INFO("Reloading mointor...");
    my $binaryLocation = findBinLocation($clusterInfo->{'pgVersion'});
    my $PGCTL=$binaryLocation->{'pgCtlBin'};
    my $cmd_reload_monitor=qq($PGCTL -D $monitorDataFolder reload);
    run_command($cmd_reload_monitor,1);    
    ECHO_INFO("Done!");
}

sub createPgAutoFailoverCluster
{
    my $clusterInfo = shift;
    my $binaryLocation = findBinLocation($clusterInfo->{'pgVersion'});
    my $retry=5; ### retry some times to let service fully up

    ECHO_INFO("create the folder for PGDATA on monitor host [$clusterInfo->{'monitorHost'}]...");
    my $baseFolder=dirname($monitorDataFolder);
    my $cmd_CreateFolder = qq(sudo mkdir -pv $monitorDataFolder; sudo chown -R $pgUser:$pgUser $baseFolder);
    run_command(qq(ssh ${pgUser}\@$clusterInfo->{'monitorHost'} "$cmd_CreateFolder"), 1);

    ### create the monitor ###
    ECHO_INFO("Creating the monitor on host [$clusterInfo->{'monitorHost'}]...");
    my $cmd_CreateMonitorNode = qq(
$binaryLocation->{'pgAutoctlBin'} create monitor \\\
--auth trust \\\
--ssl-self-signed \\\
--pgdata $monitorDataFolder \\\
--hostname $clusterInfo->{'monitorHost'} \\\
--pgctl $binaryLocation->{'pgCtlBin'}
);
    ## ECHO_SYSTEM("$cmd_CreateMonitorNode");
    run_command (qq(ssh ${pgUser}\@$clusterInfo->{'monitorHost'} "$cmd_CreateMonitorNode"),1);

    ECHO_INFO("Starting pg_auto_failover service on host [$clusterInfo->{'monitorHost'}]...");
    run_command(qq(ssh ${pgUser}\@$clusterInfo->{'monitorHost'} "sudo systemctl daemon-reload; sudo systemctl enable pgautofailover; sudo systemctl start pgautofailover"),1);
    ECHO_INFO("Checking the status of monitor...");
    sleep(3); ## wait for monitor start
    ### verify ###
    foreach my $i (1..$retry)
    {
        my $result=run_command(qq(ssh ${pgUser}\@$clusterInfo->{'monitorHost'}  "PGDATA=/data/monitor $binaryLocation->{'pgAutoctlBin'} show state &>/dev/null"));
        if ( $result->{'code'} != 0) 
        {
            if ($i < $retry)
            {
                ECHO_SYSTEM("Monitor has not started yet, retrying [ $i / $retry ]..");
                sleep(1);
                $retry++;
            }else{
                ECHO_ERROR("Monitor can not start, something goes wrong, please review the logs and fix the issue, then try again",1) unless ($result->{'code'} == 0);
            }
        }else{
            ECHO_INFO("Monitor created successfully");
            last;
        }
    }

    ### update monitor pg_hba.conf, updated at 2024-01-10
    update_monitor_pghba($clusterInfo);

    ### Create the data node ###
    my $monitor=${clusterInfo}->{'monitorHost'};
    foreach my $host (split(/,/,$clusterInfo->{'dataNodeList'}) )
    {
        ECHO_INFO("Creating datanode on host [$host]...");
   
        ECHO_INFO("Creating the folder for PGDATA on host [$host]...");
        my $baseFolder=dirname($dataNodeDataFolder);
        my $cmd_CreateFolder = qq(sudo mkdir -pv $dataNodeDataFolder; sudo chown -R $pgUser:$pgUser $baseFolder);
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_CreateFolder"), 1);
        
        my $cmd_CreateDataNode = qq(
$binaryLocation->{'pgAutoctlBin'} create postgres \\\
--pgdata $dataNodeDataFolder \\\
--auth trust \\\
--ssl-self-signed \\\
--username postgres \\\
--hostname $host \\\
--pgctl $binaryLocation->{'pgCtlBin'} \\\
--monitor 'postgres://autoctl_node\@$monitor:5432/pg_auto_failover?sslmode=require' \\\
--dbname postgres  
);
        ## ECHO_SYSTEM($cmd_CreateDataNode);
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_CreateDataNode"),1);
        run_command(qq(ssh ${pgUser}\@${host} "sudo systemctl daemon-reload; sudo systemctl enable pgautofailover; sudo systemctl start pgautofailover"),1);
    }

    ### validation ###
    ECHO_INFO("Setup has completed, checking the status of the cluster...");
    sleep(3); ### wait for standby syncup with leader
    ECHO_SYSTEM("
###############################################################################
VMWare pg_auto_failover cluster [$clusterInfo->{'pgVersion'}] has been installed, here is the result:
###############################################################################
");
    my $result=run_command(qq(ssh ${pgUser}\@$clusterInfo->{'monitorHost'}  "PGDATA=/data/monitor $binaryLocation->{'pgAutoctlBin'} show state"));
    ECHO_SYSTEM($result->{'output'});
}

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
Monitor host:      \t[$monitorHost]
Moniotr's PGDATA:  \t[$monitorDataFolder]
DataNode host:     \t[$clusterInfo->{'dataNodeList'}]
DataNode's PGDATA: \t[$dataNodeDataFolder]

!!! WARNNING !!!
Once you choose to continue, We will delete all the content in above folder, and will also destroy the previous pg_auto_ctl cluster (if exsits)
There is NO ROLLBACK! Please proceed with cautions!
");
    user_confirm("Do you want continue? <yes/no>");
    # print Dumper $clusterInfo;
=comment
$VAR1 = {
          'pgVersion' => '13.8',
          'monitorHost' => 'monitor',
          'package' => 'vmware-postgres13-13.8-1.el7.x86_64.rpm',
          'majorVer' => '13',
          'dataNodeList' => 'node1,node2'
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

    deleteOldPgDataFolder($clusterInfo->{'monitorHost'}, $monitorDataFolder);
    foreach (split(/,/,$clusterInfo->{'dataNodeList'})) {deleteOldPgDataFolder($_, $dataNodeDataFolder );};

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

        ### clean up old bashrc file
        my $cmd_deleteBashrc = qq([ -f $bashrcInclude ] && rm -f $bashrcInclude || echo "File not found [$bashrcInclude], skip..." );
        run_command(qq(ssh ${pgUser}\@${host} "$cmd_deleteBashrc"),1);

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
            my $return = run_command (qq(ssh ${pgUser}\@${host} "$cmd_deleteConfig"),1 );
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

sub findBinLocation
{
    my $version = shift;
    my $result = {};
    
    ## find out the correct binary location, since some version the location changed
    ## doc13: https://postgres.docs.pivotal.io/13-4/release-notes.html
    ## doc12: https://docs.vmware.com/en/VMware-Postgres/12.8/pg-rpm-12.8.pdf
    ## doc11: https://docs.vmware.com/en/VMware-Postgres/11.13/pg-rpm-11.13.pdf
    ## doc10: https://postgres.docs.pivotal.io/10-18/release-notes.html

    my ($majorVer, $minorVer) = split(/\./,$version);
    ECHO_DEBUG("version: $version: [$majorVer], [$minorVer]");
    ### to avoid the compatibility issue in different perl version, I will not using switch here.
    if ($majorVer >= 14)
    {
        $result->{'pgAutoctlBin'} = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
        $result->{'pgCtlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_ctl";
    }
    else
    {
        if ($majorVer == 13)
        { 
            if($minorVer >= 4)
            {
                $result->{'pgAutoctlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_ctl";
            }
            else
            {
                $result->{'pgAutoctlBin'}  = "/usr/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/usr/bin/pg_ctl";
            }
        }
        elsif ($majorVer == 12)
        {
            if($minorVer >= 8)
            {
                $result->{'pgAutoctlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_ctl";
            }
            else
            {
                $result->{'pgAutoctlBin'}  = "/usr/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/usr/bin/pg_ctl";
            }
        }
        elsif ($majorVer == 11)
        {
            if($minorVer >= 13)
            {
                $result->{'pgAutoctlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_ctl";
            }
            else
            {
                $result->{'pgAutoctlBin'}  = "/usr/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/usr/bin/pg_ctl";
            }
        }
        elsif ($majorVer == 10)
        {
            if($minorVer >= 18)
            {
                $result->{'pgAutoctlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_ctl";
            }
            else
            {
                $result->{'pgAutoctlBin'}  = "/usr/bin/pg_autoctl";
                $result->{'pgCtlBin'}  = "/usr/bin/pg_ctl";
            }
        }
        else 
        { 
            ECHO_SYSTEM("[WARNING] The version [$version] you are trying to install has not been tested yet, it might not work!!");
            $result->{'pgAutoctlBin'}  = "/usr/bin/pg_autoctl";
            $result->{'pgCtlBin'}  = "/usr/bin/pg_ctl";
        }
    }
=old  
    if(($majorVer == 13)&&($minorVer >= 4))
    {
        $result->{'pgAutoctlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_autoctl";
        $result->{'pgCtlBin'}  = "/opt/vmware/postgres/$majorVer/bin/pg_ctl";
    }else
    {
        #$result->{'pgAutoctlBin'}  = "/usr/pgsql-$majorVer/bin/pg_autoctl";
        # $result->{'pgCtlBin'}  = "/usr/pgsql-$majorVer/bin/pg_ctl";
        $result->{'pgAutoctlBin'}  = "/usr/bin/pg_autoctl";
        $result->{'pgCtlBin'}  = "/usr/bin/pg_ctl";
    }
=cut
    ECHO_DEBUG("Location of pg_auto_failover binary is [$result->{'pgAutoctlBin'}], pg_ctl is [$result->{'pgCtlBin'}]");
    return $result;
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

        ## clean up the temp installation file 
        run_command(qq(ssh ${pgUser}\@${host} "[ -f ${tempFolder}/$rpm ] && rm -f ${tempFolder}/$rpm || echo 'file not found [${tempFolder}/$rpm], skip' "),1);
    }

    sub updateOSServiceConfig 
    {
        my ($host,$version,$pgDataFolder )= @_;
        
        ECHO_INFO(qq(updating [$PgAutoFailoverServiceConf] on host [$host]...));
        my $binaryLocation = findBinLocation($version);

        my $config=qq(
[Unit]
Description = pg_auto_failover

[Service]
WorkingDirectory = /home/postgres
Environment = 'PGDATA=$pgDataFolder'
User = postgres
ExecStart = $binaryLocation->{'pgAutoctlBin'} run
Restart = always
StartLimitBurst = 0

[Install]
WantedBy = multi-user.target
);
        ECHO_DEBUG($config);
        open SvcFile,'>',"${workDir}/PgAutoFailoverServiceConf.txt" or do {ECHO_ERROR("unable to create file [${workDir}/PgAutoFailoverServiceConf.txt], exit!",1)};
        print SvcFile $config;
        close SvcFile;
        
        my $fileName = basename($PgAutoFailoverServiceConf);

        ### remove those code, no need to backup the old config since we will delete everything
        # ECHO_INFO("Backup [$PgAutoFailoverServiceConf] to [${tempFolder}]...");
        # my $cmd_BackupServiceConifg = qq([ -f $PgAutoFailoverServiceConf ] && sudo mv $PgAutoFailoverServiceConf ${tempFolder}/${fileName}.bak.`date +\%F_\%H-\%M-\%S` || echo "No such file [$PgAutoFailoverServiceConf], skip");
        # run_command(qq(ssh ${pgUser}\@${host} "$cmd_BackupServiceConifg"),1);

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
    -y answer yes automatically
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