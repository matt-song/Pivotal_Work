#!/bin/perl
use strict;
my %opts; getopts('Dt:', \%opts); 
my $data_folder='/data/matt/data_folder';

my $count_SP_LCT_M_CMPUSR_D_TMP1 = 10;
my $count_SP_CMPUSR_D_TMP_FINAL01 = 10;
my $count_TMP_LAC_CELL_R =80;

my $change_random = 10;

my $table = $opts{'t'};


sub generate_data
{
    my $table = shift;

    if ($table =~ /SP_LCT_M_CMPUSR_D_TMP1/i)        ## other_party_35,lac_cell_35,0,0
    {
        print $
    }



}

sub gen_random
{
    my $max = shift;
    $max = 100 if (! $max);
    chomp(my $value = `echo $(($RANDOM % $max))`);
    return $value;
}