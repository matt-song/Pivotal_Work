#!/usr/bin/perl
#################################################################
# Author:      Matt Song                                        #
# Create Date: 2020.07.16                                       #
# Description: Install Postgres                                 #
#################################################################
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
my %opts; getopts('hf:Dy', \%opts);

-cut
Steps: 
1. check if already installed  

2. install  the rpm
2. 
-note 
