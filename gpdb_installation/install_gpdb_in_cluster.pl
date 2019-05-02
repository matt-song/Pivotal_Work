#!/usr/bin/perl
#################################################################
# Author:      Matt Song                                        #
# Create Date: 2019.05.02                                       #
# Description: Install GPDB in cluster                          #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('hf:Dy', \%opts);

my $DEBUG = $opts{'D'};   
my $gpdb_bin = $opts{'f'};
my $ALL_YES = $opts{'y'};

my $working_folder = "/tmp/.$$";
my $gpdp_home_folder = "/opt";
my $gpdb_master_home = "/data/master";
my $gpdb_segment_home = "/data/segment"; 
my $gpdb_segment_num = 2;
my $master_hostname = 'mdw';                      ## master host
my @segment_list = ('sdw1','sdw2');               ## segment hosts list
my $gp_user = 'gpadmin';

&print_help if $opts{'h'};

### start to work ###

## Step#1 Create the working folder
working_folder("create");

## Step#2 get the binary file from package
my $gpdb_binary = extract_binary("$gpdb_bin");

## Steo#3 install the binary to $gpdp_home_folder
my $gp_info = install_gpdb_binary("$gpdb_binary");

## steo#4 distribute the package, suppose the ssh key has been synced ##
install_package_on_segment_server($gp_info);

## Step#5 initialize the GPDB
init_gpdb($gp_info);

## Step#6 Set the environment for newly installed GPDB
set_env($gp_info);

working_folder("clear");

sub check_folder_existed_and_remove
{
    my ($folder,$isLocal) = @_;   ## 1 = on segment server, 0 = check master locally

    if ($isLocal)
    {
        foreach my $server (@segment_list)
        {
            ECHO_DEBUG("Checking folder [$folder] on host [$server]...");
            my $folder_is_exist = run_command(qq(ssh $server "ls -ld $folder 2>/dev/null | wc -l" ));
            if ($folder_is_exist != 0)
            {
                user_confirm("Folder [$folder] on segment server [$server] already existed, remove it?");
                run_command(qq(ssh $server "rm -rf $folder"));
            }
        }
    }
    else
    {
        user_confirm("Folder [$folder] on master server already existed, remove it?");
        run_command("rm -rf $folder");
    }

}


sub install_package_on_segment_server
{
    my $gp_info = shift;
    my $gp_home = $gp_info->{'gp_home'};
    my $host_file = "${gp_home}/all_hosts"; 

    ECHO_INFO("Cleaning folder [$gp_home] on segment servers...");

    ### check if the segment server already have package installed ###
    check_folder_existed_and_remove($gp_home,1);

    ECHO_INFO("Distributing package to all segment server...");
    my $result = run_command(qq (
        source ${gp_home}/greenplum_path.sh; 
        gpseginstall -f $host_file 2>&1 > /dev/null
    ));

    #print "install_package_on_segment_server: result is [$result]"

}

sub print_help
{
    my $err = shift;
    ECHO_SYSTEM("Usage: $0 -f [gpdb installation file]");
    ECHO_ERROR("$err",1) if ($err); 
    exit 1;
}

sub working_folder
{
    my $task = shift;
    
    if ($task eq "create")
    {
        ECHO_INFO("Creating working working folder [$working_folder]...");
        run_command(qq(rm -rf $working_folder)) if ( -d $working_folder);
        run_command(qq(mkdir -p $working_folder));
    }
    elsif ($task eq "clear")
    {
        run_command(qq(rm -rf $working_folder));
        ECHO_INFO("Cleared the working folder [$working_folder]...");
    }
}

sub extract_binary
{
    my $package = shift;
    
    ECHO_ERROR("Unable to locate file [$package], run [# $0 -h] to check the usage of the script!",1) if ( ! -f $package); 

    ECHO_INFO("Extracting GPDB package [$package] into [$working_folder]...");
    run_command(qq(unzip -qo $package -d $working_folder),1);
    
    my $result = run_command(qq(ls $working_folder | grep "bin\$"),1);
    my $binary = $result->{'output'};
    ECHO_INFO("Successfully extracted binary [$binary]");    

    return $binary;
}

