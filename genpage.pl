#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Data::Dumper;
use HLS::Playlist;
use Fahrplan;
use JSON;
use File::Slurp;

if(@ARGV != 3) {
	say STDERR "usage: $0 schedule.xml media-events topdir";
	exit 1;
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
	
	push @$events, $event;
}

closedir($dh);

write_file('index.json', encode_json($events));
