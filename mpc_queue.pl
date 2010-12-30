#!/usr/bin/perl
use warnings;
use strict;

my $dry = 0;
my %playlist;

if(@ARGV && $ARGV[0] eq '-n'){
	$dry = 1;
	shift;
}

sub get_playlist()
{
	for(map { chomp; $_ } `mpc_choose.sh ls`){
		die "couldn't parse \"$_\"\n" unless /^\s+([0-9]+)\s+(.*)$/;
		$playlist{$1} = $2;
	}
}

sub usage()
{
	print STDERR "Usage: $0 song1 [song2 [song3...]]\n";
	exit 1;
}

sub playing()
{
	return system('mpc status|grep playing > /dev/null') == 0;
}

sub mpc
{
	my $cmd = 'mpc ' . join(' ', @_) . ' > /dev/null';
	my $ret = system $cmd;

	if($ret){
		die "$ret = $cmd\n";
	}
}

sub getnam($)
{
	for(values %playlist){
		return $_ if m/$_[0]/io;
	}
	die "Couldn't find $_[0]\n";
}

sub getid($)
{
	for(keys %playlist){
		return $_ if $playlist{$_} =~ m/$_[0]/io;
	}
	die "Couldn't find $_[0]\n";
}

usage() unless @ARGV;

get_playlist();

for(@ARGV){
	print "queued " . getid($_) . ' (' . getnam($_) . ")\n";
}

exit 0 if $dry;

for(@ARGV){
	mpc('single on');
	sleep 1 while playing();

	my $id = getid($_);
	print "playing $id (" . getnam($_) . ")...\n";
	mpc("play $id");
}

mpc('single off');
