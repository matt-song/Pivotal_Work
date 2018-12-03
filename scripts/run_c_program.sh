#!/bin/bash

FILE=$1

if [ "x"$FILE = "x" ]
then
    echo "Usage: $0 [file_name]"
    exit 1;

elif [ ! -f $FILE ]
then
    echo "no such file [$FILE]"
    exit 1

else
    mkdir -p "./.bin";
    gcc $FILE -o "./.bin/${FILE}.bin";
    chmod 755 "./.bin/${FILE}.bin";
    ./.bin/${FILE}.bin
fi

