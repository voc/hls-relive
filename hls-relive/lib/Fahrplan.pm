package Fahrplan;

use v5.12;
use strict;
use warnings;

use Carp;

use Data::Dumper;
use DateTime::Format::Strptime;

use XML::LibXML;
use DateTime;
use DateTime::Format::DateParse;

sub get_child {
	my ($node, $path) = @_;

	my $children = $node->find($path);
	if($children->size != 1) {
		return "";
	}

	return $children->pop->textContent;
}

sub parse_duration {
	my ($duration) = @_;

	my ($h, $m) = split /:/, $duration;

	return DateTime::Duration->new(
		hours => $h,
		minutes => $m);
}

sub events {
	my ($self) = @_;

	return $self->{events};
}

sub new {
	my ($class, %params) = @_;

	my $dom;
	if (defined $params{location}) {
		$dom = XML::LibXML->load_xml(location => $params{location});
	} elsif (defined $params{string}) {
		$dom = XML::LibXML->load_xml(string => $params{string});
	} else {
		croak "need to give Fahrplan XML either via string or location";
	}

	my $root = $dom->documentElement;
	my $fahrplan;

	$fahrplan->{version} = get_child($root, 'version');
	$fahrplan->{acronym} = get_child($root, 'conference/acronym');
	$fahrplan->{title} = get_child($root, 'conference/title');

	my $event_nodes = $root->find('day/room/event');
	$event_nodes->foreach(sub {
			my ($ev) = @_;

			my $event = {};

			$event->{id} = $ev->{id};
			$event->{guid} = $ev->{guid};

			foreach my $key (qw(
						title subtitle track type language abstract description
						room slug recording/optout recording/license
					)) {
				my $skey = $key =~ tr!/!.!r;
				$event->{$skey} = get_child($ev, $key);
			}

			$event->{start} = DateTime::Format::DateParse->parse_datetime(get_child($ev, "date"));
			if ($params{offset}) {
				$event->{start}->add(seconds => $params{offset})
			}

			$event->{duration} = parse_duration(get_child($ev, "duration"));
			$event->{end} = $event->{start} + $event->{duration};

			push @{$fahrplan->{events}}, $event;
		});

	return bless $fahrplan, $class;
}

1;
