use strict;
use warnings FATAL => 'all';
use v5.10;

sub some{
    goto SOME;

    my $var;

    SOME:
    $var = 1;
    say $var;
}

some();
