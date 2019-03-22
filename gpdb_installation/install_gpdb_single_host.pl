#!/usr/bin/perl
#################################################################
# Author:      Matt Song                                        #
# Create Date: 2018.10.27                                       #
# Description: Install GPDB in single host                      #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;

### Lib folder for GPDB ###
use lib './lib';
use GPDB;



my %opts; getopts('hf:Dy', \%opts);

my $DEBUG = $opts{'D'};   
my $gpdb_bin = $opts{'f'};
#my $ALL_YES = $opts{'y'};


my $gpdb_master_home = "/data/master";
my $gpdb_segment_home = "/data/segment"; 
my $gpdb_segment_num = 2;
my $master_hostname = 'mdw';
my $segment_list = ['sdw1'];               ## segment hosts list ['sdw1', 'sdw2']
my $gp_user = 'gpadmin';

&print_help if $opts{'h'};

### start to work ###

## Step#1 Create the working folder
GPDB->working_folder('create');

## Step#2 get the binary file from package
my $gpdb_binary = GPDB->extract_binary("$gpdb_bin");

## Steo#3 install the binary to $gpdp_home_folder, create hostfile for later init stage
my $gp_info = GPDB->install_gpdb_binary($gpdb_binary, $gpdb_segment_num, $segment_list, $gpdb_master_home, $gpdb_segment_home, $master_hostname);

## Step#4 initialize the GPDB
init_gpdb_single($gp_info);

## Step#5 Set the environment for newly installed GPDB
GPDB->set_env_single($gp_info);

GPDB->working_folder("clear");


sub print_help
{
    my $err = shift;
    GPDB->ECHO_SYSTEM("Usage: $0 -f [gpdb installation file]");
    GPDB->ECHO_ERROR("$err",1) if ($err); 
    exit 1;
}


### init the gpdb in single mode
sub init_gpdb_single
{
    my ($gp_info) = @_;
    my $gp_ver = $gp_info->{'ver'};
    my $gp_home = $gp_info->{'gp_home'};

    GPDB->ECHO_ERROR("No GPDB version was found, exit!") if (! $gp_ver);
    
    GPDB->ECHO_INFO("Start to initializing the GPDB");

    ### create master folder ###
    my $master_folder = "${gpdb_master_home}/master_${gp_ver}";
    GPDB->ECHO_INFO("Creating the master folder [$master_folder]...");

    if (-d $master_folder)
    {
        GPDB->user_confirm("Master folder [$master_folder] already existed, remove it?");
        GPDB->run_command("rm -rf $master_folder");
    }
    GPDB->run_command("mkdir -p $master_folder; chown gpadmin $master_folder");

    ### create segment folder ###
    my $segment_folder = "${gpdb_segment_home}/segment_${gp_ver}";
    if (-d $segment_folder)
    {
        GPDB->user_confirm("Segment folder [$segment_folder] already existed, remove it?");
        GPDB->run_command("rm -rf $segment_folder");
    }
    GPDB->ECHO_INFO("Creating segment folder under [$segment_folder]...");

    my $count = 0;
    my $conf_primary = "declare -a DATA_DIRECTORY=(";
    my $conf_mirror = "declare -a MIRROR_DATA_DIRECTORY=(";

    while ( $count lt $gpdb_segment_num )
    {
        $count++;
        
        my $primary = "$segment_folder/primary${count}";
        my $mirror = "$segment_folder/mirror${count}";

        GPDB->ECHO_DEBUG("Creating segment folder [$primary] and [$mirror]");

        GPDB->run_command("mkdir -p $primary");
        GPDB->run_command("mkdir -p $mirror");
        GPDB->run_command("chown -R gpadmin $segment_folder");

        $conf_primary = $conf_primary."$primary ";
        $conf_mirror = $conf_mirror."$mirror ";
    }
    $conf_primary = $conf_primary.")";
    $conf_mirror = $conf_mirror.")";

    GPDB->ECHO_INFO("Successfully created master and segment folder.");
    GPDB->ECHO_DEBUG("conf file: [$conf_primary] and [$conf_mirror]");

    ### initiate the gpdb server ###
    GPDB->ECHO_INFO("Creating the gpinitsystem_config file to [$gp_home]..");
    open INIT, '>', "$gp_home/gpinitsystem_config" or do {GPDB->ECHO_ERROR("unable to write file [$gp_home/gpinitsystem_config], exit!",1)};
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
    GPDB->ECHO_DEBUG("the gpinitsystem_config file is like below [\n$gpinitsystem_config\n]");
    print INIT "$gpinitsystem_config";

    GPDB->ECHO_INFO("Start to initialize the GPDB with config file [$gp_home/gpinitsystem_config] and host file [${gp_home}/seg_hosts]");
    my $result = GPDB->run_command(qq (
        source ${gp_home}/greenplum_path.sh; 
        gpinitsystem -c ${gp_home}/gpinitsystem_config -h ${gp_home}/seg_hosts -a | egrep "WARN|ERROR|FATAL"
    ));
    
    ### verify if the newly installed GPDB has started ###
    if ($result->{'code'})
    {
        GPDB->ECHO_ERROR("Failed to initialize GPDB, please check the error and try again",1);
    }
    else
    {
        GPDB->ECHO_INFO("Done! Checking if GPDB with [$gp_ver] has started");
        my $result = GPDB->check_gpdb_isRunning;
        if ($result->{'pid'})
        {
            GPDB->ECHO_INFO("GPDB has been initialized and started successfully, PID [$result->{'pid'}]");
        }
        else
        {
            GPDB->ECHO_ERROR("Failed to initialize GPDB, please check the logs and try again!",1);
        }
    }
}





