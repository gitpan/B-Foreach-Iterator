#!perl -w

use strict;
use Test::More tests => 3;

use B::Foreach::Iterator;

eval{
	iter_inc;
};

like $@, qr/No foreach loops found/;

eval{
	while(1){

		iter_inc;

		last;
	}
};

like $@, qr/No foreach loops found/;

eval{
	for(;;){

		iter_inc;

		last;
	}
};

like $@, qr/No foreach loops found/;
