#!/usr/bin/perl
=README
#############################################################################
Author:            Matt Song
Date of creation:  2024.07.04

Setup:
1. # yum -y install gcc cpan
2. # sudo cpan
3. # install JSON / install Text::Table

Features:
- Use this script to download the product of VMware GPDB/Postgres

Workflow:
1. List all the product (slug), choose the target product
2. list the version, choose the version
3. list all the package 
4. Accept the EULA and download the target package

Others:
- API doc: https://developer.broadcom.com/xapis/tanzu-api/latest/all-tanzu-apis

Update:
- 2024.08.05: minor bug fix, optimized the output.

#############################################################################
=cut
use strict;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Std;
use File::Basename;
use JSON;
use Text::Table; ## format the output
use Encode qw(encode_utf8);

# use Switch;
my %opts; getopts('r:D', \%opts);
my $DEBUG = $opts{'D'};

my $workDir = "/tmp/download_product.$$"; 
my $localTokenFolder = "$ENV{'HOME'}/.token";
my $downloadFolder = '/data/packages';
run_command("mkdir -p $workDir");  ## create work dir

### Start the work

# step1: login
my $loginInfo = loginTanzuNet();

# Step1: get the product
my $targetProductSlug = getAllDatabaseProduct();

# Step2: get the release verion
my $targetReleaseInfo = getReleases($targetProductSlug);

## Step3: get file list from above product_files `https://network.tanzu.vmware.com/api/v2/products/<slug>/releases/<releaseID>/product_files` 
# print Dumper $loginInfo;
getFileListFromRelease($targetProductSlug, $targetReleaseInfo->{'releaseID'}, $targetReleaseInfo->{'eula'}, $loginInfo->{'content'});




###### Functions ######

sub getFileListFromRelease
{
    my ($slug,$releaseID,$eulaUrl,$accessToken) = @_;
    ECHO_DEBUG("API parameter info: [$slug|$releaseID|$eulaUrl|$accessToken]");
    my $url = "https://network.tanzu.vmware.com/api/v2/products/$slug/releases/$releaseID/product_files";
    my $curlResult = getContentFromURL($url);
    if ($curlResult->{'code'} == '200')
    {
        my $outputJson = $curlResult->{'content'};
        my $allFiles = decode_json($outputJson)->{'product_files'};
        # print Dumper $allFiles;
        ECHO_INFO("Listing all files aviliable for download...\n");
        my $id = 0; my $targetFile;
        ### generate the list
        my $table = Text::Table->new("ID", "FILE");
        for my $file (sort @$allFiles)
        {
            $id++;
            $targetFile->{$id}->{'name'} = $file->{'name'};
            $targetFile->{$id}->{'url'} = $file->{'_links'}->{'download'};
            $targetFile->{$id}->{'fileName'}  = basename($file->{'aws_object_key'});
            # ECHO_SYSTEM(qq([$id]     $file->{'name'}));
            $table->load(["[$id]    ", "$file->{'name'}    "]);
        }
        print $table;
        while (1)
        {
            my $input=readAndReturn("Please choose the file you would like to download: [1 ~ $id]");
            if (($input<1)||($input>$id))
            {
                ECHO_ERROR("Wrong input, please input a correct number",1);
            }
            else
            {   
                # print Dumper $targetFile;
                downloadFile($targetFile->{$input}, $eulaUrl, $accessToken);
                return 0;
            }
        }  
    }
    else
    {
        ECHO_ERROR("Unable to access API link [$url], please check and try again!");
    }

    sub downloadFile
    {
        my ($fileInfo, $eulaUrl, $tokenString) = @_;
        ### accept the eula:curl -X POST -H "Authorization: Bearer <token>" <eula_url>
        my $decoded_json = decode_json($tokenString);
        my $accessToken = $decoded_json->{access_token};
        $accessToken = "Authorization: Bearer $accessToken";

        ## set the date to ' ' here, to avoid error "POST requests require a <code>Content-length<" 
        ## refer to https://stackoverflow.com/questions/33492178/how-to-pass-content-length-value-in-header-using-curl-command
        my $curlResult = getContentFromURL($eulaUrl,' ',1,$accessToken);  
        if ($curlResult->{'code'} == '200')
        {
            ECHO_INFO("Accepted EULA from link: [$eulaUrl]");
            ECHO_INFO("Trying to download the file now...");
            # print "=== $fileInfo->{'url'}->{'href'} ===";
            my $downloadUrl = $fileInfo->{'url'}->{'href'};
            my $fileName = $fileInfo->{'fileName'};

            my $path = readAndReturn("Where do you want store the file? default location is [$downloadFolder]");
            unless ($path)
            {
                $path = $downloadFolder;
            }
            run_command(qq(mkdir -p $path) );
            my $downloadCurlCMD = qq( curl -o $path/$fileName -L -H  "$accessToken" $downloadUrl);
            # my $downloadResult = run_command($downloadCurlCMD);
            system(qq($downloadCurlCMD 2>&1) );
            # if ($downloadResult->{'code'} == 0)
            if ($? == 0)
            {
                ECHO_INFO("File has been downloaded into [$path/$fileName]");
                return 0;
            }
        }
        else
        {
            ECHO_ERROR("Unable to accept the eula from link [$eulaUrl], the token is [$accessToken], please check again try again!");
        }    
    }
}

