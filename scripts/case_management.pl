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
elsif ($task =~ /eogs/i)
{
    generate_eogs_template();
}
elsif ($task =~ /log/i)
{
    generate_ask_log_template($case_to_check);
}
elsif ($task =~ /report/i)
{
    my $input = &get_input();
    generate_case_report($input);
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
    $0 -t eogs                          // generate end of general support message
    $0 -t log <-c log>                  // generate ask log message

    Suggested alias:

    alias sf='perl $0 -t template'
    alias case_finder='perl $0 -t find -c'
    alias ir='perl $0 -t ir -l'
    alias ircn='perl $0 -t ir -l cn'
    alias eogs='perl $0 -t eogs'
    alias logs='perl $0 -t log -c'
\n";
    exit 1;
}

sub generate_case_report
{
    my $input = shift;
    my $total_line = scalar keys %$input;
    my $count = 0;
    my ($case_no, $case_title, $customer);

    system('clear');
    my $report_file = "${work_folder}/case_report.txt";
    open REPORT,'>',$report_file or die "Unable to open file [$report_file]";
    while ($count < $total_line)
    {
        my $line = $input->{$count};
        if ($line =~ /^\d+$/)
        {
            $case_no = $input->{$count};
            $customer = $input->{$count+1};
            $case_title = $input->{$count+2};
            print REPORT "$case_no    $customer    $case_title\n\n\n";
        }
        $count++;
    }
    system("open -a \"/Applications/Sublime Text.app/Contents/MacOS/sublime_text\" $report_file");
    return 0;
}

sub generate_ask_log_template
{
    my $case = shift;

    print "Hi,\n
Good day to you. Cloud you please help provide below info/files so we can check further?

1. Please help collect the logs from master and problematic segment server, you may collect the logs via GPMT. Please check below KB for more reference:
https://community.pivotal.io/s/article/Greenplum-Magic-Tool-GPMT?language=en_US
https://docs.vmware.com/en/VMware-Greenplum/6/greenplum-database/utility_guide-ref-gpmt-gp_log_collector.html

2. Please check if we have any core file has been generated during the time segment crash. Please check below KB for more reference:
https://community.pivotal.io/s/article/How-to-Collect-Core-Files-for-Analysis
https://docs.vmware.com/en/VMware-Greenplum/6/greenplum-database/utility_guide-ref-gpmt-packcore.html

3. Please collect the minirepro of the query
https://community.pivotal.io/s/article/How-to-Collect-DDL-and-Statistics-Information-Using-the-Minirepro-Utility

4. To analyze a hung session:
https://community.pivotal.io/s/article/Analyze-Session-Tool-Automates-Debug-Tracing-for-Hung-Greenplum-Sessions?language=en_US

5. To enable core dump on the server
https://community.pivotal.io/s/article/how-to-enable-core-generation-on-a-server?language=en_US
";

    if ($case)
    {
        print "\nYou may upload the file to https://securefiles.pivotal.io/dropzone/customer-service/$case\n";
    }
    return 0;
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

sub generate_eogs_template
{
    my $ver = shift;
    print "
We noticed that you opened this ticket under a version of GPDB that has been removed from General support. General Support for GPDB version [$ver] ended at [date]
Link: https://community.pivotal.io/s/article/Greenplum-Software-End-of-Life-Cycle-Policy 

We recommend you to upgrade to Supported Version to resume getting regular support.

Please let me know what your upgrade plans are.

I’m putting this ticket handling on hold, awaiting your response”
";
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
        my $cmd = qq(open -a "/Applications/Sublime Text.app/Contents/MacOS/sublime_text" $case_update_file);
        system($cmd);
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
    my $total_line = scalar keys %$input;
    my $count = 0;
    my ($product, $version, $case_no, $cur_sev);

    while ($count < $total_line)
    {
        my $line = $input->{$count};

        $product = $1 if ($line =~ /^Product(\w+\s+.*)$/);
        $version = $1 if ($line =~ /^Product Version(.*)$/);
        $case_no = $1 if ($line =~ /^Case Number(\d+)$/);
        $cur_sev = $1 if ($line =~ /^SeveritySeverity (\d+ - \w+)$/); 

        ### capture again since Saleforce changes a lot ... shit ###
        $product = $input->{($count+1)} if ($line =~ /^Product$/);
        $version = $input->{($count+1)} if ($line =~ /^Product Version$/);
        $case_no = $input->{($count+1)} if ($line =~ /^Case Number$/);
        $cur_sev = $input->{($count+1)} if ($line =~ /^Severity$/);

        $count++;
    }

    print "$product, $version, $case_no, $cur_sev \n" if $DEBUG;

    #### case update ####
    
    system('clear');
    my $case_update = qq(
### GENERAL INFO

Case#:          $case_no
Product:        $product
Version:        $version
Severity:       $cur_sev

 

### PROBLEM DESCRIPTION 

- the issue is xxxx

 

### CONCLUSION / ROOT CAUSE 

- root cause...

 

### TROUBLESHOOTING DONE 

- did xxx
- done xxx
- tried aaa

 

### NEXT ACTION PLAN 

- next action is....

 

### RELATED LOGS 

```
llogs
```
);
    ### open the file after created template ###
    if ($case_no)
    {
        my $folder = "${work_folder}/${case_no}";
        system(qq(mkdir -p $folder));
        
        my $file = "${folder}/case_update_${case_no}.md";
        
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
        system("open -a \"/Applications/Sublime Text.app/Contents/MacOS/sublime_text\" $file");
    }

}
