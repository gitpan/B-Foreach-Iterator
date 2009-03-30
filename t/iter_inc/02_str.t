#!perl -w

use strict;
use Test::More tests => 4;

use B::Foreach::Iterator;

my @next;
foreach ('a' .. 'e'){
	push @next, iter_inc;
}

is_deeply \@next, ['b', 'd', undef];

@next = ();
foreach my $i('a' .. 'f'){
	push @next, iter_inc;
}
is_deeply \@next, ['b', 'd', 'f'] or diag "[@next]";


@next = ();
foreach (reverse 'a' .. 'e'){
	push @next, iter_inc;
}

is_deeply \@next, ['d', 'b', undef];

@next = ();
foreach my $i(reverse 'a' .. 'f'){
	push @next, iter_inc;
}
is_deeply \@next, ['e', 'c', 'a'];
