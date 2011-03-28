#!/usr/bin/perl
use warnings;
use strict;

use HTML::Entities;

my $pass = 'chippy';
my $output = "/tmp/belkin.html";
my $f = undef;
my $col = 0;
my $verbose = 0;
my $fetch = 1;
my $debug = 0;
my $dry = 0;

sub curl($%)
{
	my @post;
	my $get = shift;
	my $local_dry = $dry;

	return undef unless $fetch || !-f $output;

	if($get eq 'get'){
		$get = 1;
	}elsif($get eq 'post'){
		$get = 0;
	}elsif($get eq 'dry'){
		$local_dry = 1;
	}else{
		die "Invalid \$get\n";
	}

	for my $ref (@_){
		my %h = %$ref;
		for my $k (sort keys %h){
			push @post, "$k=$h{$k}";
		}
	}

	my $postargs;
	if(@post){
		$postargs = "-d '" . join('&', @post) . "'";
	}else{
		$postargs = '';
	}

	my $cmd = "curl -s http://192.168.2.1/setup.cgi $postargs" .
		" -b cookies.txt -c cookies.txt -o $output" .
		($get ? ' -G' : '');

	print STDERR "system(\"$cmd\")\n" if $debug;

	return 1 if $local_dry;
	my $ret = system($cmd);
	die "curl returned $ret\n" if $ret;
	return 1;
}

sub nextfile($)
{
	return curl('get', {
			next_file => $_[0]
		});
}

sub login()
{
	return curl('post', {
			pws       => $pass,
			todo      => 'login',
			this_file => 'login.html',
			next_file => '',
			message   => ''
		});
}

sub logout()
{
	return curl('post', {
			todo => 'logout'
		});
}

sub checklogin()
{
	return 1 if $dry;
	return undef unless nextfile 'lan_dhcp.html';

	open F, '<', $output or die "open $output: $!\n";
	my $need_login = grep /todo.*login/, <F>;
	close F;

	if($need_login){
		print "Logging in...\n" if $verbose;
		return login();
	}
	print "Already logged in\n" if $verbose;
	return 1;
}

sub dhcpls()
{
	return undef unless nextfile 'lan_dhcp.html';

	open F, '<', $output or die "open $output: $!\n";
	my @lines;
	my $line = (grep { /td +align=center/ } (@lines = <F>))[0];
	close F;

	# $line is a <tr>, with td = [ ip, name, mac ]

	die "couldn't parse dhcp table\n" unless $line;

	#<tr><td align=center>192.168.2.2</td><td align=center>unknown</td><td align=center>00:00:00:00:00:00</td></tr>
	my @rows = map { [
			map { s#</td>##; $_ }
			grep { length }
			split /<td[^>]*>/ ] }
		grep { /[^ \t\n]/ }
		split m#</?tr>#, $line;

	print "IP\tName\tMAC\n";

	my $i = 0;
	for(@rows){
		my @this = @$_;
		print "$_\t" for @$_;
		print $/;
	}
}

sub virtparse()
{
	return undef unless nextfile 'fw_virt.html';

	open F, '<', $output or die "open $output: $!\n";
	my @lines = <F>;
	my $data = (grep { /^var token / } @lines)[0];
	my $desc = (grep { /^var token_/ } @lines)[0];
	close F;

	die "virtparse(): data/desc not found\n" unless $data and $desc;

	$data =~ s/.*"([^"]+)".*/$1/;
	$desc =~ s/.*"([^"]+)".*/$1/;

	chomp $data;
	chomp $desc;

	my @data = split / /, $data;
	my @desc = split / /, $desc;

	my @ret;

	for my $i (0 .. $#data){
		my @fields = split /-/, $data[$i];
		$fields[4] = $fields[4] eq '2' ? 'UDP' : 'TCP';
		$fields[1] = '';

		unshift @fields, $desc[$i];

		push @ret, \@fields;
	}

	return @ret;
}


sub virtls()
{
	my @lines = virtparse();

	return undef unless @lines;

	print "Name Enabled Remote1 Remote2 Proto InternalIP Local1 Local2\n";
	for(@lines){
		#print "line: $_\n";
		my @fields = @$_;
		my $desc = shift @fields;
		print "$desc: ", join(' ', @fields), $/;
	}
}

sub virtupdate(\@)
{
	my %vars = (
		submit => 'Apply+Changes',
		virtual_server_list => 'Active+Worlds',
		clear_entry_list => '1',

		ValueOfRemote => '',
		todo => 'save',
		this_file => 'fw_virt.html',
		next_file => 'fw_virt.html',
		message => ''
	);
	my @lines = @{$_[0]};

	for my $i (0 .. 19){
		my $j = $i + 1;

		if(defined @{$lines[$i]} && length $lines[$i]->[0]){
			my $name = encode_entities($lines[$i]->[0]);

			$vars{fwi_des} .= "$name+";

			# enable, x, port1, port2, proto, ip, port3, port4
			$vars{fwi}     .= "$lines[$i]->[1]-x";
			for(3 .. 8){
				$vars{fwi}   .= "-$lines[$i]->[$_]";
			}
			$vars{fwi}     .= "+";

			$vars{"description_$j"}           = $name;
			$vars{"enable_$j"}                = $lines[$i]->[1];
			$vars{"inbound_port_low_$j"}      = $lines[$i]->[3];
			$vars{"inbound_port_high_$j"}     = $lines[$i]->[4];
			$vars{"type_$j"}                  = $lines[$i]->[5];
			$vars{"private_ip_$j"}            = $lines[$i]->[6];
			$vars{"private_port_low_$j"}      = $lines[$i]->[7];
			$vars{"private_port_high_$j"}     = $lines[$i]->[8];
		}else{
			#$vars{fwi}     .= '0-x-0-0-0-0-0-0+';
			#$vars{fwi_des} .= '+';

			$vars{"description_$j"}           = '';
			$vars{"enable_$j"}                = '';
			$vars{"inbound_port_low_$j"}      = '';
			$vars{"inbound_port_high_$j"}     = '';
			$vars{"type_$j"}                  = '';
			$vars{"private_ip_$j"}            = '';
			$vars{"private_port_low_$j"}      = '';
			$vars{"private_port_high_$j"}     = '';
		}
	}

	my $post = join '&', map { "$_=$vars{$_}" } sort keys %vars;

	return curl('post', \%vars);
}

