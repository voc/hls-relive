#!/bin/bash

ID="$1"
STREAM="$2"

kill_children() {
	pkill -INT -P $$

	# ffmpeg is not especially reliable in correctly writing an EXT-X-ENDLIST tag
	# when dying. Fix this up ourselves.

	local playlist="${RECORDING_DIR}/index.m3u8"

	if [ -f "$playlist" ] && ! egrep -q '^#EXT-X-ENDLIST' "${RECORDING_DIR}/index.m3u8"
	then
		echo '#EXT-X-ENDLIST' >> "${RECORDING_DIR}/index.m3u8"
	fi
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
			./record_hls.sh "${ICEDIST_URL}/${STREAM}/native_${RELIVE_RESOLUTION}.m3u8" $RECORDING_DIR
                        ;;
		hls_local)
			perl ./record.pl $HLS_DIR "${STREAM}_native_${RELIVE_RESOLUTION}.m3u8" $RECORDING_DIR
			;;
		icedist)
			./record_icedist.sh "${ICEDIST_URL}/${STREAM}" $RECORDING_DIR
			;;
	esac

	sleep 1
done
