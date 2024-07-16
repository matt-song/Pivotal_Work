#!/usr/bin/perl
=README
#############################################################################
Author:         Matt Song
Creation Date:  2024.07.04

Setup:
- CPAN: install JSON

Features:
- Use this script to download the product of VMware GPDB/Postgres

Workflow:
1. List all the product (slug), choose the target product
2. list the version, choose the version
3. list all the package and download the target package

Others:
- API doc: https://developer.broadcom.com/xapis/tanzu-api/latest/all-tanzu-apis

Update:
- <TBD>


#############################################################################
=cut
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use File::Basename;
use JSON;
use Encode qw(encode_utf8);

# use Switch;
my %opts; getopts('r:D', \%opts);
my $DEBUG = $opts{'D'};

my $workDir = "/tmp/download_product.$$"; 
my $localTokenFolder = "$ENV{'HOME'}/.token";
run_command("mkdir -p $workDir");  ## create work dir


### Start the work

# step1: login
loginTanzuNet();

# Step1: get the product
my $targetProductSlug = getAllDatabaseProduct();

# Step2: get the release verion
getReleases($targetProductSlug);



sub getReleases
{
    my $productSlug = shift;
    #API: https://network.tanzu.vmware.com/api/v2/products/{product_slug}/releases
    my $url = "https://network.tanzu.vmware.com/api/v2/products/$productSlug/releases";
    my $curlResult = getContentFromURL($url);
    if ($curlResult->{'code'} == '200')
    {
        my $outputJson = $curlResult->{'content'};
        my $allReleases = decode_json($outputJson)->{'releases'};
        # print Dumper $allReleases;
        my $input = readAndReturn("Please input which version you would like to download, input [a] to list all the releases");
        if ($input eq 'a')
        {
            listAllRleaseAndChoose($allReleases);
        }
        ### loop all the releases
        for my $release ( @$allReleases)
        {
            if ($release->{'version'} eq '$input' )
            {
                ECHO_INFO("Found [$input]!");
            } 
            else
            {
                ECHO_ERROR("Can not find such relase [$input], listing all the aviliable version, please choose the correct one",1); 
                listAllRleaseAndChoose($allReleases);

            }
        }
    }

    sub listAllRleaseAndChoose
    {
        my $releaseHash = shift;
        my $result;
        my $id = 0;
        for my $release (sort @$allReleases)
        {
            $id++;
            $result->{$id} = $releaseHash->{'version'};
            ECHO_SYSTEM(qq([$id]     $releaseHash->{'version'} ) );
        }
        while (1)
        {
            my $input = readAndReturn("Please choose which release you would like to download? []");
            if (($input<1)||($input>$id))
            {
                ECHO_ERROR("Wrong input, please input a correct number")
            }
            else
            {
                return $result->{$id};
            }
        }
    }
}






###### Functions ######

sub loginTanzuNet
{
    # curl -X POST https://network.tanzu.vmware.com/api/v2/authentication/access_tokens -d '{"refresh_token":"8cab349d7b064406b4e562efce2f90ee-r"}'

    my $localTokenFile = "$localTokenFolder/.token_cache";

    if ( -e $localTokenFile ) 
    {
        ECHO_INFO("Find existing token cache, try login now...");
        open TOKEN,$localTokenFile or die { ECHO_ERROR("Can not read token file [$localTokenFile], please check and retry")};
        chomp(my $refreshToken = <TOKEN>);
        close TOKEN; ECHO_DEBUG("Token is [$refreshToken]");
        my $code = tryLogin($refreshToken);

        if ($code != '200')
        {
            ECHO_ERROR("the token in the cache is not correct, please retry!");
            tryLoginUntilSuccess()
        }
    }
    else   ## try ask for token
    {
        tryLoginUntilSuccess();
    }

    sub tryLogin
    {
        my $token = shift;
        my $APIurl = 'https://network.tanzu.vmware.com/api/v2/authentication/access_tokens';
        my $header = qq( {"refresh_token":"$token"} );
        my $resultHASH = getContentFromURL($APIurl, $header);

        if ($resultHASH->{'code'} == '200')
        {
            run_command("[ -d $localTokenFolder ] || mkdir -v $localTokenFolder");
            open CACHE,'>',$localTokenFile; #or die {ECHO_ERROR("Can not update cache file [$localTokenFile], please check and try again!")};
            print CACHE $token; close CACHE;
        }
        return $resultHASH->{'code'};
    }
    sub AskForTokenAndLogin
    {
        my $token = readAndReturn("Please input your refresh_token: ");
        my $code = tryLogin($token);
        return $code;
    }
    sub tryLoginUntilSuccess
    {
        while (1)
        {
            my $httpCode = AskForTokenAndLogin();
            if ($httpCode == '200')
            {
                ECHO_INFO("Login successful!");
                last;
            }
            else 
            {
                ECHO_ERROR("Login unsuccessful, please check your token and try again!",1);
            }
        }
    }    
}

