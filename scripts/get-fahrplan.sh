#!/bin/bash

cd ~

wget -q -O data/schedule.xml.tmp https://events.ccc.de/congress/2014/Fahrplan/schedule.xml
if [ -s data/schedule.xml.tmp ]
then
	mv data/schedule.xml.tmp data/schedule.xml
fi
