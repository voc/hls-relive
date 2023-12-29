#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Carp;
use Data::Dumper;
use HLS::Playlist;
use Relive::Config;
use Fahrplan;
use JSON;
use File::Slurp;

my $project = $ENV{RELIVE_PROJECT};
if(not defined $project) {
	say STDERR "RELIVE_PROJECT environment variable must be defined";
	exit 1;
}

my $repo = $ENV{RELIVE_REPO} // "$FindBin::RealBin/../";

my $schedule_path = "${repo}/data/${project}/schedule.xml";
my $releases_path = "${repo}/data/${project}/releases";

my $config = Relive::Config::read_config (
	"${repo}/global_config",
	"${repo}/configs/${project}"
);

foreach my $k (qw(GENPAGE_URL_PREFIX RELIVE_OUTDIR)) {
	if(not defined $config->{$k}) {
		say STDERR "mandatory option $k not given in config";
		exit 1;
	}
}

my $url_prefix = $config->{GENPAGE_URL_PREFIX} . '/' . $project . '/';
my $outdir = $config->{RELIVE_OUTDIR} . '/' . $project . '/';

binmode STDOUT, ":encoding(UTF-8)";

sub age_span {
	my ($dir) = @_;

	if(not -d $dir) {
		croak "$dir is not a directory";
	}

	my ($oldest, $newest);

	opendir(my $dh, $dir);
	while(my $f = readdir $dh) {
		next unless $f =~ /\.ts$/;

		my $mtime = (stat("$dir/$f"))[9];

		if(not defined $oldest or $mtime < $oldest) {
			$oldest = $mtime;
		}

		if(not defined $newest or $newest < $mtime) {
			$newest = $mtime;
		}
	}

	closedir($dh);

	if(not defined $newest or not defined $oldest) {
		return 0;
	}

	return $newest - $oldest;
}

sub mtime {
	my ($file) = @_;

	my @stat = stat($file);

	return $stat[9];
}

sub make_thumb {
	my ($event) = @_;

	my $dir = $event->{id};
	my $thumb_path = "$dir/thumb.jpg";

	$event->{thumbnail} = $url_prefix . $thumb_path;
}

sub remux_mp4 {
	my ($event) = @_;

	my $dir = $event->{id};

	my $in = "$dir/index.m3u8";
	my $out = "$dir/muxed.mp4";

	$event->{mp4} = $url_prefix . $out;
}

sub make_sprites {
	my ($event) = @_;
	my $sprites_interval = 15;

	my $dir = $event->{id};

	my $in = "$dir/index.m3u8";
	my $out = "$dir/sprites.jpg";

	if(-f "${out}.meta") {
		my $meta = decode_json(read_file("${out}.meta"));

		$event->{sprites}{interval} = $sprites_interval;
		$event->{sprites}{url} = $url_prefix . $out;
		$event->{sprites}{n} = $meta->{n};
		$event->{sprites}{cols} = $meta->{cols};
	}
}

my $fahrplan = Fahrplan->new(location => $schedule_path);
my $fp_events = $fahrplan->events;

my $released;
if(-f $releases_path) {
	$released = decode_json(read_file($releases_path));
} else {
	$released = {};
}

if(not -e $outdir) {
	mkdir($outdir) or die "mkdir of outdir ($outdir) failed :$!";
}

chdir($outdir) or die "chdir to outdir ($outdir) failed: $!";

opendir(my $dh, ".");

my $latest_mtime = -1;

our $events = [];
while(my $id = readdir $dh) {
	next unless -d $id;
	next unless $id =~ /^[0-9]+$/;

	my $event;

	my $fev = (grep { $_->{id} == $id } @$fp_events)[0];
	next unless $fev;

	$event->{id} = $id;
	$event->{guid} = $fev->{guid};
	$event->{room} = $fev->{room};
	$event->{title} = $fev->{title};
	$event->{start} = $fev->{start}->epoch;
	$event->{mtime} = (stat("$id"))[9];

	if ($event->{mtime} > $latest_mtime) {
		$latest_mtime = $event->{mtime};
	}

	$event->{status} = "not_running"; # not_running, live, recorded, released
	if(-e "$id/index.m3u8") {
		my $pl = HLS::Playlist->from_file("$id/index.m3u8");
		$event->{status} = $pl->{complete} ? 'recorded' : 'live';

		$event->{playlist} = $url_prefix . "$id/index.m3u8";
	}

	my $frontend_url = $released->{$fev->{guid} // ""};
	if($frontend_url) {
		$event->{status} = 'released';
		$event->{release_url} = $frontend_url;
	}

	if($event->{status} ne "not_running") {
		make_thumb($event);
	}

	if($event->{status} eq "recorded") {
		remux_mp4($event);

		if($config->{SCRUB_THUMBS}) {
			make_sprites($event);
		}
	}

	$event->{duration} = age_span($id);

	push @$events, $event;
}

closedir($dh);

write_file('index.json.tmp', JSON->new->utf8->pretty->canonical->encode($events));
if ($latest_mtime > 0) {
	utime($latest_mtime, $latest_mtime, 'index.json.tmp');
}

rename('index.json.tmp', 'index.json');
