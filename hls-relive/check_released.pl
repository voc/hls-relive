#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use JSON;
use Data::Dumper;
use File::Slurp;
use LWP;

sub check200 {
	my ($url) = @_;

	my $ua = LWP::UserAgent->new;
	my $req = HTTP::Request->new(GET => $url);

	my $resp = $ua->request($req);

	return $resp->is_success;
}

if(@ARGV != 2) {
	say STDERR "usage: $0 media-events outfile";
	exit 1;
}

my $events = decode_json(read_file($ARGV[0]))->{events};

my $released_events = {};
if(-f $ARGV[1]) {
	$released_events = decode_json(read_file($ARGV[1]));
}

foreach my $event (@$events) {
	next if $released_events->{$event->{guid}};

	my $url = $event->{frontend_link};
	next unless defined $url;

	# check berlin, as this is the slave mirror and thus will always be the
	# last to receive the update
	$url =~ s!//media.ccc.de!//berlin.media.ccc.de!g;

	print "checking $url... ";
	if(check200($url)) {
		$released_events->{$event->{guid}} = $event->{frontend_link};
		say "ok";
	} else {
		say "not ok";
	}
}

write_file($ARGV[1], encode_json($released_events));
