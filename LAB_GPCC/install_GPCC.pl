#!/usr/bin/perl
###########################################################################################
# Author:      Matt Song                                                                  #
# Create Date: 2019.10.30                                                                 #
# Description: Install GPCC, supported version: 4x                                        #
#                                                                                         #
# // Some notes here: //                                                                  #
#                                                                                         #
# - The script will read the segment list from $segment_list_file                         #
# - we do need to check the folder on segments, because later we will check               #
#   the folder in swith version script.                                                   #
###########################################################################################

### TBD: check if gpcc is running before remove the folder 

use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('hf:Dy', \%opts);

my $DEBUG = $opts{'D'};   
my $gpcc_package = $opts{'f'};
my $ALL_YES = $opts{'y'};

my $workingFolder = "/tmp/.gpcc_installation.$$";
my $gpcc_home_folder = "/opt";
# my $gpdb_master_home = "/data/master";
# $gpdb_segment_home = "/data1/segment";  ### the segmnet folder will be defined in install_gpdb_package            
# my $master_hostname = 'smdw';                                                          ## master host
# my $gp_user = 'gpadmin';
#my $segment_list_file = "/home/gpadmin/all_segment_hosts.txt";
#my $list_gpdb_script = "/home/gpadmin/scripts/list_gpdb_status.sh";

&print_help if $opts{'h'};

############ Start works at here ############

### get the segment list ###
# my @segment_list = getSegmentHostsList($segment_list_file);

### pre-installation check ###
my $gpcc_ver = preInstallationCheck($gpcc_package);

### extract the package ###
workingFolderManager("create");
my $gpcc_binary = extractPackage($gpcc_package, $gpcc_ver);

### found aviliable master ###
my $DB_INFO=findAvailableGPDB($gpcc_ver);

### Install the binary ###
installBinary($gpcc_binary,$gpcc_ver,$DB_INFO);

### clean the work folder ###
workingFolderManager("clear");

sub findAvailableGPDB
{
    my $gpcc_ver = shift;
    my $DB_INFO;

    ECHO_INFO("Trying to find a live GPDB cluster to do the installation of GPCC [$gpcc_ver]...");
    # get the family of the gpcc 
    my $gpcc_family = (split(/\./, $gpcc_ver))[0];

    my $version_map = {
        '6'=>'greenplum_6',
        '4'=>'greenplum_5',
        '3'=>'greenplum_4',
    };
    my $target_GP_prefix = $version_map->{$gpcc_family};
    ECHO_DEBUG("We are working on GPCC family [$gpcc_family] and the target GPHOME is [$target_GP_prefix]");

    my $get_DB_list = runCommand(qq(ps -ef | grep sil | grep /opt/$target_GP_prefix | sort -r -k8 | grep -v sort));
    if ($get_DB_list->{'code'} == 0)
    {
        ## test DB one by one until we found an valid one, try from highest version first
        ## exmaple output: gpadmin  26227     1  0 Oct23 ?        00:00:00 /opt/greenplum_5.21.5/bin/postgres -D /data/master/master_5.21.5/gpseg-1 -p 3168 --gp_dbid=1 --gp_num_contents_in_cluster=10 --silent-mode=true -i -M master --gp_contentid=-1 -x 0 -E
        foreach my $line (split(/^/,$get_DB_list->{'output'}))    
        {
            ## need bash print non-colorful output 
            chomp($line);
            ECHO_DEBUG("Processing line [$line]...");
            my $postgres_binary = (split(/\s+/,$line))[7];
            my $pg_port = (split(/\s+/,$line))[11];
            
            ECHO_DEBUG("The postgres_binary is [$postgres_binary] and PORT is [$pg_port]");
            if ($postgres_binary =~ /(\/opt\/greenplum_[\.\d]+)\/.*/)
            {
                ECHO_DEBUG("Found valid output, postgres_binary [postgres_binary]");
                my $gp_home = $1;
                # $DB_INFO->{'GPHOME'} = $1;
                # $DB_INFO->{'PGPORT'} = $pg_port;

                ECHO_INFO("Found GPHOME: [$gp_home] and PORT [$pg_port], checking if DB is functional");
                my $testDB = runCommand(qq(source ${gp_home}/greenplum_path.sh; timeout 10 psql -Atc "select 99;"));

                if ($testDB->{'output'} == 99 )
                {
                    ECHO_INFO("Working, getting the DB info now...");
                    $DB_INFO->{'GPHOME'} = $gp_home;
                    $DB_INFO->{'PGPORT'} = $pg_port;
                    last;
                }
                else
                {
                    ECHO_ERROR("GPDB under [$gp_home] is not working, try next one...");
                    next;
                }
            }
            else
            {
                next;
            }
        }
        # print Dumper $DB_INFO;
        ECHO_ERROR("Unable to found aviliable GPDB, exit now!",1) if (! $DB_INFO->{'GPHOME'});
        return $DB_INFO;
    }
    else
    {
        ECHO_ERROR("Unable to get aviliable GPDB to install GPCC [$gpcc_ver], please check and try again!",1);
    }
}

