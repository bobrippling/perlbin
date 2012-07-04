#!/usr/bin/perl
use warnings;

sub average
{
	my $t = 0;
	$t += $_ for @_;
	return $t / @_;
}

open PING, "ping @ARGV |" or die;

while(<PING>){
	chomp;

	next unless /time=([0-9.]+) /;

	push @times, $1;

	shift @times if @times > 10; # how many points we average over

	print $_, " avg=", sprintf('%.2f', average(@times)), "\n";
}

close PING;
