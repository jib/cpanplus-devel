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

use CPANPLUS::Configure;
use CPANPLUS::Backend;
use CPANPLUS::Internals::Constants;
use Test::More 'no_plan';
use Data::Dumper;

BEGIN { require 'conf.pl'; }

my $conf = gimme_conf();

my $cb = CPANPLUS::Backend->new( $conf );

### XXX SOURCEFILES FIX
my $mod     = $cb->module_tree('Foo::Bar::EU::NOXS');

isa_ok( $mod,  'CPANPLUS::Module' );

my $where = $mod->fetch;
ok( $where,             "Module fetched" );

my $dir = $cb->_extract( module => $mod );
ok( $dir,               "Module extracted" );
ok( DIR_EXISTS->($dir), "   Dir exists" );

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
