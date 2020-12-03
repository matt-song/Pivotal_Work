#!/bin/bash
hosts="sdw1 sdw2"

### setup env
mkdir -vp /data/gptext/zoo-master/
for segHost in $hosts
do
    echo creating folder on $segHost 
    ssh $segHost "mkdir -vp /data/gptext/primary{1,2}"
done

