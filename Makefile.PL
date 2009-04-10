use strict;
use warnings;
use inc::Module::Install;

name 'B-Foreach-Iterator';
all_from 'lib/B/Foreach/Iterator.pm';

requires 'Exporter' => 5.57;

build_requires 'ExtUtils::ParseXS';

test_requires 'Test::More'      => 0.62;
test_requires 'Test::LeakTrace' => 0.08;

tests 't/*.t t/*/*.t';
author_tests 'xt';

WriteMakefile(
	OBJECT => '$(O_FILES)',

	clean  => {FILES => q(
		B-Foreach-Iterator-* *.stackdump
		*.gcda *.gcno *.gcov
		nytprof *.out
		cover_db
	)},
);
