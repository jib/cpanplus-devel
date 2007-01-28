BEGIN { 
    if( $ENV{PERL_CORE} ) {
        chdir '../lib/CPANPLUS' if -d '../lib/CPANPLUS';
        unshift @INC, '../../../lib';
    
        ### fix perl location too
        $^X = '../../../t/' . $^X;
    }
} 

BEGIN { chdir 't' if -d 't' };

### this is to make devel::cover happy ###
BEGIN {
    use File::Spec;
    require lib;
    for (qw[../lib inc]) { my $l = 'lib'; $l->import(File::Spec->rel2abs($_)) }
}


use strict;
use Test::More 'no_plan';
use Data::Dumper;
use CPANPLUS::Backend;
use CPANPLUS::Internals::Constants;

### XXX SOURCEFILES FIX
BEGIN { require 'conf.pl'; }
my $conf    = gimme_conf();
my $cb      = CPANPLUS::Backend->new($conf);
my $mod     = $cb->module_tree('Text::Bastardize');


### search for modules ###
for my $type ( CPANPLUS::Module->accessors() ) {

    ### don't muck around with references/objects
    ### or private identifiers
    next if ref $mod->$type() or $type =~/^_/;

    my @aref = $cb->search(
                    type    => $type,
                    allow   => [$mod->$type()],
                );

    ok( scalar @aref,       "Module found by '$type'" );
    for( @aref ) {
        ok( IS_MODOBJ->($_),"   Module isa module object" );
    }
}

### search for authors ###
my $auth = $mod->author;
for my $type ( CPANPLUS::Module::Author->accessors() ) {
    my @aref = $cb->search(
                    type    => $type,
                    allow   => [$auth->$type()],
                );

    ok( @aref,                  "Author found by '$type'" );
    for( @aref ) {
        ok( IS_AUTHOBJ->($_),   "   Author isa author object" );
    }
}


{   my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= "@_"; };

    {   ### try search that will yield nothing ###
        ### XXX SOURCEFILES FIX
        my @list = $cb->search( type    => 'module',
                                allow   => ['Foo::Bar'.$$] );

        is( scalar(@list), 0,   "Valid search yields no results" );
        is( $warning, '',       "   No warnings issued" );
    }

    {   ### try bogus arguments ###
        my @list = $cb->search( type => '', allow => ['foo'] );

        is( scalar(@list), 0,   "Broken search yields no results" );
        like( $warning, qr/^Key 'type'.* is of invalid type for/,
                                "   Got a warning for wrong arguments" );
    }
}

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
