#!/usr/bin/perl
###########################################################################################
# Author:      Matt Song                                                                  #
# Create Date: 2019.11.6                                                                  #
# Description: Switch the GPCC version, supported version: 4x                             #
#                                                                                         #
# // Some notes here: //                                                                  #
#                                                                                         #
###########################################################################################


### TBD: check if gpcc is running before remove the folder 

use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('hD', \%opts);

my $DEBUG = $opts{'D'};   
# my $workingFolder = "/tmp/.gpcc_installation.$$";
my $gpdb_home_folder = "/opt";
my $gpcc_home_folder = "/opt";

# my $gpdb_master_home = "/data/master";
# $gpdb_segment_home = "/data1/segment";  ### the segmnet folder will be defined in install_gpdb_package            
# my $master_hostname = 'smdw';                                                          ## master host
# my $gp_user = 'gpadmin';
#my $segment_list_file = "/home/gpadmin/all_segment_hosts.txt";
#my $list_gpdb_script = "/home/gpadmin/scripts/list_gpdb_status.sh";

=workfolow:

1. get aviliable gpcc/gpdb
2. on gpdb, install gpperfmon (need remove the before install it) https://gpcc.docs.pivotal.io/440/topics/setup-collection-agents.html
3. start gpcc

=cut


######### Start work from here #########

### Step#1 Get aviliable GPCC/GPDB build
my $GPCC_LIST = getAviliableGPCC();
my $GPDB_LIST = getAvailableGPDB();

### Step#2 Let user choose which the combination of GPDB and  GPCC 
my $user_choice = chooseTargetBuild($GPCC_LIST,$GPDB_LIST);





sub chooseTargetBuild
{
    my ($GPDB,$GPCC) = @_;
    my $result;
    
    system("clear");
    ### choose the GPDB ###
    ECHO_INFO("All aviliable GPDB build as below:\n");
    for my $gpdb_id (sort { $a <=> $b } keys %$GPDB)
    {
        printColor('yellow',"    [$gpdb_id]:     $GPDB->{$gpdb_id}->{'version'}\n");
    }
    ECHO_INFO("Please choose the GPDB version for GPCC");
    my $selectedGPDB = (<STDIN>);


    ECHO_INFO("All aviliable GPCC build as below:\n");
    for my $gpcc_id (sort { $a <=> $b } keys %$GPCC)
    {
        printColor('yellow',"    [$gpcc_id]:     $GPCC->{$gpcc_id}->{'version'}\n");
    }
}

sub getUserInput
{
    
}



sub getAviliableGPCC
{
    ECHO_INFO("Getting installed GPCC builds under [$gpcc_home_folder]");
    my $getGPCC = runCommand(qq(ls -l $gpcc_home_folder/ | grep greenplum-cc-web- | grep "^d" | awk '{print \$NF}'),1);

    my $result;
    my $count=0;
    foreach my $build (split('^',$getGPCC->{'output'}))
    {
        chomp($build);
        my $gpcc_version = $1 if ($build =~ /greenplum-cc-web-([\w\.]+)\-?.*/);
        ECHO_DEBUG("Found the version of GPCC [$gpcc_version]");
        $result->{$count}->{'home'}=$build;
        $result->{$count}->{'version'}=$gpcc_version;
        $count++;
    }
    print Dumper $result;
    return $result;
}

sub getAvailableGPDB
{
    ECHO_INFO("Getting installed GPDB builds under [$gpdb_home_folder]");
    my $getGPDB = runCommand(qq(ls -l $gpdb_home_folder/ | grep greenplum_ | grep "^d" | awk '{print \$NF}'),1);

    my $result;
    my $count=0;
    foreach my $build (split('^',$getGPDB->{'output'}))
    {
        chomp($build);
        my $gpdb_version = $1 if ($build =~ /greenplum_([\w\.]+)/);
        ECHO_DEBUG("Found the version of GPDB [$gpdb_version]");

        ### check if GPDB is functional ###
        my $checkRunning = runCommand(qq(ps -ef | grep $gpdb_home_folder | grep postgres | grep master | grep "\\\-D" | grep "$gpdb_version" | grep -v "sh \\\-c ps \\\-ef" | wc -l));
        my $status = $checkRunning->{'output'} > 0 ? 'online':'offline';

        if ($status eq 'online') 
        {
            my $testDB = runCommand(qq(source ${gpdb_home_folder}/${build}/greenplum_path.sh; timeout 10 psql postgres -Atc "select 99;" | grep -w 99));
            $status = 'unavailable' if ($testDB->{'output'} != 99);
        }

        ### get the port of GPDB ###
        my $checkPort = runCommand(qq(echo `echo "$gpdb_version" | md5sum | awk '{print \$1}' | tr a-f A-F` % 9999 | bc),1);
        my $port = $checkPort->{'output'};
        if (length($port) < 4)
        {
            my $zeroNeeded = 4 - length($port);
            ECHO_DEBUG("Port of [$build] is [$port], less than 1000, adding [$zeroNeeded] 0 on it");
            foreach (1..$zeroNeeded)
            {
                $port = $port."0";
            }
        }
        $result->{$count}->{'home'}=$build;
        $result->{$count}->{'version'}=$gpdb_version;
        $result->{$count}->{'status'}=$status;
        $result->{$count}->{'port'}=$port;
        $count++;
    }
    print Dumper $result;
    return $result;
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

sub ECHO_WARN
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
