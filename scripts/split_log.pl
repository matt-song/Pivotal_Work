#!/usr/bin/perl
use strict;
use Getopt::Std;
use Term::ANSIColor;

my %opts; getopts('f:l:Dh', \%opts);
my $DEBUG = $opts{'D'};   
my $logFile = $opts{'f'};
my $lineEachFile = $opts{'l'};

### start work ###
## TBD, add help message 
my $allLines = get_total_lines_count($logFile);
split_logs($logFile,$allLines);


### functions ###

sub get_total_lines_count
{
    my $log = shift;
    ECHO_ERROR("No such file [$log], exit!",1) if ( ! -f $log );
    my $result = 0;

    ECHO_INFO("Calculating the count of lines in [$log]...");
    open FILE,"$log" or die { ECHO_ERROR("Unable to open log File [$log], exit",1)};
    while (<FILE>){$result++;};
    close FILE ;
    ECHO_INFO("Find [$result] lines in [$log]");
    return $result;
}

sub split_logs
{
    my ($log,$totoalCount) = @_;

    if (! $lineEachFile)
    {
        ECHO_SYSTEM("The log [$log] has [$totoalCount] lines, how much lines do you want to have in each split files?");
        while (1)
        {
            chomp($lineEachFile = <STDIN>);
            if ($lineEachFile !~ /^\d+$/)
            {
                ECHO_ERROR("Wrong format for intput [$lineEachFile], integer only!");
                next;
            }
            elsif ($lineEachFile > $totoalCount)
            {
                ECHO_ERROR("Invalid input [$lineEachFile], should not greater than [$totoalCount]!");
                next;
            }
            else
            {
                last;
            }
        }
    }
    ECHO_INFO("Will split [$log] into [$lineEachFile] lines for each files..");

    ### clean all split file before we start ###
    ### TDB, add check and skip if no files ###
    ECHO_INFO("Checking if any existing split file before we start...");
    system(qq(rm -i ./*.split.*));

    my $count=0; 
    my $file_id=0;

    open FILE,$log or die { ECHO_ERROR("Unable to open log File [$log], exit",1)};
    while (<FILE>)
    {
        chomp(my $line=$_);
        my $split_file_name="${log}.split.$file_id";
        open OUTPUT,'>>',$split_file_name or die { ECHO_ERROR("Unable to write to file [$split_file_name], exit",1)};
        print OUTPUT "$line\n";
        close OUTPUT;
        $count++;
        if ($count % $lineEachFile == 0)
        {
            $file_id++;
            ECHO_SYSTEM("Reached [$count] lines, switch to next output file [ ${log}.split.$file_id ]...");
        }
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