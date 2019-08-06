#!/usr/bin/perl
use strict;
use Getopt::Std;
use Term::ANSIColor;

my %opts; getopts('f:l:Dh', \%opts);
my $DEBUG = $opts{'D'};   
my $logFile = $opts{'f'};
my $lineEachFile = $opts{'l'};

### start work ###

&print_usage if $opts{'h'};   

my $allLines = get_total_lines_count($logFile);
split_logs($logFile,$allLines);


### functions ###

sub print_usage
{
    my $program = $0;
    ECHO_SYSTEM("Usage: $0 -f [log File] -l [lines per file]");
    exit 1;
}

sub get_total_lines_count
{
    my $log = shift;
    if ( ! -f $log )
    {   
        ECHO_ERROR("No such file [$log], exit!") ;
        &print_usage;
    }
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
    chomp(my $existing_split_file_count=`find ./ -name "${log}.split.*" | wc -l | sed 's/ //g'`);
    #print "$split_file_count";
    if ($existing_split_file_count > 0)
    {
        ECHO_INFO("Found [$existing_split_file_count] existing split files, remove it?");
        chomp(my $confirm = <STDIN>);
        if ($confirm =~ /y|yes/i )
        {
            ECHO_SYSTEM("Removing below files: ");
            system(qq(rm -v ./${log}.split.*));
        }
        else
        {
            ECHO_ERROR("cancelled by user, will append to the existing files, this is NOT recommended")
        }
    }

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