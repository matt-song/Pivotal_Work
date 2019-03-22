#!/usr/bin/perl
package GPDB;
use strict;
use Data::Dumper;
use Term::ANSIColor;

my $DEBUG = 1;

my $gpdp_home_folder = "/opt";
my $gpdb_master_home = "/data/master";

my $working_folder = "/tmp/.$$";
my $gpdp_home_folder = "/opt";
my $gp_user = 'gpadmin';

### GPDB installation related function ###

sub working_folder
{
    my ($self, $task) = @_;
    
    if ($task eq "create")
    {
        ECHO_INFO('self',"Creating working working folder [$working_folder]...");
        run_command('self', qq(rm -rf $working_folder)) if ( -d $working_folder);
        run_command('self', qq(mkdir -p $working_folder));
    }
    elsif ($task eq "clear")
    {
        run_command('self', qq(rm -rf $working_folder));
        ECHO_INFO('self',"Cleared the working folder [$working_folder]...");
    }
}

sub extract_binary
{
    my ($self, $package) = @_;
    
    ECHO_ERROR('self',"Unable to locate file [$package], run [# $0 -h] to check the usage of the script!",1) if ( ! -f $package); 

    ECHO_INFO('self',"Extracting GPDB package [$package] into [$working_folder]...");
    run_command('self', qq(unzip -qo $package -d $working_folder),1);
    
    my $result = run_command('self', qq(ls $working_folder | grep "bin\$"),1);
    my $binary = $result->{'output'};
    ECHO_INFO('self',"Successfully extracted binary [$binary]");    

    return $binary;
}

