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

my $CB  = CPANPLUS::Backend->new( $conf );
my $Acc = 'selfupdate_object';

### test the object
{   ok( $CB,                        "New backend object created" );
    can_ok( $CB,                    $Acc );

    my $su = $CB->$Acc;
    ok( $su,                        "Selfupdate object retrieved" );
    isa_ok( $su,                    "CPANPLUS::Selfupdate" );
}

### test the feature list
{   my @feat = $CB->$Acc->list_features;
    ok( scalar(@feat),              "Features list returned" );

    ### test if we get modules for each feature
    for my $feat (@feat) {
        my @mods = $CB->$Acc->modules_for_feature( $feat );
        
        ok( $feat,                  "Testing feature '$feat'" );
        ok( scalar( @mods ),        "   Module list returned" );
    }        
}    