sub virtmake(%)
{
	my @ret;

	if(defined $_[0]){
		my %map = @_;

		# desc enabled X inp inp2 proto ip outp2 outp2
		$ret[0] = $map{desc};
		$ret[1] = $map{enabled};
		$ret[2] = '';
		$ret[3] = $map{in_port1};
		$ret[4] = $map{in_port2};
		$ret[6] = $map{ip};
		$ret[7] = $map{out_port1};
		$ret[8] = $map{out_port2};

		goto nodef unless defined $map{proto};

		if($map{proto} eq 'TCP'){
			$ret[5] = 1;
		}elsif($map{proto} eq 'UDP'){
			$ret[5] = 2;
		}else{
		nodef:
			die "invalid protocol $map{proto}\n";
		}
	}else{
		$ret[0] = '';
	}

	return @ret;
}

sub default()
{
	my @maps;

	for my $i (0 .. 8){
		my %map;
		my $port = $i + 6734;

		$map{desc}      = "ssh $i $port";
		$map{enabled}   = 1;
		$map{in_port1}  = $port;
		$map{in_port2}  = $port;
		$map{ip}        = $i + 1;
		$map{out_port1} = 22;
		$map{out_port2} = 22;
		$map{proto}     = 'TCP';

		my @made = virtmake(%map);
		push @maps, \@made;
	}

	virtupdate @maps;
}

sub virtadd(@)
{
	my @update = virtparse();
	my $free = scalar @update;

	die "FIXME\n";
	for(@_){ # FIXME
		my @a = @$_;
		for my $i (8 .. 3){
			$a[$i] = $a[$i - 1];
		}
		$a[2] = '';
		@{$_} = @a;
	}

	push @update, [] while @update < 20;

	for(@_){
		die "Too many virtual server slots in use!\n" if $free > 19;

		#                 desc     enabled     inp     inp2     proto       ip      outp2  outp2
		#$update[$i] = [ "TEST_$i", $i % 2, '', $i + 1, $i + 1, $i % 2 + 1, $i % 4, $i + 2, $i + 2 ];
		$update[$free++] = [ @$_ ];
		print "adding " . join(', ', @$_) . "\n";
	}

	return virtupdate @update;
}

sub virtdel()
{
	# given list of ints
	my @update = virtparse();

	for(@_){
		if(defined @{$update[$_]}){
			print "removing $_: " . join(', ', @{$update[$_]}) . "\n";
			$update[$_] = [ virtmake undef ];
		}else{
			print "$_ already clear\n";
		}
	}

	return virtupdate @update;
}

sub null()
{
}

# -------------------------------------

sub usage()
{
	print STDERR <<"!";
Usage: $0 [-d] [-t] [-v] [CMD]
  -t: Pipe to `column -t`
  -v: Verbose
  -d: Debug
  -n: Dry

  login:     duh
  logout:    duh
  ls:        list dhcp clients
  virt:      list virtual servers
  virt_add:  add the args to the virt list
  virt_del:  clear the given indicies from the virt list

  virt_add takes a colon-seperated list:
    'desc enabled in_port1 in_port2 proto ip out_port1 out_port2'

  virt_del takes a list of indicies
!
	exit 1;
}

my $test = 0;
my $virtc = 0;
my @virtc;

for(@ARGV){
	if($_ eq 'DEF'){
		usage if $f;
		$f = \&default;
	}elsif($_ eq 'ls'){
		usage if $f;
		$f = \&dhcpls;
	}elsif($_ eq 'logout'){
		usage if $f;
		$f = \&logout;
	}elsif($_ eq 'login'){
		usage if $f;
		$verbose = 1;
		$f = \&null;
	}elsif($_ eq 'virt'){
		usage if $f;
		$f = \&virtls;
	}elsif($_ eq 'virt_add'){
		usage if $f;
		$f = \&virtadd;
		$virtc = 1;
	}elsif($_ eq 'virt_del'){
		usage if $f;
		$f = \&virtdel;
		$virtc = 1;
	}elsif($_ eq '-t'){
		$col = 1;
	}elsif($_ eq '-n'){
		$dry = 1;
	}elsif($_ eq '-v'){
		$verbose = 1;
	}elsif($_ eq '-d'){
		$debug = 1;
	}elsif($_ eq '-n'){
		$fetch = 0; # FIXME - arg
	}elsif($virtc){
		my @a = split /:/, $_;
		if($f == \&virtadd){
			die "need 8 items in $_\n" if @a != 8;
			push @virtc, [ @a ];
		}else{
			push @virtc, int;
		}
	}else{
		print STDERR "$_ ...?\n";
		usage();
	}
}

usage() unless $f;

open STDOUT, '|column -t' if $col;

die "Couldn't login\n" unless checklogin();
if($virtc){
	$f->(@virtc);
}else{
	$f->();
}
unlink $output if $fetch;

# TODO: error if someone else logged in
