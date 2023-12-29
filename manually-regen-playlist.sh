#!/bin/bash

if [ -z "${1:-}" ]; then
	echo "Usage: $0 /video/relive/[eventname]/[talkid]"
	exit 1
fi

set -e
set -o pipefail
cd "${1}"

echo "Please wait, this might take a while..."

maxseg="$(ls *.ts | cut -d'-' -f2 | sort -h | tail -n 1 | cut -d'.' -f1)"
tmpfile="$(mktemp)"

(
cat << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:8
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-DISCONTINUITY
#EXT-X-DISCONTINUITY
EOF
for i in $(seq 1 "${maxseg}"); do
	echo "Segment $i / ${maxseg}..." >&2
	segment="$(echo *"-$i.ts")"
	length="$(ffprobe -hide_banner -print_format json -show_streams "${segment}" 2>/dev/null | jq '.streams[0].duration' | cut -d'"' -f2)"
	if [ ! "${length}" = "null" ]; then
		echo "#EXTINF:${length},"
		echo "${segment}"
	fi
done
echo "#EXT-X-ENDLIST"
) > "${tmpfile}"

mv "${tmpfile}" "${1}/index.m3u8"
echo "Done!"

