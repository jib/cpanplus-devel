### running under perl core?
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

my $CB      = CPANPLUS::Backend->new( $conf );
my $Acc     = 'selfupdate_object';
my $Conf    = CPANPLUS::Selfupdate->_get_config;
my $Dep     = 'B::Deparse';   # has to be in our package file && core!

### test the object
{   ok( $CB,                        "New backend object created" );
    can_ok( $CB,                    $Acc );

    ok( $Conf,                      "Got configuration hash" );

    my $su = $CB->$Acc;
    ok( $su,                        "Selfupdate object retrieved" );
    isa_ok( $su,                    "CPANPLUS::Selfupdate" );
}

### test the feature list
{   ### start with defining our OWN type of config, as not all mentioned
    ### modules will be present in our bundled package files.
    ### XXX WHITEBOX TEST!!!!
    {   delete $Conf->{$_} for keys %$Conf;
        $Conf->{'dependencies'}                 = { $Dep => 0 };
        $Conf->{'core'}                         = { $Dep => 0 };
        $Conf->{'features'}->{'some_feature'}   = [ { $Dep => 0 }, sub { 1 } ];
    }

    is_deeply( $Conf, CPANPLUS::Selfupdate->_get_config,
                                    "Config updated succesfully" );

    my @feat = $CB->$Acc->list_features;
    ok( scalar(@feat),              "Features list returned" );

    ### test if we get modules for each feature
    for my $feat (@feat) {
        my @mods = $CB->$Acc->modules_for_feature( $feat );
        
        ok( $feat,                  "Testing feature '$feat'" );
        ok( scalar( @mods ),        "   Module list returned" );
    
        for my $mod (@mods) {
            isa_ok( $mod,           "CPANPLUS::Module" );
            isa_ok( $mod,           "CPANPLUS::Selfupdate::Module" );
            can_ok( $mod,           'is_uptodate_for_cpanplus' );
            ok( $mod->is_uptodate_for_cpanplus,
                                    "   Module uptodate" );
        }                                    
    }        
}    
