#!/usr/bin/perl
use warnings;
use strict;

sub usage();

my $dry  = 0;
my $bg   = 0;
my $fast = 1;
my %playlist;

my @argv = @ARGV;

for(@argv){
	if($_ eq '-n'){
		$dry = 1;
	}elsif($_ eq '-f'){
		$bg = 1;
	}elsif($_ eq '-s'){
		$fast = 0;
	}elsif($_ eq '--help'){
		usage();
	}else{
		last;
	}
	shift @ARGV;
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
	print STDERR "Usage: $0 [OPT] song1 [song2 [song3...]]\n";
	print STDERR " Opt can be either -n or -f, dry/background\n";
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

sub getid($)
{
	my $reg = shift;

	for my $k (keys %playlist){
		return $k if $playlist{$k} =~ m/$reg/i;
	}
	die "Couldn't find $_[0] (key)\n";
}

usage() unless @ARGV;

get_playlist();

for(@ARGV){
	my $id = getid($_);
	print "queued \"$playlist{$id}\" ($id) for /$_/\n";
}

if(!$fast && -t STDOUT){
	$| = 1;
	print "interrupt to cancel,";
	for($_ = 3; $_ >= 0; $_--){
		print " $_";
		sleep 1;
	}
	print "\r\e[K";
}

exit 0 if $dry;

if($bg){
	my $pid = fork();
	die "fork(): $!\n" unless defined $pid;

	if($pid != 0){
		print "forked to background, pid $pid\n";
		exit 0;
	}
}

for(@ARGV){
	mpc('single on');
	sleep 1 while playing();

	my $id = getid($_);
	print "playing $id (" . getnam($_) . ")\n";
	mpc("play $id");
}

mpc('single off');
