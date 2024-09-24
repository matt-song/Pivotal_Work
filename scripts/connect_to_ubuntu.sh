#!/bin/bash

vmFolder="$HOME/Virtual Machines.localized/ubuntu_work.vmwarevm"
vmName='ubuntu_work'
user=matt

vmIP=`vmrun getGuestIPAddress "${vmFolder}/${vmName}.vmx"`
echo "Connecting to [$vmIP] ..."

ssh -o StrictHostKeyChecking=no ${user}@${vmIP}
