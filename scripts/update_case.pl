#!/usr/bin/perl
#################################################################
# Author:      Matt Song                                        #
# Create Date: 2018.12.03                                       #
# Description: Generate template for case management            #
#################################################################
use strict;
use Data::Dumper;
use Getopt::Std;
my %opts; getopts('hDt:c:l:', \%opts);
my $DEBUG = $opts{'D'};   
my $task = $opts{'t'};
my $case_to_check = $opts{'c'};
my $lang = $opts{'l'};

my $work_folder = '/Users/xsong/work';


if ($task =~ /template/i)
{
    my $input = &get_input();
    &generate_template($input);
}
elsif ($task =~ /find/i)
{
    &find_case_update($case_to_check);
}
elsif ($task =~ /ir/i)
{
    generate_ir($lang);
}
else
{
    &print_help;
}


##### functions #####
sub print_help
{
    print "
    Usage: 

    $0 -h                               // print this message
    $0 -t template                      // generate case update template
    $0 -t find -c [case number]         // find the case update 
    $0 -t ir -l cn                      // generate IR message

    Suggested alias:

    alias sf='perl $0 -t template'
    alias case_finder='perl $0 -t find -c'
    alias ir='perl $0 -t ir -l'
    alias ircn='perl $0 -t ir -l cn'
\n";
    exit 1;
}

sub generate_ir
{
    my $lang = shift;
    my $output = "";

    if ($lang =~ /cn/i)   ## cn version
    {
        $output = 'Hi,

您好, 感谢联系Pivotal Support, 我是工程师Matt, 很高兴为您服务.
我会检查case的记录并稍后联系您.

Best Regards,

Matt Song
APJ Data Customer Engineer | Pivotal Support
Email:   xsong@pivotal.io
Working Hours: Mon-Fri 8 AM to 5 PM GMT+8';
    }
    else                    ## en version
    {
        $output = 'Hi,

This is Matt from Pivotal support and I will assist you with this.

Let me review the requested information and I will get back to you shortly

Best Regards,

Matt Song
APJ Data Customer Engineer | Pivotal Support
Email:   xsong@pivotal.io
Working Hours: Mon-Fri 8 AM to 5 PM GMT+8';
    }
    print "$output"."\n";
    return 0;
}

sub find_case_update
{
    my $case = shift;

    if (! $case)
    {
        print "No case number was specified, exit!\n";
        &print_help;
    }

    my $case_update_file = "${work_folder}/${case}/case_update_${case}.txt";

    if (-f $case_update_file)
    {
        system("open $case_update_file");
    }
    else
    {
        print "Unable to find file [$case_update_file].\n";
        exit 1;
    }

}

sub get_input
{
    my $result;
    my $count = 0;
    print "Please paste the case info from sales force, end with CTRL-D\n";
    foreach my $line (<STDIN>)
    {
        chomp($line);
        print "The input is [$line]\n" if $DEBUG;
        $result->{$count} = $line;
        $count++;
    }
    return $result;
}

sub generate_template
{
    my $input = shift;
    my $total_line = scalar keys $input;
    my $count = 0;
    my ($product, $version, $case_no, $cur_sev);

    while ($count < $total_line)
    {
        my $line = $input->{$count};
        
        $product = $input->{($count+1)} if ($line =~ /^Product$/);
        $version = $input->{($count+1)} if ($line =~ /^Product Version$/);
        $case_no = $input->{($count+1)} if ($line =~ /^Case Number$/);
        $cur_sev = $input->{($count+1)} if ($line =~ /^Severity$/);

        $count++;
    }

    print "$product, $version, $case_no, $cur_sev \n" if $DEBUG;

    #### case update ####
    
    system('clear');
    my $case_update = "
================ GENERAL INFO ================

Case#:          $case_no
Product:        $product
Version:        $version
Severity:       $cur_sev

============= PROBLEM DESCRIPTION ============


=========== CONCLUSION / ROOT CAUSE ==========


============ TROUBLESHOOTING DONE ============


============== NEXT ACTION PLAN ==============


================ RELATED LOGS ================

";
    ### open the file after created template ###
    if ($case_no)
    {
        my $folder = "${work_folder}/${case_no}";
        system(qq(mkdir -p $folder));
        
        my $file = "${folder}/case_update_${case_no}.txt";
        
        ### asking user if he would like to overide the existing file ###
        if ( -f $file)
        {
            print "[$file] is already there, override it? <yes>";
            chomp(my $confirm = <STDIN>);
            if ($confirm =~ /n|no/i)
            {
                print $case_update;
                exit 1;
            }
        }
        open OUTPUT,'>',$file;
        print OUTPUT "$case_update";
        close OUTPUT;
        system("open $file");
    }

}
