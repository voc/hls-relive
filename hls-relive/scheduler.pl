#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;
use utf8;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/lib";

use Fahrplan;
use Relive::Config;

use DateTime;
use DateTime::Format::DateParse;
use DateTime::Format::Strptime;
use IPC::Run;

my $project = $ENV{RELIVE_PROJECT};
if(not defined $project) {
	say STDERR "RELIVE_PROJECT environment variable must be defined";
	exit 1;
}

chdir($FindBin::RealBin);
my $repo = $ENV{RELIVE_REPO} // "$FindBin::RealBin/../";

my $start_time = time;
my $fudge = $ENV{RELIVE_FUDGE_DATE};

my @recorder = qw(./wrapper.sh);

my $strp = DateTime::Format::Strptime->new(
	pattern => '%F %T %Z',
);

my $zone = DateTime::TimeZone->new( name => 'local' );

binmode STDOUT, ':encoding(UTF-8)';

my $config = Relive::Config::read_config(
	"${repo}/global_config",
	"${repo}/configs/${project}"
);

my $prerecord = $config->{PRERECORD} // 900;
my $postrecord = $config->{POSTRECORD} // 900;

my $stream_map;
foreach my $k (keys %$config) {
	if($k =~ /^STREAM_(.*)/) {
		$stream_map->{$config->{$k}} = $1;
	}
}

say "Populated stream map as follows:";
foreach my $k (sort keys %$stream_map) {
	say "$k -> $stream_map->{$k}";
}

sub now {
	my $now;

	if(defined $fudge) {
		$now = DateTime::Format::DateParse->parse_datetime($fudge);
		$now->add(seconds => time - $start_time);
	} else {
		$now = DateTime->now;
	}

	$now->set_time_zone($zone);
}

if(scalar @ARGV > 1) {
	$fudge = shift @ARGV;
}

my $schedule_path = $ARGV[0];

sub read_events {
	my ($path) = @_;

	my $fp = Fahrplan->new(location => $path, offset => ($config->{FAHRPLAN_OFFSET} // 0));

	# sanity check: are we trying to record an empty/non-existent room?
	foreach my $room (keys %$stream_map) {
		if(grep({$_->{room} eq $room} @{$fp->events}) == 0) {
			say "Warning: room '$room' has no events in the schedule";
		}
	}

	my $now = now;

	# find all events
	#  - from the rooms we find interesting
	#  - that are going to be recorded
	#  - that have not ended yet
	#  - sorted from earliest to latest
	#  and add recording offsets
	my @events =
		map {
			$_->{start}->subtract(seconds => $prerecord);
			$_->{end}->add(seconds => $postrecord);
			$_
		}
		sort {DateTime->compare($a->{start}, $b->{start})}
		grep {DateTime->compare(now, $_->{end}) <= 0}
		grep {$_->{"recording.optout"} ne "true"}
		grep {exists $stream_map->{$_->{room}}} @{$fp->events};

	#say Dumper([@events]);
	#say scalar @events;

	return @events;
}

sub mtime {
	my ($f) = @_;

	return (stat($f))[9];
}

my @events = read_events($schedule_path);
my $schedule_ts = mtime($schedule_path);

my %recordings;
sub start_recording {
	my ($event) = @_;

	my $recording = {
		event => $event
	};

	$recording->{proc} = IPC::Run::start([@recorder, $event->{id}, $stream_map->{$event->{room}}]);

	$recordings{$event->{id}} = $recording;
}

sub stop_recording {
	my ($recording) = @_;

	$recording->{proc}->kill_kill;

	delete $recordings{$recording->{event}->{id}};
}

$SIG{'TERM'} = sub {
	foreach my $id (keys %recordings) {
		my $recording = $recordings{$id};

		$recording->{proc}->kill_kill;
	}

	exit 0;
};

$SIG{'INT'} = $SIG{'TERM'};

while(@events or keys(%recordings)) {
	my $now = now;

	say "="x80;
	say "Now: ", $strp->format_datetime($now);

	if(-e $schedule_path) {
		my $cur_mtime = mtime($schedule_path);
		if($schedule_ts < $cur_mtime) {
			say "Refreshing events";
			@events = read_events($schedule_path);

			# remove all the events we are already recording
			@events = grep { not exists $recordings{$_->{id}} } @events;

			$schedule_ts = $cur_mtime;
		}
	}

	my $next = $events[0];
	if(defined $next) {
		printf "Next event is: %s (starts %s)\n", $next->{title}, $strp->format_datetime($next->{start});
	} else {
		say "No next event. Waiting for recorders to finish.";
	}

	say "-"x80;

	say "Currently recording: ";
	foreach my $id (keys %recordings) {
		my $recording = $recordings{$id};

		printf " - %d: %s (ends %s)\n",
			$recording->{event}->{id},
			$recording->{event}->{title},
			$strp->format_datetime($recording->{event}->{end});
	}

	say "-"x80;

	# start recordings
	while($next and DateTime->compare($now, $next->{start}) >= 0) {
		my $event = shift @events;
		say "Event ", $event->{title}, " begins";

		start_recording($event);

		$next = $events[0];
	}

	# stop recordings
	foreach my $id (keys %recordings) {
		my $recording = $recordings{$id};

		if(DateTime->compare($now, $recording->{event}->{end}) >= 0) {
			say "Event ", $recording->{event}->{title}, " ends";

			stop_recording($recording);
		}
	}

	say "="x80;
	say "";

	sleep 10;
}

say "no events left";
exit 0;
