package HLS::Playlist;

use v5.12;
use strict;
use warnings;

use Carp;
use File::Slurp;

sub new {
	my ($class) = @_;

	return bless {
		media_sequence_base => 0,
		next_media_sequence => 0,
		events => []
	}, $class;
}

sub from_string {
	my ($class, $str) = @_;

	my $ret = $class->new();
	$ret->parse($str);

	return $ret;
}

sub from_file {
	my ($class, $location) = @_;

	if(not -e $location) {
		croak "Input file does not exist";
	}

	my $contents = read_file($location);
	if(not $contents) {
		croak "Reading input file failed: $@";
	}

	return $class->from_string($contents);
}

sub add_discontinuity {
	my ($self) = @_;

	push @{$self->{events}}, {type => 'discontinuity'};
}

sub add_segment {
	my ($self, $duration, $title, $file) = @_;

	my $event = {
		type => 'segment',
		seq => $self->{next_media_sequence},
		duration => $duration,
		title => $title,
		file => $file
	};

	push @{$self->{events}}, $event;
	$self->{next_media_sequence}++;

	return $event;
}

sub parse {
	my ($self, $str) = @_;

	my @lines = split /[\n\r]+/, $str;

	if(shift(@lines) ne '#EXTM3U') {
		croak "Playlist is not a valid HLS file";
	}

	my $pl;
	my ($duration, $title);
	foreach my $line (@lines) {
		if($line =~ /^\#EXTINF:(\d*\.\d*),(.*)/) {
			$duration = $1;
			$title = $2;
		} elsif($line =~ /^#EXT-X-TARGETDURATION:(.*)/) {
			$self->{target_duration} = $1;
		} elsif($line =~ /^#EXT-X-MEDIA-SEQUENCE:(.*)/) {
			$self->{media_sequence_base} = $1;
			$self->{next_media_sequence} = $1;
		} elsif($line =~ /^#EXT-X-ENDLIST/) {
			$self->{complete} = 1;
		} elsif($line =~ /^#EXT-X-DISCONTINUITY/) {
			$self->add_discontinuity;
		} elsif($line =~ /^#EXT-X-VERSION/) {
		} elsif($line =~ /^#.*/) {
			carp "Unknown tag '$line'";
		} else {
			$self->add_segment($duration, $title, $line);
		}
	}
}

sub format {
	my ($self) = @_;

	my @lines;
	push @lines, '#EXTM3U';
	push @lines, '#EXT-X-VERSION:3';
	push @lines, '#EXT-X-MEDIA-SEQUENCE:' . $self->{media_sequence_base};
	push @lines, '#EXT-X-TARGETDURATION:' . $self->{target_duration};

	foreach my $event (@{$self->{events}}) {
		if($event->{type} eq 'discontinuity') {
			push @lines, '#EXT-X-DISCONTINUITY';
		}

		if($event->{type} eq 'segment') {
			push @lines, sprintf('#EXTINF:%f,%s',
				$event->{duration},
				$event->{title} // '');

			push @lines, $event->{file};
		}
	}

	if($self->{complete}) {
		push @lines, '#EXT-X-ENDLIST';
	}

	return join("\n", @lines);
}

sub write {
	my ($self, $location) = @_;

	write_file($location, $self->format) or croak "Writing playlist failed: $@";
}

sub get_segment {
	my ($self, $seq) = @_;

	return (grep {
		$_->{type} eq 'segment' &&
		$_->{seq} eq $seq;
	} @{$self->{events}})[0];
}

sub media_sequence_range {
	my ($self) = @_;

	my $min = $self->{media_sequence_base};
	my $max = $min;

	for(my $i = @{$self->{events}} - 1; $i >= 0; $i--) {
		my $event = $self->{events}[$i];

		next if $event->{type} ne 'segment';

		$max = $event->{seq};
		last;
	}

	return ($min, $max);
}

sub media_sequence_max {
	my ($self) = @_;

	use Data::Dumper; say Dumper($self);
	return ($self->media_sequence_range)[1];
}

1;
