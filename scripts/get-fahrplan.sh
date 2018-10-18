#!/bin/bash

RELIVE_REPO=$(dirname $(realpath $0))/../
eval $(perl "${RELIVE_REPO}/hls-relive/export-config.pl")

DATA_DIR="${RELIVE_REPO}/data/${RELIVE_PROJECT}"
[ -d "$DATA_DIR" ] || mkdir "$DATA_DIR"

if [ -z "$FAHRPLAN_URL" ]
then
       exit 0
fi

wget --timeout=10 --no-check-certificate -q -O "${DATA_DIR}/schedule.xml.tmp" "$FAHRPLAN_URL"
if [ -s "${DATA_DIR}/schedule.xml.tmp" ]
then
	mv "${DATA_DIR}/schedule.xml.tmp" "${DATA_DIR}/schedule.xml"
fi
