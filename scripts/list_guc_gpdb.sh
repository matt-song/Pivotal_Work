#!/bin/bash

export http_proxy="socks5://localhost:1086"
export https_proxy="socks5://localhost:1086"

link=https://raw.githubusercontent.com/greenplum-db/gpdb/main/src/backend/utils/misc/guc_gp.c
curl -s $link | grep "{\"" | awk -F',' '{print $1}' | sed 's/{"//g' | sed 's/\"//g' | sed 's/\t//g' | sed 's/ //g' | sort -u