sub installBinary
{
    my ($folder,$gpcc_ver,$gpdb_info) = @_;
    my $installation_conf = qq(
path = $gpcc_home_folder
display_name = gpcc_$gpcc_ver
master_port = $gpdb_info->{'PGPORT'}
web_port = 28080
rpc_port = 8899
enable_ssl = false
enable_kerberos = false
language = 1 
);
    ECHO_DEBUG("The content of conf file of installation is [$installation_conf]");

    open CONF,'>',"${workingFolder}/gpcc_install.conf" or do {ECHO_ERROR("Unable to write into conf file [${workingFolder}/gpcc_install.conf], exit!")};
    print CONF $installation_conf;
    close CONF;

    ECHO_INFO("Start to install the GPCC [$gpcc_ver] with binary [${workingFolder}/${folder}/gpccinstall-${gpcc_ver}]");
    my $install_gpcc=runCommand(qq( bash -c "${workingFolder}/${folder}/gpccinstall-${gpcc_ver} -c ${workingFolder}/gpcc_install.conf >/dev/null < <(echo y)"));
    
    if ($install_gpcc->{'code'} == 0)
    {
        ECHO_INFO("Successfully installed GPCC [$gpcc_ver]!");
    }
    else
    {
        ECHO_ERROR("Failed to install the GPCC, please check and try again, exit now.",1);
    }
}

sub extractPackage
{
    my ($package, $gpcc_ver) = @_;

    ECHO_INFO("Extracting GPCC package [$package], GPCC version is [$gpcc_ver]");
    runCommand(qq(unzip -qo $package -d $workingFolder),1);

    my $getBinaryName = runCommand(qq(ls $workingFolder | grep "greenplum-cc-web-${gpcc_ver}"),1);
    my $binary = $getBinaryName->{'output'};
    ECHO_INFO("Successfully extracted binary,the installation file name is [$binary], start to install the GPCC now...");
    return $binary;
}

=old
sub getSegmentHostsList
{
    my $segment_list_file = shift;
    my $segment_list;

    ECHO_DEBUG("Getting the segment list from file [$segment_list_file]...");
    open SEG, $segment_list_file or do {ECHO_ERROR("Failed to read segment list file [$segment_list_file]",1)};
    foreach my $line (<SEG>)
    {
        chomp($line);
        ECHO_DEBUG("Processing line [$line]");
        next if ($line =~ /^#/);
        push(@$segment_list,$line);
    }
    close SEG;
    #print Dumper $segment_list;
    return $segment_list;
}
=cut 

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

sub printHelp
{
    my $err = shift;
    ECHO_SYSTEM("Usage: $0 -f [gpcc installation file]");
    ECHO_ERROR("$err",1) if ($err); 
}

sub preInstallationCheck
{
    my ($package, $segment_list) = @_;
    ECHO_ERROR("No such file [$package], please check and try again",1) if ( ! -f $package);

    ### get the target version of gpcc 
    my $gpcc_ver= (split (/-/,$package))[3];    # greenplum-cc-web-4.8.0-LINUX-x86_64.zip
    ECHO_DEBUG("Found GPCC version [$gpcc_ver]");

    ### check if we have pre-installed package ###
    ECHO_INFO("Checking if we have pre-installed gpcc package for [$gpcc_ver]");
    my $checkFolderExisted = runCommand(qq(ls -ld ${gpcc_home_folder}/greenplum-cc-web-${gpcc_ver} 2>/dev/null | wc -l));
    if ($checkFolderExisted->{'output'} != 0)
    {
        user_confirm("The GPCC with version [$gpcc_ver] has already been installed, do you want to remove and reinstall?");
        runCommand("rm -rfv `ls -d ${gpcc_home_folder}/greenplum-cc-web-${gpcc_ver}`");
    }
    return $gpcc_ver;
}

sub workingFolderManager
{
    my $task = shift;
    
    if ($task eq "create")
    {
        ECHO_INFO("Creating working working folder [$workingFolder]...");
        runCommand(qq(rm -rf $workingFolder)) if ( -d $workingFolder);
        runCommand(qq(mkdir -p $workingFolder));
    }
    elsif ($task eq "clear")
    {
        runCommand(qq(rm -rf $workingFolder));
        ECHO_INFO("Cleared the working folder [$workingFolder]...");
    }
}

sub runCommand
{
    my ($cmd, $err_out) = @_;
    my $run_info;
    $run_info->{'cmd'} = $cmd;

    ECHO_DEBUG("will run command [$cmd]..");
    chomp(my $result = `$cmd 2>&1` );
    my $rc = "$?";
    #ECHO_DEBUG("Return code [$rc], Result is [$result]");
    
    $run_info->{'code'} = $rc;
    $run_info->{'output'} = $result;

    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is [$rc]"); 
        ECHO_ERROR("ERROR: [$result]", $err_out);
    }
    else
    {
        ECHO_DEBUG(" -> Command excuted successfully");
        ECHO_DEBUG(" -> The result is [$result]");   
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
        workingFolderManager("clear");
        exit(1);
    }
    else{return 1;}
}
sub printColor
{
    my ($Color,$MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}
