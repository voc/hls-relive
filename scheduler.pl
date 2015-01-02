#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/lib";

use Fahrplan;

use DateTime;
use DateTime::Format::DateParse;
use DateTime::Format::Strptime;
use IPC::Run;

my $start_time = time;
my $fudge;

my $prerecord = 0;
my $postrecord = 0;
my @recorder = qw(wrapper.sh);

my $stream_map = {
	"Saal 1" => "s1",
	"Saal 2" => "s2",
	"Saal 6" => "s3",
	"Saal G" => "s4",
};

my $strp = DateTime::Format::Strptime->new(
	pattern => '%F %T %Z',
);

my $zone = DateTime::TimeZone->new( name => 'local' );

binmode STDOUT, ':encoding(UTF-8)';

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

sub read_events {
	my $fp = Fahrplan->new(location => $ARGV[0]);

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
		grep {$_->{"recording.optout"} eq "false"}
		grep {exists $stream_map->{$_->{room}}} @{$fp->events};

	#say Dumper([@events]);
	#say scalar @events;

	return @events;
}

my @events = read_events;
my $refresh_events = 0;
$SIG{'HUP'} = sub {
	$refresh_events = 1;
};

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

while(@events) {
	my $now = now;

	say "="x80;
	say "Now: ", $strp->format_datetime($now);

	if($refresh_events) {
		say "Refreshing events";
		@events = read_events;

		# remove all the events we are already recording
		@events = grep { not exists $recordings{$_->{id}} } @events;

		$refresh_events = 0;
	}

	my $next = $events[0];
	printf "Next event is: %s (starts %s)\n", $next->{title}, $strp->format_datetime($next->{start});
	
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
