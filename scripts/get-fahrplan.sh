#!/bin/bash

source ./cfg

wget -q -O data/schedule.xml.tmp "$FAHRPLAN_URL"
if [ -s data/schedule.xml.tmp ]
then
	mv data/schedule.xml.tmp data/schedule.xml
fi
