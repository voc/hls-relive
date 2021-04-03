#!/bin/bash

STREAM="$1"
RECORDING_DIR="$2"

STARTTIME=$(date +%s)

exec ffmpeg -nostats -i $STREAM -c:v copy -c:a copy \
	-map 0:v:0 -map 0:a:0 -map 0:a:1 \
	-f hls \
	-hls_time 6 -hls_list_size 0 -hls_segment_filename "${RECORDING_DIR}/${STARTTIME}-%d.ts" -hls_flags +append_list+discont_start+program_date_time \
	"${RECORDING_DIR}/index.m3u8"
