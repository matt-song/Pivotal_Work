#!/usr/bin/perl
###########################################################################################
# Author:      Matt Song                                                                  #
# Create Date: 2019.11.14                                                                 #
# Description: Use this script to test the performance to each vultr site                 #
###########################################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('D', \%opts);

my $DEBUG = $opts{'D'};   




sub getVultrSites
{
    my $result;
    # curl -s https://www.vultr.com/resources/faq/#downloadspeedtests | grep 100MB | awk -F 'href=' '{print $2}' | grep -v ipv6 | grep https  | awk -F'/' '{print $3}'

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