sub readAndReturn
{
    my $message = shift;
    ECHO_SYSTEM("$message");
    chomp(my $input = <STDIN>); 
    return $input;
}
sub getAllDatabaseProduct
{
    my $outputJson;
    my $resultHASH = getContentFromURL('https://network.tanzu.vmware.com/api/v2/products');
    if ($resultHASH->{'code'} == '200')
    {
        $outputJson = $resultHASH->{'content'};
    }
    else
    {
        ECHO_ERROR("Failed to get content from API, please check and try again");
    }
    
    my $allProducts= decode_json($outputJson)->{'products'};
    #print Dumper $products;

    my $productListForDB;
    my $id = 0;
    for my $product (@$allProducts)
    {
        my $productName = encode_utf8($product->{'name'});
        if ($productName  =~ /greenplum|postgres/i)
        {
            $id++;
            # my $slug = $product->{'slug'}; 
            $productListForDB->{$id}->{'slug'} = $product->{'slug'}; 
            $productListForDB->{$id}->{'product'} = $productName;
            
            # ECHO_INFO("Find product $productName ");
            # ECHO_INFO("  slug = $product->{'slug'} ");
        }
        else
        {
            next;
        }
    }

#          '1' => {
#                   'product' => 'VMware Tanzu Greenplum® Command Center',
#                   'slug' => 'gpdb-command-center'}
    ECHO_INFO("Here is the product list: ");
    for (my $i == 1; $i <= $id; $i++ )
    {
        ECHO_SYSTEM("$i      $productListForDB->{$i}->{'slug'}      $productListForDB->{$i}->{'product'}");
    }
    while (1)
    {
        my $choice = readAndReturn("please choose which one you would like to download: [1~$id]");
        if (($choice < 1)||($choice > $id))
        {
            ECHO_ERROR("wrong input, please input a correct id of the product",1);
        }
        else
        {
            #print Dumper $productListForDB->{$choice};
            return $productListForDB->{$choice}->{'slug'};
        }
    }
}



### get the content of the URL, only return value if http code is 200, save the outpout into workfolder
### example curl -o /tmp/aaa -s -w "%{http_code}\n" https://network.tanzu.vmware.com/api/v2/products
sub getContentFromURL
{
    my ($url, $header, $isPOST) = @_;

    my $result='';
    ### visit the URL
    my $outputFile = "$workDir/curl_output.txt";
    run_command(qq( [ -f $outputFile ] && rm -f $outputFile || echo ) ); 
    my $curlCommand = qq(curl -o $workDir/curl_output.txt -s -w "%{http_code}" $url);
    
    if ($header)
    {
        $curlCommand .= qq( -d '$header')
    }
    if ($isPOST)
    {
        ## TBD
    }

    ECHO_DEBUG("the final curl command is [$curlCommand]");
    my $result = run_command($curlCommand); my $httpCode = $result->{'output'};

    open OUTPUT, $outputFile or die {ECHO_ERROR("Can not open output file [$outputFile]!") } ;
    my $content=<OUTPUT>; 
    ECHO_DEBUG("The content of the file is [$content]");
    close OUTPUT;

    $result->{'code'} = $httpCode;
    $result->{'content'} = $content;

    if ($httpCode != '200')
    {
        ECHO_ERROR("the curl command [$curlCommand] returned code [$httpCode], please check your url and try again, here is the content of the page",1);
        ECHO_ERROR($content,1);
    }
    return $result;
}


sub run_command
{
    my ($cmd, $err_out) = @_;
    my $run_info;
    $run_info->{'cmd'} = $cmd;

    ECHO_DEBUG("will run command [$cmd]..");
    chomp(my $result = `$cmd 2>&1` );
    my $rc = "$?";
    ECHO_DEBUG("Return code [$rc], Result is [$result]");

    $run_info->{'code'} = $rc;
    $run_info->{'output'} = $result;

    if ($rc)
    {
        ECHO_ERROR("Failed to excute command [$cmd], return code is $rc");
        ECHO_ERROR("ERROR: [$run_info->{'output'}]", $err_out);
    }
    else
    {
        ECHO_DEBUG("Command excute successfully, return code is [$rc]");
        ECHO_DEBUG("The result is [$run_info->{'output'}]");
    }
    return $run_info;

}

### define function to make the world more beautiful ###
sub ECHO_SYSTEM
{
    my ($message) = @_; printColor('yellow',"$message"."\n");
}
sub ECHO_DEBUG
{
    my ($message) = @_; printColor('cyan',"[DEBUG] $message"."\n") if $DEBUG;
}
sub ECHO_INFO
{
    my ($message, $no_return) = @_; printColor('green',"[INFO] $message"); print "\n" if (!$no_return);
}
sub ECHO_ERROR
{
    my ($Message,$onErrorContinue) = @_;
    printColor('red',"[ERROR] $Message"."\n");
    unless ($onErrorContinue)
    {
        ECHO_INFO("Removing the working directory [$workDir]");
        run_command("rm -rf $workDir",1) if ( -d $workDir);
        exit(1);
    }
    else
    {
        # ECHO_SYSTEM("[WARN] Continue with error...");
        return 1;
    }
}
sub printColor
{
    my ($Color,$MSG) = @_; print color "$Color"; print "$MSG"; print color 'reset';
}

## clean up the work dir
run_command("rm -rf $workDir"); 