package Relive::Config;

use v5.12;
use strict;
use warnings;

sub read_config {
	my @paths = @_;
	my $chash;

	foreach my $path (@paths) {
		open(my $fh, '<:encoding(UTF-8)', $path) or die "opening config at '$path' failed: $!";

		while(my $line = <$fh>) {
			chomp($line);

			next if $line =~ /^#/;
			next if $line !~ /=/;

			my ($k, $v) = $line =~ /^([^=]*)=(.*)/;

			($v) = $v =~ /^"?(.*?)"?$/; #FIXME: do proper unescaping here

			$chash->{$k} = $v;
		}
	}

	return $chash;
}

1;
