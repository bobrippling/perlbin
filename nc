#!/usr/bin/env perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;

sub usage {
	print STDERR "Usage: $0 [-v] [-w timeout] <ip> <port>\n";
	print STDERR "Usage: $0 [-v] -lp <port>\n";
	exit 1;
}

sub sysread_ck {
	my($fh, $d_ref, $n) = @_;
	my $bytes = sysread($fh, ${$d_ref}, $n);
	if($bytes == 0){
		exit;
	}elsif(!defined $bytes){
		die "read: $!";
	}
}

sub transfer {
	my($from, $to) = @_;
	my $data;
	sysread_ck($from, \$data, 4096);
	syswrite($to, $data);
}

@ARGV or usage();

my $verbose = 0;
if($ARGV[0] eq '-v'){
	$verbose = 1;
	shift;
}

my $socket;

if ($ARGV[0] eq '-lp') {
	@ARGV == 2 or usage();
	my $port = $ARGV[1];

	my $server = IO::Socket::INET->new(
		LocalAddr => '0.0.0.0',
		LocalPort => $port,
		Proto => 'tcp',
		Listen => 1,
		Reuse => 1
	) or die "listen: $!";

	$socket = $server->accept() or die "accept: $!";
	print STDERR "$0: accepted connection\n" if $verbose;
} else {
	my $timeout;
	if($ARGV[0] eq '-w'){
		shift @ARGV;
		$timeout = shift @ARGV or usage();
	}

	@ARGV == 2 or usage();
	my ($ip, $port) = @ARGV;

	$socket = IO::Socket::INET->new(
		PeerAddr => $ip,
		PeerPort => $port,
		Proto => 'tcp',
		($timeout ? (Timeout => $timeout) : ()),
	) or die "connect: $!";
	print STDERR "$0: connected\n" if $verbose;
}

$socket->autoflush(1);
STDOUT->autoflush(1);

my $sel = IO::Select->new();
$sel->add($socket);
$sel->add(\*STDIN);

while (1) {
	for my $fh ($sel->can_read) {
		if ($fh == $socket) {
			transfer($fh, \*STDOUT);
		} elsif ($fh == \*STDIN) {
			transfer($fh, $socket);
		}
	}
}
