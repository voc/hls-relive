#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use lib qw(./lib);
use Carp::Always;
use Linux::Inotify2;
use HLS::Playlist;
use Data::Dumper;
use List::Util qw(max);

if(@ARGV != 3) {
	say STDERR "usage: $0 in-dir in-m3u8 out-dir";
	exit 1;
}

my ($in_base, $in_m3u8, $out_base) = @ARGV;

################################################################################
# global variables
################################################################################

my $in_pl;
my $out_pl;
my $last_media_sequence;

################################################################################
# functions
################################################################################

sub update {
	say "got an update";

	my $sync = 0;
	foreach my $event (@{$in_pl->{events}}) {
		if($event->{type} eq 'discontinuity') {
			if($sync) {
				say "adding discont";
				$out_pl->add_discontinuity;
			}

			next;
		}

		if($event->{seq} < $last_media_sequence) {
			next;
		}

		if($event->{seq} == $last_media_sequence) {
			$sync = 1;
			next;
		}

		say "fetching segment " . $event->{file};
		my ($in_name) = $event->{file} =~ m!^.*?([^/]+)$!;
		my $out_name = $out_pl->{next_media_sequence} . '.ts';

		link "$in_base/$in_name", "$out_base/$out_name" or die "link failed: $!";

		$out_pl->add_segment($event->{duration}, $event->{title}, $out_name);
	}
}

################################################################################
# main
################################################################################

if(not -e "$in_base/$in_m3u8") {
	die 'input playlist does not exist';
}

if(-e "$out_base/index.m3u8") {
	say "output playlist already exists, resuming";
	$out_pl = HLS::Playlist->from_file("$out_base/index.m3u8");
	$out_pl->add_discontinuity;
} else {
	$out_pl = HLS::Playlist->new;
}

my $inotify = Linux::Inotify2->new;
$inotify->watch($in_base, IN_MOVED_TO, sub {
		my ($e) = @_;

		if($e->name ne $in_m3u8) {
			return;
		}

		$in_pl = HLS::Playlist->from_file($e->fullname);
		update;
	});

$in_pl = HLS::Playlist->from_file("$in_base/$in_m3u8");
my ($min, $max) = $in_pl->media_sequence_range;
$last_media_sequence = max($min, $max - 5);

update;

1 while $inotify->poll;
