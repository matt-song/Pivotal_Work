#!/bin/bash
#
# Disclaimer : Please verify the script mentioned in the documents on a test cluster 
# before running it on production or important clusters/database, 
# as those scripts are for education purpose only and no offical support is provided for any bug.
#
#

# Starting the program.

echo "INFO - Starting the program"

# Checking if the debug option has been provided as a parameter with the script.
# If yes, turn it on else turn it off.

[ "$1" = "-d" ] && debug=on || debug=off

# Parameters for the script 
# This are the parameters that will be used in the later part of the scripts.

echo "INFO - Generating the directories name / location where the output logs will saved / stored"

export script=$0
export script_basename=`basename $script`
export script_dir=`dirname $script`/..
cd $script_dir
export script_dir=`pwd`
export install_dir=`dirname $script_dir`
export tmpdir=$script_dir/tmp
export wrkdir=/tmp/wrkdir.$$
export prod_name="Pivotal Greenplum"
export dldir="/data/package"
export api_token="TvzDy4hwz8wwrwoUMysU"

# Make working directory that will be used to store temporary files and 
# this will be removed when the script ends.

echo "INFO - Creating the directory needed for the program"

mkdir -p ${wrkdir}

# Clean up function
# The below functions traps user cancellation like CTRL + C and does the cleanup 

clean_up()
{
    trap ":" 1 2 3 15
    if [ "${SIGSET}" ]
    then
        printf "\n%s aborted...\n"  $(basename $0)
        [ -f "${dldir}/${target_file}" ] && rm -f ${dldir}/${target_file}
    fi
    [ "${wrkdir}" ] && rm -rf ${wrkdir}
}

# Clean up if the script is quit

trap "SIGSET=TRUE;clean_up;exit 1" 1 2 3 15

# Get download directory or hard code and remove the next hash mark

echo "INFO - Setting the download directory to: " $dldir

while [ -z ${dldir} ]; do
    read -p "Enter the download directory : " dldir
    if [ ! -d "${dldir}" ]
    then
        printf "\n%s does not exist...\n" ${dldir}
        unset dldir
    elif [ ! -w "${dldir}" ]
    then
        printf "\n%s is not writable...\n" ${dldir}
        unset dldir
    fi
done
[ ${debug} = 'on' ] && echo "dldir=\""${dldir}"\""

# Get api_token or hard code and remove the next hash mark

echo "INFO - Setting the connection token" 

if [ -z ${api_token} ]; then
    echo -e "\nTo get your API Token"
    echo -e "\n \t + Connect to network.pivotal.io with your username / password"
    echo -e "\t + Click on Edit profile"
    echo -e "\t + Scroll to the bottom on the page where you will see your API Token. \n"
fi

[ -z ${api_token} ] && read -p "Enter your network.pivotal.io API Token: " api_token
[ ${debug} = 'on' ] && echo "api_token=\""${api_token}"\""

# Authenticate the API Token

echo "INFO - Authenticating the API Token" 

curl --silent -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token ${api_token}" -X GET https://network.pivotal.io/api/v2/authentication > ${wrkdir}/authenticate

if [ $(grep -c "HTTP/1.1 200 OK" ${wrkdir}/authenticate) -ne 1 ]
then
    printf "Authentication failed, please check your API Token and try again.  Exiting...\n"
cat ${wrkdir}/authenticate
    clean_up
    exit 1
fi

# Get products list & request the user on which product do they choose.

echo "INFO - Getting the product list"

curl --silent -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token ${api_token}" -X GET https://network.pivotal.io/api/v2/products | python -mjson.tool > ${wrkdir}/prod_list
grep '"name":' ${wrkdir}/prod_list | egrep -vi 'suite|foundry|buildpacks' | cut -d'"' -f4 | sort > ${wrkdir}/prod_name_list

# Get product name

# printf "\nThese are the available products:\n\n"
# column ${wrkdir}/prod_name_list  

# printf "\n"
# while true; do
#     read -p "Which product do you want to download? " prod_name
#     if [ $(grep -c "^${prod_name}$" ${wrkdir}/prod_name_list) -eq 1 ]
#     then
#         break
#     else
#         printf "Sorry can't find that product, please re-enter the product name from the list above\n"
#     fi
# done

# echo "INFO - Setting the product list to: " $prod_name

echo "INFO - Setting the product list to: " $prod_name  