sub getReleases
{
    my $productSlug = shift;
    my $targetReleaseID;
    #API: https://network.tanzu.vmware.com/api/v2/products/{product_slug}/releases
    my $url = "https://network.tanzu.vmware.com/api/v2/products/$productSlug/releases";
    my $curlResult = getContentFromURL($url);
    if ($curlResult->{'code'} == '200')
    {
        my $outputJson = $curlResult->{'content'};
        my $allReleases = decode_json($outputJson)->{'releases'};
        # print Dumper $allReleases;
        my $input = readAndReturn("Please input which version you would like to download, input [a] to list all the releases");
        
        ### list all product
        if ($input eq 'a')
        {
            $targetReleaseID = listAllRleaseAndChoose($allReleases);
            return $targetReleaseID;
        }
        
        ### loop all the releases
        my $found = 0;
        for my $release ( @$allReleases)
        {
            # ECHO_DEBUG("input: [$input], checking [$release->{'version'}]...");
            # print Dumper $release;
            if ($release->{'version'} eq $input )
            {
                ECHO_INFO("Found [$input]!");
                $found = 1;
                if ($found)
                {
                    my $result;
                    $result->{'version'} = $release->{'version'};
                    $result->{'releaseID'} = $release->{'id'};
                    $result->{'eula'} = $release->{'_links'}->{'eula_acceptance'}->{'href'};
                    # print Dumper $result;
                    return $result;

                }
            } 
        }
        unless ($found)
        {
            ECHO_ERROR("Can not find such relase [$input], listing all the aviliable version, please choose the correct one",1); 
            $targetReleaseID = listAllRleaseAndChoose($allReleases);
            return $targetReleaseID;
        }
    }
    else
    {
        ECHO_ERROR("Unable to access API link [$url], please check and try again!");
    }

    sub listAllRleaseAndChoose
    {
        my $releaseHash = shift;
        my $result;
        my $id = 0;
        # print Dumper $releaseHash;
        my @sorted_array = sort { $a->{'version'} cmp $b->{'version'} } @$releaseHash;
        my $table = Text::Table->new("ID", "VERSION");
        for my $release (@sorted_array)
        {
            $id++;
            $result->{$id}->{'version'} = $release->{'version'};
            $result->{$id}->{'releaseID'} = $release->{'id'};
            $result->{$id}->{'eula'} = $release->{'_links'}->{'eula_acceptance'}->{'href'};
            # ECHO_SYSTEM(qq([$id]     $release->{'version'} ) );
            $table->load(["[$id]    ", "$release->{'version'}    "]);
        }
        print $table;
        while (1)
        {
            my $input = readAndReturn("Please choose which release you would like to download? []");
            if (($input<1)||($input>$id))
            {
                ECHO_ERROR("Wrong input, please input a correct number",1);
            }
            else
            {   
                # print Dumper $result->{$id};
                return $result->{$input};
            }
        }
    }
}

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
        my $loginAttempt = tryLogin($refreshToken);

        if ($loginAttempt->{'code'} != '200')
        {
            ECHO_ERROR("the token in the cache is not correct, please retry!",1);
            my $loginResult = tryLoginUntilSuccess();
            return $loginResult;
        }
        else
        {
            #print Dumper $loginAttempt;
            return $loginAttempt;
        }
    }
    else   ## try ask for token
    {
        my $loginResult = tryLoginUntilSuccess();
        return $loginResult;
    }

    sub tryLogin
    {
        my $token = shift;
        my $APIurl = 'https://network.tanzu.vmware.com/api/v2/authentication/access_tokens';
        my $header = qq( {"refresh_token":"$token"} );
        my $resultHASH = getContentFromURL($APIurl, $header);

        if ($resultHASH->{'code'} == '200')
        {
            run_command("[ -d $localTokenFolder ] || mkdir -v $localTokenFolder",1);
            open CACHE,'>',$localTokenFile; #or die {ECHO_ERROR("Can not update cache file [$localTokenFile], please check and try again!")};
            print CACHE $token; close CACHE;
        }
        return $resultHASH;
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
            my $result = AskForTokenAndLogin();
            if ($result->{'code'} == '200')
            {
                ECHO_INFO("Login successful!");
                return $result;
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
    # print Dumper $allProducts;

    my $productListForDB;
    my $id = 0;
    my $table = Text::Table->new("ID", "SLUG", "Description");
    for my $product (@$allProducts)
    {
        my $productName = encode_utf8($product->{'name'});
        if ($productName  =~ /greenplum|postgres/i)
        {
            $id++;
            $productListForDB->{$id}->{'slug'} = $product->{'slug'}; 
            $productListForDB->{$id}->{'product'} = $productName;
            $table->load(["[$id]    ", "$productListForDB->{$id}->{'slug'}    ", "$productListForDB->{$id}->{'product'}"]);
        }
        else
        {
            next;
        }
    }
    ECHO_INFO("Here is the product list: \n");
    print $table;

    while (1)
    {
        my $choice = readAndReturn("\nplease choose which one you would like to download: [1~$id]");
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
    my ($url, $data, $isPOST, $header) = @_;

    my $result='';
    ### visit the URL
    my $outputFile = "$workDir/curl_output.txt";
    run_command(qq( [ -f $outputFile ] && rm -f $outputFile || echo ) ); 
    my $curlCommand = qq(curl -o $workDir/curl_output.txt -s -w "%{http_code}" $url);
    
    if ($data)
    {
        $curlCommand .= qq( -d '$data');
    }
    if ($isPOST)
    {
        $curlCommand .= qq( -X POST );
    }
    if ($header)
    {
        $curlCommand .= qq( -H "$header" );
    }

    ECHO_DEBUG("the final curl command is [$curlCommand]");
    my $result = run_command($curlCommand,1); my $httpCode = $result->{'output'};
    my $content;

    if (-f $outputFile)
    {
        open OUTPUT, $outputFile or die {ECHO_ERROR("Can not open output file [$outputFile]!") } ;
        $content=<OUTPUT>; 
        ECHO_DEBUG("The content of the file is [$content]");
        close OUTPUT;
    }
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
    my ($cmd, $onErrorContinue) = @_;
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
        if ($onErrorContinue)
        {
            ECHO_ERROR("Failed to excute command [$cmd], return code is $rc",1);
            ECHO_ERROR("ERROR: [$run_info->{'output'}]", 1);
        }
        else
        {
            ECHO_ERROR("Failed to excute command [$cmd], return code is $rc");
            ECHO_ERROR("ERROR: [$run_info->{'output'}]");
        }
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