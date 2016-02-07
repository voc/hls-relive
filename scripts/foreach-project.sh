#!/bin/bash

RELIVE_REPO=$(dirname $(realpath $0))/../
CMD="$1"

for project in $(find "${RELIVE_REPO}/configs/" -maxdepth 1 -type f -printf '%P\n' | egrep '^[^.]*$')
do
	export RELIVE_PROJECT="$project"
	$CMD
done
