#!/bin/bash 

target_device=$1
if [ "x$target_device" == 'x' ]; then
    echo "You did not specific the target device, will set to default [WI-FI], to view the list of the aviliable device, run [# networksetup -listallnetworkservices]"
    target_device="WI-FI"
    echo ""
fi

### the list you would like to add:
domain_list="
*.jd.com
*.bilibili.com
*.wolkenservicedesk.com
*.jira.eng.vmware.com
*.eng.vmware.com
*.oc.vmware.com
*.broadcom.net
"
# *.confluence.eng.vmware.com
# *.vmware.com
# *.wolkenservicedesk.com

cur_list=`networksetup -getproxybypassdomains "WI-FI"`
need_add=''

for url in `echo $domain_list`;
do
    echo "checking if [$url] has already in the list..."
    count=`echo $cur_list | grep -w $url | wc -l | sed 's/ //g'`
#    echo "DEBUG: count is [$count]"
    if [ "x$count" != 'x0' ]; then
        echo "found [$url] in the list, skip..."
    else
        echo "Adding [$url]..."
        need_add=`echo -e "${need_add}\n${url}"`
    fi
done

final_list=`echo "$cur_list $need_add" | sed 's/\n/ /g'`
# echo $final_list

echo -e "\nUpdating the system proxybypassdomains.."
## networksetup -setproxybypassdomains <networkservice> <domain1> [domain2] [...]
networksetup -setproxybypassdomains "$target_device" $final_list
echo -e "Done, the proxybypassdomains now is like below:\n"
networksetup -getproxybypassdomains $target_device