if [ $(grep -c "^${prod_name}$" ${wrkdir}/prod_name_list) -eq 1 ]
    then
    echo "INFO - Product name \""$prod_name"\" found, continue ..."
else
    echo "WARN - Couldn't find the product name \""$prod_name"\" from the product list something could have changed, please pick up the exact name from below" 
    printf "\nThese are the available products:\n\n"
    column ${wrkdir}/prod_name_list | grep Greenplum
    printf "\n"
    while true; do
        read -p "Which product do you want to download? " prod_name
        if [ $(grep -c "^${prod_name}$" ${wrkdir}/prod_name_list) -eq 1 ]
            then
            break
        else
            printf "Sorry can't find that product, please re-enter the product name from the list above\n"
        fi
    done
fi
[ ${debug} = 'on' ] && echo "Product Name=\""${prod_name}"\""

# Get slug

echo "INFO - Getting the Slug ID"

export prod_slug=$(sed -n "/\"${prod_name}\"/,/\"slug\"/p" ${wrkdir}/prod_list | tail -1 | cut -d'"' -f4)
[ ${debug} = 'on' ] && echo "prod_slug=\""${prod_slug}"\""

# Get product ID

echo "INFO - Getting the Product ID"

export prod_id=$(curl --silent -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token ${api_token}" -X GET https://network.pivotal.io/api/v2/products | python -mjson.tool | sed -n "/${prod_slug}\/releases/,/\"id\":/p" | tail -1 | tr -dc '[:digit:]')
[ ${debug} = 'on' ] && echo "prod_id=\""${prod_id}"\""

# Get the release

echo "INFO - Getting the Releases"

curl --silent -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token ${api_token}" -X GET https://network.pivotal.io/api/v2/products/${prod_slug}/releases | python -mjson.tool > ${wrkdir}/prod_releases

# Get version and request which version would they like to choose.

echo "INFO - Getting the product version"

printf "\nThese are the available versions:\n\n"
grep '"version":' ${wrkdir}/prod_releases | cut -d'"' -f4
printf "\n"
while true; do
    read -p "Which version of greenplum database do you want to download (for eg.s 4.3.4.0) ? " prod_version
    if [ $(grep -c "\"version\": \"${prod_version}\"" ${wrkdir}/prod_releases) -eq 1 ]
    then
        break
    else
        printf "Sorry can't find that version, please re-enter the product version from the list above\n"
    fi
done
[ ${debug} = 'on' ] && echo "prod_version=\""${prod_version}"\""

# Get release ID

echo "INFO - Getting the Release ID"

export rel_id=$(tac ${wrkdir}/prod_releases | sed -n "/${prod_version}/,/id/p"|tail -1|tr -dc '[:digit:]')
[ ${debug} = 'on' ] && echo "rel_id=\""${rel_id}"\""

# Get file ID

echo "INFO - Getting the File ID"

curl --silent -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token ${api_token}" -X GET https://network.pivotal.io/api/v2/products/${prod_slug}/releases/${rel_id} | python -mjson.tool > ${wrkdir}/prod_fileid

# Get file to download and request user on which file they would like to download.
# If there are multiple version that the user gets to choose the version of that file.

