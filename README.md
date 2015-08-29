HLS ReLive
==========

This set of tools records portions of an HLS stream into separate
playlists for timeshifting and to bridge the time until the actual
recordings are available.

Components
----------

The ReLive system consists of several tools and cron jobs, some of which
can be used independently from the rest.

### record.pl

`record.pl` records HLS streams that are being generated locally by
watching the corresponding directory with inotify. It cannot record
streams via HTTP, nor will it perform any magic (like trying to figure
out at what position in the source m3u8 it stopped recording) when being
restarted: It will simply add a discontinuity header to the output m3u8
and resume adding segments. It turns out that this makes things much
simpler and is enough for our use case.

Usage: `record.pl in-directory in-m3u8 out-directory`

The m3u8 in the output directory will be named `index.m3u8`.

### scheduler.pl

`scheduler.pl` is responsible for starting and stopping recording
processes as dictated by the conference schedule. See below for
configuration details.

When sent a `SIGHUP`, it will reload its schedule, spawning or killing
recording subprocesses as necessary. Running recording subprocesses
which are still valid w.r.t. the new schedule remain untouched.

When sent a `SIGINT` or `SIGTERM` it shuts down all recording
subprocesses and then terminates itself.

Recording subprocesses are started via `wrapper.sh` which takes care of
setting up their environment (creating one directory per schedule event
to store the recording, amongst other things) and starting them.

### genpage.pl

`genpage.pl` looks through the directory with all the recordings,
cross-referencing them with the schedule and media.ccc.de, to find out
whether a proper release has happened yet. All this data is collected
and written into a file called `index.json` in the top-level recording
directory, which can then be used by the streaming frontend.

A recording can be in one of four states:
 - not_running: Transitory state where the recording directory has been
   created, but doesn't contain any data yet.
 - live: There is data present, but the playlist is not finished yet.
 - recorded: There is data present and the playlist is finished.
 - released: A recording of this talk has been found on media.ccc.de

A recording can move from the *recorded* state back to *live* if the
recording is restarted for some reason. Other than that, recordings
progress monotonically from *not_running* to *released*.

Starting from the *live* state, a thumbnail is generated. Once a
recording is *recorded*, the HLS files get remuxed into a faststarted
mp4 for easy download.

The `index.json` file contains an array of objects. A fully populated
object looks like this:

    {
       "thumbnail" : "//live.dus.c3voc.de/releases/relive/1549/thumb.jpg",
       "status" : "released",
       "duration" : 5399,
       "room" : "HS 7",
       "playlist" : "//live.dus.c3voc.de/releases/relive/1549/index.m3u8",
       "id" : "1549",
       "title" : "Btrfs – Das Dateisystem der Zukunft?",
       "release_url" : "http://media.ccc.de/browse/conferences/froscon/2015/froscon2015-1549-btrfs_das_dateisystem_der_zukunft.html"
    }

### check_released.pl

`check_released.pl` is a helper used by the `get-releases.sh` script. It
ensures that only events which have a generated frontend page are marked
as *released*.

### Cron jobs

There are three cron jobs:

  - calling get-releases.sh to download and cache the list of recordings
    already released on media.ccc.de
  - calling get-fahrplan.sh to download the schedule
  - calling genpage.pl to update `index.json` etc.

Configuration
-------------

All scripts get their configuration from the `cfg` file in the root of
the git repository. See `cfg.example` for an example. The config file
contains comments explaining the various options.

Setting up for a new conference
-------------------------------

The following steps are necessary to set up ReLive for a new conference:

  - update the configuration file appropriately
  - clear out the `data` directory (strictly speaking, only removing the
    `releases` file is necessary)
  - clear out the `RELIVE_DIR`, but keep `crossdomain.xml`
  - call `scheduler.pl` like this: `cd /home/relive/hls-relive; perl scheduler.pl ../data/schedule.xml`.
    You'll probably want to do that in a screen session.