sub install_gpdb_binary
{
    my $binary = shift;
    my $gp_info;

    ECHO_DEBUG("Checking if GPDB is running");
    &stop_gpdb;

    ### print the settings and ask user to confirm ###
    ECHO_INFO("Will start to install binary [$binary], please review below setting");
    
    my $gp_ver = $1 if ($binary =~ /greenplum-db-([\d\.]+)-/);
    my $gp_home = "${gpdp_home_folder}/greenplum_${gp_ver}";
    my $master_folder = "$gpdb_master_home/master_${gp_ver}";
    my $segment_count = $gpdb_segment_num;
    my $segment_folder = "$gpdb_segment_home/segment_${gp_ver}";

    ECHO_SYSTEM("
    GPDB Version:           $gp_ver
    GPDB home folder:       $gp_home
    GPDB master folder:     $master_folder
    GPDB segment count:     $segment_count
    GPDB segment folder:    $segment_folder");

    $gp_info->{'ver'} = $gp_ver;
    $gp_info->{'gp_home'} = $gp_home;

    &user_confirm("Do you want to continue the installation? [yes/no]");

    check_folder_existed_and_remove($gp_home,0);

    ECHO_INFO("Installing GPDB package to [$gp_home]...");
    my $result = run_command(qq( echo -e "yes\n$gp_home\nyes\nyes" | ${working_folder}/${binary} 1>/dev/null));
    ECHO_ERROR("Failed to install GPDB into [$gp_home], please check the error and try again!",1) if ($result->{'code'});

    ### adding the host list into GPDB home folder ###
    ECHO_INFO("Adding host list into [${gp_home}]...");
    open ALL_HOSTS,'>',"${gp_home}/all_hosts" or do {ECHO_ERROR("unable to write file [${gp_home}/all_hosts], exit!",1)};
    open SEG_HOSTS,'>',"${gp_home}/seg_hosts" or do {ECHO_ERROR("unable to write file [${gp_home}/seg_hosts], exit!",1)};

    print SEG_HOSTS "$_\n" foreach (@segment_list);
    my @all_segment = @segment_list;
    push(@all_segment, $master_hostname);
    print ALL_HOSTS "$_\n" foreach (@all_segment);
    close ALL_HOSTS; close SEG_HOSTS;

    ### adding $MASTER_DATA_DIRECTORY to greenplum_path.sh
    ECHO_INFO("updating [greenplum_path.sh] with MASTER_DATA_DIRECTORY");
    open GP_PATH, '>>' , "$gp_home/greenplum_path.sh" or do {ECHO_ERROR("unable to write file [$gp_home/greenplum_path.sh], exit!",1)};
    my $line = qq(export MASTER_DATA_DIRECTORY='${master_folder}/gpdb_${gp_ver}_-1');
    print GP_PATH "$line\n";
    close GP_PATH;
   
    ECHO_INFO("GPDB binary has been successfully installed to [$gp_home]");
    return $gp_info;
}

sub init_gpdb
{
    my $gp_info = shift;
    my $gp_ver = $gp_info->{'ver'};
    my $gp_home = $gp_info->{'gp_home'};

    ECHO_ERROR("No GPDB version found, exit!") if (! $gp_ver);
    
    ECHO_INFO("Start to initializing the GPDB");

    ### create master folder ###
    my $master_folder = "${gpdb_master_home}/master_${gp_ver}";
    ECHO_INFO("Creating the master folder [$master_folder]...");

    check_folder_existed_and_remove($master_folder,0);
    run_command("mkdir -p $master_folder; chown gpadmin $master_folder");

    ### create segment folder ###
    my $segment_folder = "${gpdb_segment_home}/segment_${gp_ver}";
    
    ### scan each segment server to see if segment folder was existed ###
    check_folder_existed_and_remove($segment_folder,1);

    ECHO_INFO("Creating segment folder under [$segment_folder]...");

    my $count = 0;
    my $conf_primary = "declare -a DATA_DIRECTORY=(";
    my $conf_mirror = "declare -a MIRROR_DATA_DIRECTORY=(";

    while ( $count lt $gpdb_segment_num )
    {
        $count++;
        
        my $primary = "$segment_folder/primary${count}";
        my $mirror = "$segment_folder/mirror${count}";

        ### Create segment folder on each segment server ###
        foreach my $seg_server (@segment_list)
        {
            ECHO_DEBUG("Creating segment folder [$primary] and [$mirror] on server [$seg_server]");

            run_command(qq(ssh $seg_server "mkdir -p $primary"));
            run_command(qq(ssh $seg_server "mkdir -p $mirror"));
            run_command(qq(ssh $seg_server "chown -R gpadmin $segment_folder"));
        }

        $conf_primary = $conf_primary."$primary ";
        $conf_mirror = $conf_mirror."$mirror ";
    }
    $conf_primary = $conf_primary.")";
    $conf_mirror = $conf_mirror.")";

    ECHO_INFO("Successfully created master and segment folder.");
    ECHO_DEBUG("conf file: [$conf_primary] and [$conf_mirror]");

    ### initiate the gpdb server ###
    ECHO_INFO("Creating the gpinitsystem_config file to [$gp_home]..");
    open INIT, '>', "$gp_home/gpinitsystem_config" or do {ECHO_ERROR("unable to write file [$gp_home/gpinitsystem_config], exit!",1)};
    my $gpinitsystem_config = qq(
ARRAY_NAME="gpdb_${gp_ver}"
SEG_PREFIX=gpdb_${gp_ver}_
PORT_BASE=20000
$conf_primary
MASTER_HOSTNAME=$master_hostname
MASTER_DIRECTORY=$master_folder
MASTER_PORT=5432
TRUSTED_SHELL=ssh
CHECK_POINT_SEGMENTS=8
ENCODING=UNICODE
MIRROR_PORT_BASE=21000
REPLICATION_PORT_BASE=22000
MIRROR_REPLICATION_PORT_BASE=23000
$conf_mirror
);
    ECHO_DEBUG("the gpinitsystem_config file is like below [\n$gpinitsystem_config\n]");
    print INIT "$gpinitsystem_config";

    ECHO_INFO("Start to initialize the GPDB with config file [$gp_home/gpinitsystem_config] and host file [${gp_home}/seg_hosts]");
    my $result = run_command(qq (
        source ${gp_home}/greenplum_path.sh; 
        gpinitsystem -c ${gp_home}/gpinitsystem_config -h ${gp_home}/seg_hosts -a | egrep "WARN|ERROR|FATAL"
    ));
    
    ### verify if the newly installed GPDB has started ###
    if ($result->{'code'})
    {
        ECHO_ERROR("Failed to initialize GPDB, please check the error and try again",1);
    }
    else
    {
        ECHO_INFO("Done! Checking if GPDB with [$gp_ver] has started");
        my $result = &check_gpdb_isRunning;
        if ($result->{'pid'})
        {
            ECHO_INFO("GPDB has been initialized and started successfully, PID [$result->{'pid'}]");
        }
        else
        {
            ECHO_ERROR("Failed to initialize GPDB, please check the logs and try again!",1);
        }
    }
}

sub set_env
{
    my $gp_info = shift;

    my $gp_home = $gp_info->{'gp_home'};

    ### create the the DB for GP user ###
    ECHO_INFO("Creating database for [$gp_user]...");
    run_command(qq(
        source $gp_home/greenplum_path.sh;
        createdb $gp_user;
    ));
    
    ## remove the greenplum-db file and relink to target folder
    ECHO_INFO("Relink the greenplum-db to [$gp_home]...");
    run_command(qq(rm -f $gpdp_home_folder/greenplum-db)) if ( -e "$gpdp_home_folder/greenplum-db");
    run_command(qq(ln -s $gp_home $gpdp_home_folder/greenplum-db));

    foreach my $server (@segment_list)
    {
        ECHO_INFO("Relink the greenplum-db to [$gp_home] on segment [$server]...");
        run_command(qq(ssh $server "[ -h $gpdp_home_folder/greenplum-db ] && rm -f $gpdp_home_folder/greenplum-db" )) ;
        run_command(qq(ssh $server "ln -s $gp_home $gpdp_home_folder/greenplum-db"));
    }

    ECHO_SYSTEM("
###############################################################
# All set, you may run below command to login to gpdb, enjoy! #
###############################################################

  # source $gp_home/greenplum_path.sh
  # psql 
");

}

sub stop_gpdb
{
    my $checking_result = &check_gpdb_isRunning;

    if ($checking_result->{'pid'} == 0)
    {
        ECHO_INFO("No need to stop GPDB process, Skip");
        return 0;
    }
    else ## try to stop GPDB
    {
        my $gphome = $checking_result->{'gphome'};

        ### Let user confirm if we want stop current running GPDB service ###
        &user_confirm("Pleaase confirm if you would like to stop GPDB installed in [$gphome]? <yes/no>");

        ### Stop the GPDB ###
        ECHO_INFO("Stopping GPDB...");
        
        my $max_retry = 5; 
        my $retry = 0;

        while ($retry <= $max_retry)
        {
            $retry++;
            ECHO_DEBUG("Stopping GPDB... Attempt#[$retry]...");

            run_command(qq(
            source $gphome/greenplum_path.sh;
            gpstop -M fast -a | egrep "WARNING|ERROR";) );

            my $result = &check_gpdb_isRunning;

            if ($result->{'pid'} == 0) ## successfully shutdown
            {
                ECHO_INFO("Successfully stopped GPDB.");
                return 0;
            }
            else
            {
                if ($retry eq $max_retry)
                {
                    ECHO_ERROR("Failed to stop GPDB, maximum retry count [$max_retry] has reached, please stop GPDB manually and try again!", 1);
                }
                else
                {
                    ECHO_ERROR("Failed to stop GPDB, will try again.. [$retry / $max_retry]");
                    last;
                }

            }
        }
    }
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
sub check_gpdb_isRunning
{
    my $result;
    
    ECHO_INFO("Checking if GPDB is running...");
    my $result = run_command(qq(ps -ef | grep silent | grep master | grep "^gpadmin" | grep -v sh | awk '{print \$2","\$8}'));
    my ($pid,$gphome) = split(/,/,$result->{'output'});
    ($gphome = $gphome) =~ s/\/bin\/postgres//g;

    ECHO_DEBUG("GPDB pid: [$pid], GPHOM: [$gphome]");
    if ($pid =~ /\d+/) ## GPDB is running
    {
        ECHO_INFO("GPDB is running, PID: [$pid], GPHOME: [$gphome]");
        $result->{'pid'} = $pid;
        $result->{'gphome'} = $gphome;
        return $result;
    }
    else  ## GPDB is not running
    {
        ECHO_INFO("GPDB is not running");
        $result->{'pid'} = 0;
        return $result;
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
    printColor('blue',"[DEBUG] $message"."\n") if $DEBUG;
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
        working_folder("clear");
        exit(1);
    }
    else{return 1;}
}
sub printColor
{
    my ($Color,$MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}
