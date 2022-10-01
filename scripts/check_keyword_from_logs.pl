#!/usr/bin/perl
use strict;

my $file = 'gpdb-2022-01-13_000000.csv';
my $keyword = 'con2343606';
my $count=0;

open LOG,$file or die "no such file $file";
while (<LOG>)
{
  $count+=1;
  my $line = $_;
  chomp($line);
  if ( $line =~ /${keyword}/ )
  {
    print "$line \n";
  }
  print "have read $count lines...\n" if ($count % 10000000 ==  0);
}
close LOG;