sub install_gpdb_binary
{
    my ($self, $binary, $gpdb_segment_num, $seg_servers, $gpdb_master_home, $gpdb_segment_home, $master_hostname) = @_;
    
    my $gp_info;
    my @segment_list = @$seg_servers;

    ECHO_DEBUG('self',"Checking if GPDB is running");
    &stop_gpdb;

    ### print the settings and ask user to confirm ###
    ECHO_INFO('self',"Will start to install binary [$binary], please review below setting");
    
    my $gp_ver = $1 if ($binary =~ /greenplum-db-([\d\.]+)-/);
    my $gp_home = "${gpdp_home_folder}/greenplum_${gp_ver}";
    my $master_folder = "$gpdb_master_home/master_${gp_ver}";
    my $segment_count = $gpdb_segment_num;
    my $segment_folder = "$gpdb_segment_home/segment_${gp_ver}";

    ECHO_SYSTEM('self',"
    GPDB Version:           $gp_ver
    GPDB home folder:       $gp_home
    GPDB master folder:     $master_folder
    GPDB segment count:     $segment_count
    GPDB segment folder:    $segment_folder");

    $gp_info->{'ver'} = $gp_ver;
    $gp_info->{'gp_home'} = $gp_home;

    &user_confirm('self',"Do you want to continue the installation? [yes/no]");

    if ( -d $gp_home )
    {
        &user_confirm('self',"GP home folder [$gp_home] already existed, remove it? [yes/no]");
        run_command("rm -rf $gp_home");
    }

    ECHO_INFO('self',"Installing GPDB package to [$gp_home]...");
    my $result = run_command('self', qq( echo -e "yes\n$gp_home\nyes\nyes" | ${working_folder}/${binary} 1>/dev/null));
    ECHO_ERROR('self',"Failed to install GPDB into [$gp_home], please check the error and try again!",1) if ($result->{'code'});

    ### adding the host list into GPDB home folder ###
    ECHO_INFO('self',"Adding host list into [${gp_home}]...");
    open ALL_HOSTS,'>',"${gp_home}/all_hosts" or do {ECHO_ERROR('self',"unable to write file [${gp_home}/all_hosts], exit!",1)};
    open SEG_HOSTS,'>',"${gp_home}/seg_hosts" or do {ECHO_ERROR('self',"unable to write file [${gp_home}/seg_hosts], exit!",1)};

    print SEG_HOSTS "$_\n" foreach (@segment_list);
    push(@segment_list, $master_hostname);
    print ALL_HOSTS "$_\n" foreach (@segment_list);
    close ALL_HOSTS; close SEG_HOSTS;

    ### adding $MASTER_DATA_DIRECTORY to greenplum_path.sh
    ECHO_INFO('self',"updating [greenplum_path.sh] with MASTER_DATA_DIRECTORY");
    open GP_PATH, '>>' , "$gp_home/greenplum_path.sh" or do {ECHO_ERROR('self',"unable to write file [$gp_home/greenplum_path.sh], exit!",1)};
    my $line = qq(export MASTER_DATA_DIRECTORY='${master_folder}/gpdb_${gp_ver}_-1');
    print GP_PATH "$line\n";
    close GP_PATH;
   
    ECHO_INFO('self',"GPDB binary has been successfully installed to [$gp_home]");
    return $gp_info;
}

sub set_env_single
{
    my ($self, $gp_info) = @_;

    my $gp_home = $gp_info->{'gp_home'};

    ### create the the DB for GP user ###
    ECHO_INFO('self',"Creating database for [$gp_user]...");
    run_command('self', qq(
        source $gp_home/greenplum_path.sh;
        createdb $gp_user;
    ));
    
    ## remove the greenplum-db file and relink to target folder
    ECHO_INFO('self',"Relink the greenplum-db to [$gp_home]...");
    run_command('self', qq(rm -f $gpdp_home_folder/greenplum-db)) if ( -e "$gpdp_home_folder/greenplum-db");
    run_command('self', qq(ln -s $gp_home $gpdp_home_folder/greenplum-db));

    ECHO_SYSTEM('self',"
###############################################################
# All set, you may run below command to login to gpdb, enjoy! #
###############################################################

  # source $gp_home/greenplum_path.sh
  # psql 
");
}

sub user_confirm
{
    my ($self, $msg) = @_;
=old
    if ($ALL_YES)
    {
        $input = 'yes';
    }
    else
    {
        ECHO_SYSTEM('self',"\n$msg");
        $input = (<STDIN>);
    }
=cut
    ECHO_SYSTEM('self',"\n$msg");
    my $input = (<STDIN>);

    if ($input =~ /no|n/i)
    {
        ECHO_ERROR('self',"Cancelled by user, exit!", 1);
    }
    elsif ($input =~ /yes|y/i) 
    {
        return 0;
    }
    else
    {
        ECHO_ERROR('self',"Please input 'yes' or 'no'!");
        &user_confirm('self',$msg);
    }
}

### define function to make the world more beautiful ###
sub ECHO_SYSTEM
{
    my ($self,$message) = @_;
    printColor('self','yellow',"$message"."\n");
}
sub ECHO_DEBUG
{
    my ($self,$message) = @_;
    printColor('self','blue',"[DEBUG] $message"."\n") if $DEBUG;
}
sub ECHO_INFO
{
    my ($self, $message, $no_return) = @_;
    printColor('self','green',"[INFO] $message");
    print "\n" if (!$no_return);
}
sub ECHO_ERROR
{
    my ($self, $Message,$ErrorOut) = @_;
    printColor('self','red',"[ERROR] $Message"."\n");
    if ($ErrorOut == 1)
    { 
        working_folder("clear");
        exit(1);
    }
    else{return 1;}
}
# print the strings with color 
sub printColor
{
    my ($self, $Color, $MSG) = @_;
    print color "$Color"; print "$MSG"; print color 'reset';
}

sub run_command
{
    my ($self, $cmd, $err_out) = @_;
    my $run_info;
    $run_info->{'cmd'} = $cmd;

    ECHO_DEBUG('self',"will run command [$cmd]..");
    chomp(my $result = `$cmd 2>&1` );
    my $rc = "$?";
    ECHO_DEBUG('self',"Return code [$rc], Result is [$result]");
    
    $run_info->{'code'} = $rc;
    $run_info->{'output'} = $result;

    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is $rc"); 
        ECHO_ERROR("ERROR: [$run_info->{'output'}]", $err_out);
    }
    else
    {
        ECHO_DEBUG('self',"Command excute successfully, return code is [$rc]");
        ECHO_DEBUG('self',"The result is [$run_info->{'output'}]");   
    }
    return $run_info;

}

sub stop_gpdb
{
    my $checking_result = &check_gpdb_isRunning;

    if ($checking_result->{'pid'} == 0)
    {
        ECHO_INFO('self',"No need to stop GPDB process, Skip");
        return 0;
    }
    else ## try to stop GPDB
    {
        my $gphome = $checking_result->{'gphome'};

        ### Let user confirm if we want stop current running GPDB service ###
        &user_confirm('self',"Pleaase confirm if you would like to stop GPDB installed in [$gphome]? <yes/no>");

        ### Stop the GPDB ###
        ECHO_INFO('self',"Stopping GPDB...");
        
        my $max_retry = 5; 
        my $retry = 0;

        while ($retry <= $max_retry)
        {
            $retry++;
            ECHO_DEBUG('self',"Stopping GPDB... Attempt#[$retry]...");

            run_command('self', qq(
            source $gphome/greenplum_path.sh;
            gpstop -M fast -a | egrep "WARNING|ERROR";) );

            my $result = &check_gpdb_isRunning;

            if ($result->{'pid'} == 0) ## successfully shutdown
            {
                ECHO_INFO('self',"Successfully stopped GPDB.");
                return 0;
            }
            else
            {
                if ($retry eq $max_retry)
                {
                    ECHO_ERROR('self',"Failed to stop GPDB, maximum retry count [$max_retry] has reached, please stop GPDB manually and try again!", 1);
                }
                else
                {
                    ECHO_ERROR('self',"Failed to stop GPDB, will try again.. [$retry / $max_retry]");
                    last;
                }

            }
        }
    }
}

sub check_gpdb_isRunning
{
    my $result;
    
    ECHO_INFO('self',"Checking if GPDB is running...");
    my $result = run_command('self',qq(ps -ef | grep silent | grep master | grep "^gpadmin" | grep -v sh | awk '{print \$2","\$8}'));
    my ($pid,$gphome) = split(/,/,$result->{'output'});
    ($gphome = $gphome) =~ s/\/bin\/postgres//g;

    ECHO_DEBUG('self',"GPDB pid: [$pid], GPHOM: [$gphome]");
    if ($pid =~ /\d+/) ## GPDB is running
    {
        ECHO_INFO('self',"GPDB is running, PID: [$pid], GPHOME: [$gphome]");
        $result->{'pid'} = $pid;
        $result->{'gphome'} = $gphome;
        return $result;
    }
    else  ## GPDB is not running
    {
        ECHO_INFO('self',"GPDB is not running");
        $result->{'pid'} = 0;
        return $result;
    }
}
