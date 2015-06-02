package Relive::Config;

use v5.12;
use strict;
use warnings;

sub read_config {
	my ($path, $cb) = @_;

	open(my $fh, '<', $path) or die "opening config failed: $!";

	while(my $line = <$fh>) {
		chomp($line);

		next if $line =~ /^#/;
		next if $line !~ /=/;

		my ($k, $v) = split /=/, $line;

		($v) = $v =~ /^"?(.*?)"?$/; #FIXME: do proper unescaping here

		$cb->($k, $v);

	}
}

1;
