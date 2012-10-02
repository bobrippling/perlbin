#!/usr/bin/perl
use warnings;

sub usage
{
	die "Usage: $0 [link]\n"
}

my $link;

if(@ARGV == 0){
	print STDERR "$0: reading from stdin...\n";
	$link = <STDIN>;
	die "no in\n" unless $link;
}elsif(@ARGV == 1){
	$link = $ARGV[0];
}else{
	usage();
}

open WGET, '-|', "wget -UFirefox -o/dev/stdout -O/dev/null '$link'" or die;

my @lines;
my $found = 0;

wget_loop:
while(<WGET>){
	chomp;

	push @lines, $_;

	if(/^HTTP request sent, .*200 OK/){
		for(my $i = $#lines; $i >= 0; $i--){
			my $l = $lines[$i];

			if($l =~ /^--[^ ]+ [^ ]+ +(.*)/){
				my $resolved = $1;
				print "$resolved\n";
				$found = 1;
				last wget_loop;
			}
		}
	}
}

close WGET;

die "No download for $link\n" unless $found;
