#!/bin/bash

ID="$1"
STREAM="$2"

exec perl ./record.pl /tmp/hls "${STREAM}_native_sd" /srv/www/hls
if [ ! -d "/srv/www/hls/$ID" ]
then
	mkdir "/srv/www/hls/$ID"
fi

