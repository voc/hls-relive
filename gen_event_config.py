#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import sys
import argparse
import requests
import jinja2


# request currently active conferences from streams API
r = requests.get('https://streaming.media.ccc.de/streams/v2.json?forceopen=yess')
#r = requests.get('http://localhost:8000/streams/v2.json')

if r.status_code != 200:
    print("Fetching streams API failed with response: ", r, r.text)
    exit(1)

conferences = r.json()

# list available conferences when argument is missing
if len(sys.argv) <= 1:
    print("Streams API currenly lists following conferences:")
    for c in conferences:
        print(" - {}".format(c['slug']))
print()

parser = argparse.ArgumentParser()
parser.add_argument('slug', help="slug aka acronym of a confernce currenly active at streaming website")
args = parser.parse_args()


# filter for our conferences specified by argument
conference = None
for c in conferences:
    if c['slug'] == args.slug:
        conference = c
        break

if conference is None:
    print("Error – unknown conference: " + args.slug)
    exit(1)

#print(conference)

if 'schedule' not in conference or conference['schedule'] is None:
    print("Warning: Schedule URL is empty!");


# generate config and write it to a file
templateLoader = jinja2.FileSystemLoader(searchpath="configs")
templateEnv = jinja2.Environment(loader=templateLoader)
template = templateEnv.get_template("cfg.example.j2")

output = template.render( conference )
config_file = 'configs/' + args.slug
with open(config_file, 'w') as f:
    f.write(output)
print("The new config was successfully written to " + config_file)
print("Next:")
print(" - check config and apply manual adjustments")
print(" - after a minute, a cronjob will run and download the schedule")
# TODO?: run scripts/get-fahrplan.sh from this script?
print(" - then start the scheduler (run as user relive): ./launcher.sh " + args.slug)
