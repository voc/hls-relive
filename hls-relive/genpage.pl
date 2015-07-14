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
use Text::Template;

my $url_prefix = "//cdn.c3voc.de/releases/relive/";
my $schedule_path = '../data/schedule.xml';
my $releases_path = '../data/releases';
my $workdir = '/srv/releases/relive/';

Relive::Config::read_config "$FindBin::RealBin/../cfg", sub {
	my ($k, $v) = @_;

	if($k eq 'GENPAGE_URL_PREFIX') {
		$url_prefix = $v;
	} elsif($k eq 'RELIVE_DIR') {
		$workdir = $v;
	}
};

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

	return $newest - $oldest;
}

sub extract_image {
	my ($file, $out) = @_;

	system("ffmpeg -loglevel error -i '$file' -an -r 1 -filter:v 'scale=256:144' -vframes 1 -f image2 -vcodec mjpeg -y '$out'");
}

sub make_thumb {
	my ($event) = @_;

	my $dir = $event->{id};
	my @segments = sort glob "$dir/*.ts";

	return unless @segments;

	my $thumb_segment;
	if($event->{status} eq 'live') {
		$thumb_segment = $segments[$#segments];
	} elsif($event->{status} eq 'recorded' or $event->{status} eq 'released') {
		$thumb_segment = $segments[$#segments / 2];
	}

	my $thumb_path = "$dir/thumb.jpg";
	extract_image($thumb_segment, $thumb_path);
	$event->{thumbnail} = $url_prefix . $thumb_path;
}

sub mtime {
	my ($file) = @_;

	my @stat = stat($file);

	return $stat[9];
}

sub remux_mp4 {
	my ($event) = @_;

	my $dir = $event->{id};

	my $in = "$dir/index.m3u8";
	my $out = "$dir/muxed.mp4";

	if(not -f $out or (mtime($in) > mtime($out))) {
		system("ffmpeg -loglevel error -i '$in' -c:a copy -c:v copy -bsf:a aac_adtstoasc -movflags faststart -y '$out'");
	}

	$event->{mp4} = $url_prefix . $out;
}

my $fahrplan = Fahrplan->new(location => $schedule_path);
my $fp_events = $fahrplan->events;

my $released = decode_json(read_file($releases_path));

chdir($workdir) or die "chdir to workdir ($workdir) failed: $!";

opendir(my $dh, ".");

our $events = [];
while(my $id = readdir $dh) {
	next unless -d $id;
	next unless $id =~ /^[0-9]+$/;

	my $event;

	my $fev = (grep { $_->{id} == $id } @$fp_events)[0];
	$event->{id} = $id;
	$event->{room} = $fev->{room};
	$event->{title} = $fev->{title};

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
	}

	$event->{duration} = age_span($id);

	push @$events, $event;
}

closedir($dh);

write_file('index.json', encode_json($events));

my $template = Text::Template->new(TYPE => 'FILE', SOURCE => "$FindBin::Bin/template.tmpl");
write_file('index.html', {binmode => ':encoding(UTF-8)'}, $template->fill_in());
