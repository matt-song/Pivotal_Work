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
my %opts; getopts('hf:D', \%opts);

my $DEBUG = $opts{'D'};   
my $gpdb_bin = $opts{'f'};

my $working_folder = "/tmp/.$$";
my $gpdp_home_folder = "/opt";
my $gpdb_master_home = "/data/master";
my $gpdb_segment_home = "/data/segment"; 
my $gpdb_segment_num = 2;
my $master_hostname = 'mdw';                      ## master host
my @segment_list = ('sdw1','sdw2');               ## segment hosts list

&print_help if $opts{'h'};

### start to work ###

## Step#1 Create the working folder
working_folder("create");

## Step#2 get the binary file from package
my $gpdb_binary = extract_binary("$gpdb_bin");

## Steo#3 install the binary to $gpdp_home_folder
install_gpdb_binary("$gpdb_binary");

working_folder("clear");


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
    run_command(qq(unzip -qo $package -d $working_folder));

    #(my $binary = $package) =~ s/\.zip/\.bin/g;
    my $binary = run_command(qq(ls $working_folder | grep bin));
    ECHO_INFO("Successfully extracted binary [$binary]");    

    return $binary;
}

sub install_gpdb_binary
{
    my $binary = shift;

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
GPDB segment folder:    $segment_folder
");

    &user_confirm("Do you want to continue the installation? [yes/no]");

    if ( -d $gp_home )
    {
        &user_confirm("GP home folder [$gp_home] already existed, remove it? [yes/no]");
        run_command("rm -rf $gp_home");
    }

    ECHO_INFO("Installing GPDB package to [$gp_home]...");
    my $rc = run_command(qq( echo -e "yes\n$gp_home\nyes\nyes" | ${working_folder}/${binary} 1>/dev/null));
    ECHO_ERROR("Failed to install GPDB into [$gp_home], please check the error and try again!",1) if ($rc);

    ### adding the host list into GPDB home folder ###
    open ALL_HOSTS,'>',"${gp_home}/all_hosts" or do {ECHO_ERROR("unable to write file [${gp_home}/all_hosts], exit!",1)};
    open SEG_HOSTS,'>',"${gp_home}/seg_hosts" or do {ECHO_ERROR("unable to write file [${gp_home}/seg_hosts], exit!",1)};

    print SEG_HOSTS "$_\n" foreach (@segment_list);
    my @all_host = push(@segment_list, $master_hostname);
    print ALL_HOSTS "$_\n" foreach( @all_host);

    close ALL_HOSTS; close SEG_HOSTS;




=old
# stop current gpdb 

ps -ef | grep silent | grep master | grep "^gpadmin" | awk '{print $2,$8}'
12374 /opt/greenplum_4.3.25.1/bin/postgres

# remove the folder /opt/greenplum-.4.3.28.0 if exist 

echo -e "yes\n/opt/greenplum_4.3.28.0\nyes\nyes" | ./greenplum-db-4.3.28.0-rhel5-x86_64.bin

# cd /opt/greenplum_4.3.28.0/
# source greenplum_path.sh

# echo -e "mdw\nsdw1" > all_hosts
# echo "sdw1" > seg_hosts
=cut


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
            gpstop -M fast -a > /dev/null;) );

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
    ECHO_SYSTEM("$msg");
    my $input = (<STDIN>);
    ECHO_ERROR("Cancelled by user, exit!", 1) unless ($input =~ /y|yes/i);
    return 0;
}
sub check_gpdb_isRunning
{
    my $result;
    
    ECHO_INFO("Checking if GPDB is running...");
    my $gpdb_proc = run_command(qq(ps -ef | grep silent | grep master | grep "^gpadmin" | grep -v sh | awk '{print \$2","\$8}'));
    my ($pid,$gphome) = split(/,/,$gpdb_proc);
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
    my $cmd = shift;
    ECHO_DEBUG("will run command [$cmd]..");
    chomp(my $result = `$cmd 2>&1` );
    my $rc = "$?";
    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is $rc"); 
        ECHO_ERROR("ERROR: [$result]");
        return $rc;
    }
    else
    {
        ECHO_DEBUG("Command excute successfully, return code [$rc]");
        ECHO_DEBUG("the result is [$result]");
        return $result;        
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
