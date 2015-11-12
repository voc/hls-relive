#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/lib";

use Relive::Config;

my $project = $ENV{RELIVE_PROJECT};
if(not defined $project) {
	say STDERR "RELIVE_PROJECT environment variable must be defined";
	exit 1;
}

my $repo;
if(not defined $ENV{RELIVE_REPO}) {
	$repo = "$FindBin::RealBin/../";

	say "export RELIVE_REPO=\"$repo\"";
} else {
	$repo = $ENV{RELIVE_REPO};
}

my $config = Relive::Config::read_config (
	"${repo}/global_config",
	"${repo}/configs/${project}"
);

foreach my $k (sort keys %$config) {
	my $v = $config->{$k};

	$v =~ s/\\/\\\\/;
	$v =~ s/"/\\"/;

	say "export ${k}=\"${v}\"";
};
