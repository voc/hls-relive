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

RELIVE_RESOLUTION=${RELIVE_RESOLUTION:-hd}
RELIVE_RECORDING_MODE=${RELIVE_RECORDING_MODE:-hls}

while true
do
	case $RELIVE_RECORDING_MODE in
		hls)
			perl ./record.pl $HLS_DIR "${STREAM}_native_${RELIVE_RESOLUTION}.m3u8" $RECORDING_DIR
			;;
		icedist)
			./record_icedist.sh "${ICEDIST_URL}/${STREAM}" $RECORDING_DIR
			;;
	esac

	sleep 1
done
