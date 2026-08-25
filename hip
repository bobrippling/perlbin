#!/usr/bin/env perl
use strict;
use warnings;
use Socket qw(getaddrinfo getnameinfo AF_UNSPEC SOCK_STREAM NI_NUMERICHOST NI_NUMERICSERV);

sub usage {
	print STDERR "Usage: $0 [--all|-a] hostname...\n";
	print STDERR "--all/-a: show all addresses\n";
	exit 2;
}

sub resolve {
	my($host, $all) = @_;

	my ($err, @res) = getaddrinfo(
		$host,
		undef,
		{ family => AF_UNSPEC, socktype => SOCK_STREAM }
	);

	die "$0: getaddrinfo: $err" if $err;

	for my $ai (@res) {
		my ($err2, $ip) = getnameinfo($ai->{addr}, NI_NUMERICHOST | NI_NUMERICSERV);
		if($err2){
			warn "$0: getnameinfo: $err2";
			next;
		}
		print "$ip\n";
		last unless $all;
	}
}

my $all = 0;
for(@ARGV){
	if($_ eq "--all" || $_ eq "-a"){
		$all = 1;
	}elsif(/^-/){
		usage();
	}else{
		resolve($_, $all);
	}
}
