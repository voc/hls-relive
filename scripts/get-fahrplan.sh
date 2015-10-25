#!/bin/bash

cd $(dirname $(realpath $0))/../

source ./cfg

wget --no-check-certificate -q -O data/schedule.xml.tmp "$FAHRPLAN_URL"
if [ -s data/schedule.xml.tmp ]
then
	mv data/schedule.xml.tmp data/schedule.xml
fi
