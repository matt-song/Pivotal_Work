#!/usr/bin/perl
use strict;

open FILE,'>',"./test_file" or die "can not open file, exit",  "UTF-8";
print "this is some message\n";
close FILE;

