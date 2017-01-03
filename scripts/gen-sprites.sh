#!/bin/bash

set -e

height=90

if [ "$#" -ne 3 ]
then
	echo "usage: $0 interval input output"
	exit 1
fi

interval="$1"
input="$2"
output="$3"

tmp=$(mktemp -d /tmp/sprites-XXXXXX)

cleanup() {
	rm -rf ${tmp}
}

trap cleanup EXIT

ffmpeg -loglevel error -i "$input" -vf select="not(mod(n\\,${interval})),scale=-1:${height}" -vsync passthrough "${tmp}/%06d.png"

nsprites=$(ls -1 ${tmp} | wc -l)
cols=$(echo "sqrt($nsprites)" | bc)

montage ${tmp}/* -tile ${cols}x -geometry +0+0 ${output}

cat > "${output}.meta" <<EOF
{
	"n": ${nsprites},
	"cols": ${cols}
}
EOF
