#!/bin/bash

vmFolder='/Users/xsong/Documents/Virtual Machines.localized/ubuntu_20.vmwarevm'
vmName='ubuntu_20'
# logFile='vmware.log'
user=matt

# vmIP=`cat ${vmFolder}/${logFile} | grep  "vmx IP" | grep en0 | awk -F'IP=' '{print $NF}' | awk '{print $1}' | grep -v [a-z] | tail -1`
vmIP=`vmrun getGuestIPAddress "${vmFolder}/${vmName}.vmx"`
echo "Connecting to [$vmIP] ..."

ssh -o StrictHostKeyChecking=no ${user}@${vmIP}
