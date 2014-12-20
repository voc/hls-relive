#!/bin/bash

ID="$1"
STREAM="$2"

kill_children() {
	pkill -P $$
}

trap kill_children EXIT


if [ ! -d "/srv/www/hls/$ID" ]
then
	mkdir "/srv/www/hls/$ID"
fi

while true
do
	perl ./record.pl /tmp/hls "${STREAM}_native_sd.m3u8" /srv/www/hls/"$ID"
	sleep 1;
done