echo "INFO - Obtaining the files available for the release"
printf "\nThese are the available files:\n\n"
sed -n "/\"download\":/,/\"name\":/p" ${wrkdir}/prod_fileid | grep name | cut -d'"' -f4
printf "\n"
while true; do
    read -p "Which  files do you want to download (copy the entire line from above)? " prod_file
        if [ $(grep -c "\"name\": \"${prod_file}\"" ${wrkdir}/prod_fileid) -eq 1 ]; then
            echo -e "INFO - Setting up request to download the file: " $prod_file
            prod_file=$(sed 's/[\/]/\\\//g' <<< $prod_file)  #This is to escape the file name that has / on the name ( like PL/PERL ) , since the sed assumes that it is its command
            export download_url=$(tac ${wrkdir}/prod_fileid | sed -n "/\"name\": \"${prod_file}\"/,/\/download\"/p"|tail -1|cut -d'"' -f4)
            [ ${debug} = 'on' ] && echo "download_url=\""${download_url}"\""
            export target_file=$(basename $(tac ${wrkdir}/prod_fileid | sed -n "/\"name\": \"${prod_file}\"/,/aws_object_key/p"|tail -1|cut -d'"' -f4))
            [ ${debug} = 'on' ] && echo "target_file=\""${target_file}"\""
            break
        elif [ $(grep -c "\"name\": \"${prod_file}\"" ${wrkdir}/prod_fileid) -gt 1 ]; then
            echo -e "\nINFO - Found multiple version for file:" $prod_file
            prod_file=$(sed 's/[\/]/\\\//g' <<< $prod_file)
            tac ${wrkdir}/prod_fileid | sed -n "/\"name\": \"${prod_file}\"/,/\/download/p" > ${wrkdir}/prod_fileid_version
            printf "\nThese are the available version for the file:\n\n"
            tac ${wrkdir}/prod_fileid | sed -n "/\"${prod_file}\"/,/file_version/p" | grep file_version | cut -d '"' -f 4
            printf "\n"
            while true; do
                read -p "Which version of the file \" ${prod_file} \" do you want to download? " prod_file_version
                if [ $(grep -c "\"file_version\": \"${prod_file_version}\"" ${wrkdir}/prod_fileid_version) -eq 1 ]; then
                    export download_url=$(cat ${wrkdir}/prod_fileid_version | sed -n "/\"file_version\": \"${prod_file_version}\",/,/\/download\"/p"|tail -1|cut -d'"' -f4)
                    [ ${debug} = 'on' ] && echo "download_url=\""${download_url}"\""
                    export target_file=$(basename $(cat ${wrkdir}/prod_fileid_version | sed -n "/\"file_version\": \"${prod_file_version}\",/,/aws_object_key/p"|tail -1|cut -d'"' -f4))
                    [ ${debug} = 'on' ] && echo "target_file=\""${target_file}"\""
                    break
                else
                    printf "sorry can't find the version, please re-enter the version again from the list above \n"
                fi
            done
            break
        else
            printf "Sorry can't find that file, please re-enter the product file from the list above\n"
        fi
done


export download_url=$(tac ${wrkdir}/prod_fileid | sed -n "/\"name\": \"${prod_file}\"/,/\/download\"/p"|tail -1|cut -d'"' -f4)
[ ${debug} = 'on' ] && echo "download_url=\""${download_url}"\""

export target_file=$(basename $(tac ${wrkdir}/prod_fileid | sed -n "/\"name\": \"${prod_file}\"/,/aws_object_key/p"|tail -1|cut -d'"' -f4))
[ ${debug} = 'on' ] && echo "target_file=\""${target_file}"\""

# Accept EULA

echo "INFO - Accepting the agreement"

curl --silent -H "Accept: application/json" -H "Content-Type: application/json" -H "Content-Length: 0" -H "Authorization: Token ${api_token}" -X POST https://network.pivotal.io/api/v2/products/${prod_slug}/releases/${rel_id}/eula_acceptance | python -mjson.tool > ${wrkdir}/eula_acceptance

if [ $(grep -c "accepted_at" ${wrkdir}/eula_acceptance) -ne 1 ]
then
    if [ $(grep -c "\"status\": 401" ${wrkdir}/eula_acceptance) -eq 1 ]
    then
        printf "EULA acceptance failed, user could not be authenticated.  Exiting...\n"
    elif [ $(grep -c "\"status\": 404" ${wrkdir}/eula_acceptance) -eq 1 ]
    then
        printf "EULA acceptance failed, product or release cannot be found.  Exiting...\n"
    else
        printf "EULA acceptance failed, command reults were:\n"
        cat ${wrkdir}/eula_acceptance
        printf "Exiting...\n"
    fi
    clean_up
    exit 1
fi

# Show environment variables if debug mode is on

if [ ${debug} = 'on' ]
then
    echo
    echo "Variables to export to match the executed environment"
    echo "export dldir=\""${dldir}"\""
    echo "export api_token=\""${api_token}"\""
    echo "export prod_name=\""${prod_name}"\""
    echo "export prod_slug=\""${prod_slug}"\""
    echo "export prod_version=\""${prod_version}"\""
    echo "export prod_id=\""${prod_id}"\""
    echo "export rel_id=\""${rel_id}"\""
    echo "export prod_file=\""${prod_file}"\""
    echo "export download_url=\""${download_url}"\""
    echo "export target_file=\""${target_file}"\""
fi

# Download product file

echo "INFO - Downloading the file"

wget --output-document="${dldir}/${target_file}" --post-data="" --header="Authorization: Token ${api_token}" ${download_url} --no-check-certificate

# Successful message

echo "INFO - Download successful, file: \""$prod_file"\" , Location: \""${dldir}"\""
printf "\n"

# Clean up on exit

clean_up
exit 0
