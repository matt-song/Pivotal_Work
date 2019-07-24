#!/usr/bin/perl
use strict;

my %opts; getopts('f:l:Dh', \%opts);
my $DEBUG = $opts{'D'};   
my $logFile = $opts{'f'};
my $lineEachFile = $opts{'l'};

open FILE,"$logFile" or die { print "Unable to open log File [$logFile], exit\n"; exit 1;};

my $count=0;
my $output_file = chomp(`basename $logFile`);
while (<FILE>)
{
    my $output = "$output_file"."$count"
    chomp(my $line = $_);
    open OUTPUT,'>','$output' or die { print "Unable to write into [$output], exit\n"; exit 1;};
    print OUTPUT $line ;
    $count++;
        
}
close FILE ;
