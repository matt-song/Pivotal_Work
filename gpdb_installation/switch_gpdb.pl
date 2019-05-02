#!/usr/bin/perl
#################################################################
# Author:      Matt Song                                        #
# Create Date: 2018.10.31                                       #
# Description: Switch the GPDB server to target build           #
#################################################################
use strict;
use Term::ANSIColor;
use Data::Dumper;

my $gpdp_home_folder = "/opt";
my $DEBUG = 0;
my $HOST_LIST="/home/gpadmin/all_hosts.txt";

 ### let user choose which version to start ###
my $targer_gpdb = select_gpdb($gpdp_home_folder);

### stop GPDB if it is running ###
&stop_gpdb;

### finally, switch the gpdb ###
switch_gpdb($targer_gpdb);

sub switch_gpdb
{
    my $gp_folder = shift;

    my $greenplum_path = "$gp_folder/greenplum_path.sh";

    ## remove the greenplum-db file and relink to target folder
    open LIST,$HOST_LIST or die "Unable to read the list [$HOST_LIST], exit!";

    while (<LIST>)
    {
        chomp(my $server = $_);
        ECHO_INFO("Relink the greenplum-db to [$gp_folder] on host [$server]...");
        my $link_file = "$gpdp_home_folder/greenplum-db";

        run_command( qq(ssh $server "[ -h $link_file ] && rm -f $link_file") );
        run_command( qq(ssh $server "ln -s $gp_folder $link_file") );
    }

    ## start the gpdb ##
    ECHO_INFO("Starting GPDB...");
    run_command(qq(
        source $greenplum_path;
        gpstart -a | egrep "ERROR|WARNING"
    ));
    my $result = &check_gpdb_isRunning;
    if ($result->{'pid'})
    {
        ECHO_INFO("GPDB has started successfully, PID [$result->{'pid'}]");
        ECHO_INFO("Reloading the greenplum_path.sh...");
        run_command(qq (source "$result->{'gphome'}/greenplum_path.sh" ));
        ECHO_INFO("All done, enjoy!");
    }
    else
    {
        ECHO_ERROR("Failed to start GPDB, please check the logs and try again!",1);
    }
}

sub select_gpdb
{
    
    my $current_gpdb = &check_gpdb_isRunning();
    if ($current_gpdb->{'pid'})
    {
        my $current_gp_ver = $current_gpdb->{'gphome'};
        $current_gp_ver =~ s/\/opt\/greenplum_//g;
        ECHO_SYSTEM("\n[WARNING] Detected GPDB is running, code version: [$current_gp_ver]");
        user_confirm("Continue to swith GPDB build? [yes/no]");
    }

    my $gp_list = run_command("ls $gpdp_home_folder | grep '^greenplum_'");
    my $gp_target;

    my $hash;

    ECHO_INFO("Find below GPDB installed: \n");
    my $count = 0;
    foreach my $gp_server (split ('^',$gp_list))
    {
        chomp($gp_server);
        next if ( $gp_server !~ /^greenplum_/);
        
        $count++;
        ECHO_SYSTEM(qq(    [$count]:    $gp_server));
        $hash->{$count} = "$gpdp_home_folder/$gp_server";
    }
    ECHO_ERROR("No GPDB found in [$gpdp_home_folder], exit!",1) if ($count == 0);

    ### ask user choose which GPDB to switch ###
    while (1)
    {
        ECHO_SYSTEM("\nplease select which GPDB you would like to change to:");
        chomp(my $input = (<STDIN>));
        if ($hash->{$input})
        {
            $gp_target = $hash->{$input};
            ECHO_SYSTEM("Target GPDB has choosen: [$hash->{$input}]");
            return $hash->{$input};
        }
        else
        {
            ECHO_ERROR("Wrong input [$input], please try again");
        }   
    }
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
                    next;
                }

            }
        }
    }
}
sub user_confirm
{
    my $msg = shift;

    ECHO_SYSTEM("\n$msg");
    my $input = (<STDIN>);

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
        #working_folder("clear");
        exit(1);
    }
    else{return 1;}
}
sub printColor
{
    my ($Color,$MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}


# ls  /opt/ | grep greenplum_
