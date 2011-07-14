#!/usr/bin/perl
use warnings;

sub isipv4($)
{
	return 8 == length shift;
}

sub bintoaddr($)
{
	my $_ = shift;
	my @ret;
	my $fmt = isipv4($_) ? '%d' : '%02d';

	unshift @ret, sprintf $fmt, hex($1 . $2) while s/^(.)(.)//;

	if(isipv4($_)){
		return join '.', @ret;
	}else{
		my $r = join ':', @ret;
		$r =~ s/(00:)+(00)?/::/; # FIXME
		return $r;
	}
}

sub toaddr($)
{
	my $_ = shift;
	/(.*):(.*)/;
	return { addr => $1, port => $2, str => sprintf "%s:%d", bintoaddr $1, hex $2 };
}

sub st($)
{
	my %m = (
		 1 => 'time_wait',
		 2 => 'connecting',
		 6 => 'connected',
		10 => 'listening',
	);
	my $i = hex shift;
	my $v = $m{$i};

	return $v ? $v : sprintf "UNKNOWN_%d", $i;
}

my @socks;

if($ARGV[0] && $ARGV[0] eq '-t'){
	shift;
	open STDOUT, "|column -t" or die;
	$| = 1;
}

unless(@ARGV){
	push @ARGV, "/proc/net/tcp";
	push @ARGV, "/proc/net/tcp6";
}

while(<>){
	push @socks, {
			n => $1,
			laddr => toaddr($2),
			raddr => toaddr($3),
			state => st($4),
			uid => getpwuid($5) || $5,
		} if /^\s*([0-9]+): ([^ ]+) ([^ ]+) (..) [^ ]+ [^ ]+ [^ ]+ +([0-9]+)/;
}

for(@socks){
	my %h = %$_;
	print "$h{laddr}->{str} $h{raddr}->{str} state=$h{state} uid=$h{uid}\n";
}
