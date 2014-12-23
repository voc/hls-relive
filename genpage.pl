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

if(@ARGV != 3) {
	say STDERR "usage: $0 schedule.xml media-events topdir";
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

my $fahrplan = Fahrplan->new(location => $ARGV[0]);
my $fp_events = $fahrplan->events;

my $media_events = decode_json(read_file($ARGV[1]))->{events};

chdir($ARGV[2]) or die "chdir to topdir failed: $!";

opendir(my $dh, ".");

my $events = [];
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

		$event->{playlist} = "$id/index.m3u8";
	}

	if(my @mevs = grep { $_->{guid} eq $fev->{guid} } @$media_events) {
		$event->{status} = 'released';
		$event->{release_url} = $mevs[0]->{frontend_link};
	}
	
	$event->{duration} = age_span($id);

	push @$events, $event;
}

closedir($dh);

write_file('index.json', encode_json($events));
