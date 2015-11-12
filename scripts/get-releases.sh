#!/bin/bash

RELIVE_REPO=$(dirname $(realpath $0))/../
eval $(perl "${RELIVE_REPO}/hls-relive/export-config.pl")

DATA_DIR="${RELIVE_REPO}/data/${RELIVE_PROJECT}"
[ -d "$DATA_DIR" ] || mkdir "$DATA_DIR"

wget -q -O "${DATA_DIR}/media-events.tmp" http://api.media.ccc.de/public/conferences/"$MEDIA_CONFERENCE_ID"
if [ -s "${DATA_DIR}/media-events.tmp" ]
then
	mv "${DATA_DIR}/media-events.tmp" "${DATA_DIR}/media-events"
fi

perl "${RELIVE_REPO}/hls-relive/check_released.pl" "${DATA_DIR}/media-events" "${DATA_DIR}/releases" 2>/dev/null
