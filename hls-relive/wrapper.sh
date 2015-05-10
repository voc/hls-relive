#!/bin/bash

ID="$1"
STREAM="$2"

kill_children() {
	pkill -P $$
}

trap kill_children EXIT


if [ ! -d "/srv/releases/relive/$ID" ]
then
	mkdir "/srv/releases/relive/$ID"
fi

while true
do
	perl ./record.pl /tmp/hls "${STREAM}_native_sd.m3u8" /srv/releases/relive/"$ID"
	sleep 1;
done
