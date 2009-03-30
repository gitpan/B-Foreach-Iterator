package B::Foreach::Iterator;

use 5.008_001;
use strict;

our $VERSION = '0.01';

use Exporter qw(import);
our @EXPORT = qw(iter_inc iter_next);

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);


1;
__END__

=head1 NAME

B::Foreach::Iterator - Increases foreach iterators

=head1 VERSION

This document describes B::Foreach::Iterator version 0.01.

=head1 SYNOPSIS

	use B::Foreach::Iterator;

	for my $key(foo => 10, bar => 20, baz => 30){
		printf "%s => %s\n", $key => iter_inc;
	}

=head1 DESCRIPTION

C<B::Foreach::Iterator> provides functions that manipulate C<foreach> iterators.

=head1 INTERFACE

=head2 Exported functions

=over 4

=item iter_inc()

Increases the iterator of current C<foreach> loops and returns its value.

=item iter_next()

Returns the value of the next iterator of current C<foreach> loops. Does not
increases the iterator.

=back

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<perlguts>.

F<pp_hot.c>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Goro Fuji. Some rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
