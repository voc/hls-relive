#!/bin/bash

STREAM="$1"
RECORDING_DIR="$2"

STARTTIME=$(date +%s)

if [ "${STREAM}" = "http://live.ber.c3voc.de:7999/nevoke_passthrough_h264" ]; then

exec ffmpeg -nostats -i $STREAM -c:v copy -c:a copy \
	-map 0:v:2 -map 0:a \
	-f hls \
	-hls_time 6 -hls_list_size 0 -hls_segment_filename "${RECORDING_DIR}/${STARTTIME}-%d.ts" -hls_flags +append_list+discont_start \
	"${RECORDING_DIR}/index.m3u8"

else

exec ffmpeg -nostats -i $STREAM -c:v copy -c:a copy \
	-map 0:v:0 -map 0:a \
	-f hls \
	-hls_time 6 -hls_list_size 0 -hls_segment_filename "${RECORDING_DIR}/${STARTTIME}-%d.ts" -hls_flags +append_list+discont_start \
	"${RECORDING_DIR}/index.m3u8"

fi
