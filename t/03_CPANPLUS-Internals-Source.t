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

use CPANPLUS::Backend;

use Test::More 'no_plan';
use Data::Dumper;

BEGIN { require 'conf.pl'; }

my $conf = gimme_conf();

my $cb = CPANPLUS::Backend->new( $conf );
isa_ok($cb, "CPANPLUS::Internals" );

my $mt = $cb->_module_tree;
my $at = $cb->_author_tree;

for my $name (qw[auth mod dslip] ) {
    my $file = File::Spec->catfile( 
                        $conf->get_conf('base'),
                        $conf->_get_source($name)
                );            
    ok( (-e $file && -f _ && -s _), "$file exists" );
}    

ok( scalar keys %$at, "Authortree loaded successfully" );
ok( scalar keys %$mt, "Moduletree loaded successfully" );

my $auth    = $at->{'AYRNIEU'};
my $mod     = $mt->{'Text::Bastardize'};

isa_ok( $auth, 'CPANPLUS::Module::Author' );
isa_ok( $mod,  'CPANPLUS::Module' );

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
