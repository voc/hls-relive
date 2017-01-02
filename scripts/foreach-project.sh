#!/bin/bash

RELIVE_REPO=$(dirname $(realpath $0))/../
CMD="$1"

lockname=/tmp/relive-$(echo "$CMD" | md5sum | cut -d' ' -f1)

if [ -e "${lockname}" ]
then
	pid=$(cat "$lockname")

	if [ -e "/proc/${pid}" ]
	then
		# lock is probably still alive, exit
		exit 0
	fi

	echo "removing stale lock file ${lockname} for cmd '${CMD}'"
	rm "${lockname}"
fi

echo "$$" > "${lockname}"

cleanup() {
	rm "${lockname}"
}

trap cleanup EXIT

for project in $(find "${RELIVE_REPO}/configs/" -maxdepth 1 -type f -printf '%P\n' | egrep '^[^.]*$')
do
	export RELIVE_PROJECT="$project"
	$CMD
done
