#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use JSON;
use Data::Dumper;
use File::Slurp;
use LWP::Simple;

sub get_json {
	my ($url) = @_;

	my $doc = get($url);
	if(not defined $doc) {
		return undef;
	}

	my $json = decode_json($doc);
	if(not defined $json) {
		return undef;
	}

	return $json;
}

sub count_recordings {
	my ($event) = @_;

	my $event_data = get_json($event->{url});

	if(defined($event_data) and defined($event_data->{recordings})) {
		return scalar(@{$event_data->{recordings}});
	} else {
		return 0;
	}
}

if(@ARGV != 2) {
	say STDERR "usage: $0 media-events outfile";
	exit 1;
}

my $events = decode_json(read_file($ARGV[0]))->{events};

my $old_released_events = {};
if(-f $ARGV[1]) {
	$old_released_events = decode_json(read_file($ARGV[1]));
}

my $released_events = {};
foreach my $event (@$events) {
	my $guid = $event->{guid};

	if($old_released_events->{$guid}) {
		$released_events->{$guid} = $old_released_events->{$guid};
		next;
	}

	print "checking $event->{slug}... ";

	my $recordings = count_recordings($event);
	if($recordings > 0) {
		$released_events->{$guid} = $event->{frontend_link};
		say "ok ($recordings)";
	} else {
		say "not ok";
	}
}

write_file($ARGV[1], encode_json($released_events));
