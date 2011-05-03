#!/usr/bin/perl
use warnings;
use strict;

sub usage();

my $dry   = 0;
my $bg    = 0;
my $query = 0;
my($stop_after, $stop_before) = 0;
my %playlist;

my @argv = @ARGV;

for(@argv){
	if($_ eq '-n'){
		$dry = 1;
	}elsif($_ eq '-f'){
		$bg = 1;
	}elsif($_ eq '-q'){
		$query = 1;
	}elsif($_ eq '-s'){
		$stop_before = 1;
	}elsif($_ eq '-S'){
		$stop_after = 1;
	}elsif($_ eq '--help'){
		usage();
	}else{
		shift @ARGV if $_ eq '--';
		last;
	}
	shift @ARGV;
}

sub get_playlist()
{
	for(map { chomp; $_ } `mpc playlist | nl`){
		die "couldn't parse \"$_\"\n" unless /^\s+([0-9]+)\s+(.*)$/;
		$playlist{$1} = $2;
	}
}

sub usage()
{
	my $out = <<"!";
Usage: $0 [OPT] song1 [song2 [song3...]]
  -n: Dry run
  -f: Fork to background
  -q: Query before running
  -s: Stop playing before queuing
  -S: Stop playing after queue
!
	print STDERR $out;
	exit 1;
}

sub playing()
{
	return system('mpc status|grep playing > /dev/null') == 0;
}

sub mpc
{
	my $cmd = 'mpc --wait ' . join(' ', @_) . ' > /dev/null';
	my $ret = system $cmd;
	die "$ret = $cmd\n" if $ret;
}

sub pwtest()
{
	my $ret = system "mpc consume off > /dev/null 2>&1";
	return !!$ret;
}

sub getid($)
{
	my $reg = shift;

	for my $k (keys %playlist){
		return $k if $playlist{$k} =~ m/$reg/i;
	}
	die "Couldn't find /$reg/ (key)\n";
}

sub sigh()
{
	print "caught SIG$_[0]\n";
	# FIXME: restore 'single' and what not?
	exit 1;
}

sub basename($)
{
	return $1 if $_[0] =~ m#.*/([^/]+)$#;
	return $_[0];
}

die "$0: need password\n" if pwtest();

if(@ARGV == 0){
	my $bnam = basename($0);

	print STDERR "$bnam: reading from stdin...\n";
	@ARGV = map { chomp; $_ } <STDIN>;

	print STDERR "$bnam: assuming yes (-q)\n" if $query;
	$query = 0;
}

get_playlist();

for(@ARGV){
	my $id = getid($_);
	print "queued \"$playlist{$id}\" ($id) for /$_/\n";
}

if($query){
	$| = 1;
	print "go? (Y/n) ";
	my $in = <STDIN>;
	exit 1 unless defined $in;
	chomp $in;
	exit 1 unless !length($in) || $in =~ /^y$/i;
}

if($dry){
	print "no action taken - dry run\n";
	exit 0;
}

if($bg){
	my $pid = fork();
	die "fork(): $!\n" unless defined $pid;

	if($pid != 0){
		print "forked to background, pid $pid\n";
		exit 0;
	}

	# child only
	close STDOUT;
	close STDERR;
	close STDIN;
	chdir '/';
}

mpc('stop') if $stop_before;

for(@ARGV){
	mpc('single on');
	mpc('repeat off');
	sleep 1 while playing();

	my $id = getid($_);
	print "playing $id ($playlist{$id})\n" unless $bg;
	mpc("play $id");
}

if($stop_after){
	sleep 1 while playing();
	mpc('stop');
}
# has to be after `stop`
mpc('single off');
mpc('repeat on');
