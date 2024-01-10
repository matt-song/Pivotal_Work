#!/bin/bash
tag=$1

if [ "x$tag" == 'x' ]
then
    echo "usage $0 <tag>"
    exit 1
fi

echo "updating local repository"

cd /Users/xsong/Documents/GPDB_Code/gp-gpdb6/gpdb-6X_STABLE
git checkout
git pull

echo "checking tag [$tag].."
git tag --contain $tag 


