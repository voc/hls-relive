#!/bin/bash

ID="$1"
STREAM="$2"

kill_children() {
	pkill -P $$
}

trap kill_children EXIT

eval $(perl export-config.pl)

RECORDING_DIR="${RELIVE_OUTDIR}/${RELIVE_PROJECT}/${ID}"

if [ ! -d $RECORDING_DIR ]
then
	mkdir -p $RECORDING_DIR
fi

while true
do
	perl ./record.pl $HLS_DIR "${STREAM}_native_sd.m3u8" $RECORDING_DIR
	sleep 1
done
