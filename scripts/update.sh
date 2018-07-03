#!/bin/bash

RELIVE_REPO=$(dirname $(realpath $0))/../

"${RELIVE_REPO}/scripts/foreach-project.sh" "perl ${RELIVE_REPO}/hls-relive/genpage.pl"
perl "${RELIVE_REPO}/hls-relive/make-index.pl"
