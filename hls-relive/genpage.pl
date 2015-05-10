#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Carp;
use Data::Dumper;
use HLS::Playlist;
use Fahrplan;
use JSON;
use File::Slurp;
use Text::Template;

#my $url_prefix = "http://cdn.c3voc.de/releases/relive/";
my $url_prefix = "http://live.dus.c3voc.de/releases/relive/";

binmode STDOUT, ":encoding(UTF-8)";

if(@ARGV != 3) {
	say STDERR "usage: $0 schedule.xml released topdir";
	exit 1;
}

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

my $fahrplan = Fahrplan->new(location => $ARGV[0]);
my $fp_events = $fahrplan->events;

my $released = decode_json(read_file($ARGV[1]));

chdir($ARGV[2]) or die "chdir to topdir failed: $!";

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

	$event->{duration} = age_span($id);

	push @$events, $event;
}

closedir($dh);

write_file('index.json', encode_json($events));

my $template = Text::Template->new(TYPE => 'FILE', SOURCE => "$FindBin::Bin/template.tmpl");
write_file('index.html', {binmode => ':encoding(UTF-8)'}, $template->fill_in());
