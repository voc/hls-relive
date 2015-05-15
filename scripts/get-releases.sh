#!/bin/bash

cd $(dirname $(realpath $0))/../

source ./cfg

wget -q -O data/media-events.tmp http://api.media.ccc.de/public/conferences/"$MEDIA_CONFERENCE_ID"
if [ -s data/media-events.tmp ]
then
	mv data/media-events.tmp data/media-events
fi

perl hls-relive/check_released.pl data/media-events data/releases 2>/dev/null
