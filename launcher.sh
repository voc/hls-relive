#!/bin/bash

cd $(dirname $(realpath $0))

if [[ -z "$1" ]]
then
	echo "usage: $0 project-name"
	exit 1
fi

project="$1"

if [[ ! -e "configs/$project" ]]
then
	echo "project '$project' does not exist"
	exit 1
fi

export RELIVE_PROJECT="$project"

cd hls-relive

eval $(perl export-config.pl)
if [[ ! -r "$HLS_DIR" || ! -x "$HLS_DIR" ]]
then
	echo "$HLS_DIR is not accessible"
	exit 1
fi

exec perl scheduler.pl "../data/${project}/schedule.xml"
