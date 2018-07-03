#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Carp;
use Relive::Config;
use JSON;
use File::Slurp;

my $repo = $ENV{RELIVE_REPO} // "$FindBin::RealBin/../";

my $config = Relive::Config::read_config("${repo}/global_config");
foreach my $k (qw(GENPAGE_URL_PREFIX RELIVE_OUTDIR)) {
	if(not defined $config->{$k}) {
		say STDERR "mandatory option $k not given in config";
		exit 1;
	}
}

my $url_prefix = $config->{GENPAGE_URL_PREFIX};
my $outdir = $config->{RELIVE_OUTDIR};

binmode STDOUT, ":encoding(UTF-8)";

chdir($outdir) or die "chdir to outdir ($outdir) failed: $!";
opendir(my $dh, ".");

my $latest_mtime = -1;
my $projects = [];
while(my $name = readdir $dh) {
	next unless -d $name;
	next unless -f "${name}/index.json";

	my $config_path = "${repo}/configs/${name}";
	next unless -f $config_path;

	my $mtime = (stat("${name}/index.json"))[9];
	if ($mtime > $latest_mtime) {
		$latest_mtime = $mtime;
	}

	my $project;
	$project->{project} = $name;
	$project->{updated_at} = $mtime;
	$project->{index_url} = "${url_prefix}/${name}/index.json";

	my $project_config = Relive::Config::read_config($config_path);
	my $media_id = $project_config->{MEDIA_CONFERENCE_ID};
	if (defined $media_id and $media_id =~ /[0-9]+/) {
		$project->{media_conference_id} = $project_config->{MEDIA_CONFERENCE_ID} + 0;
	}

	push @$projects, $project;
}

closedir($dh);

write_file('index.json.tmp', JSON->new->utf8->pretty->canonical->encode($projects));
if ($latest_mtime > 0) {
	utime($latest_mtime, $latest_mtime, 'index.json.tmp');
}

rename('index.json.tmp', 'index.json');
