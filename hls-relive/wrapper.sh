#!/bin/bash

ID="$1"
STREAM="$2"

kill_children() {
	pkill -P $$
}

trap kill_children EXIT

source ../cfg

if [ ! -d "$RELIVE_DIR/$ID" ]
then
	mkdir "$RELIVE_DIR/$ID"
fi

while true
do
	perl ./record.pl $HLS_DIR "${STREAM}_native_sd.m3u8" $RELIVE_DIR/"$ID"
	sleep 1;
done
