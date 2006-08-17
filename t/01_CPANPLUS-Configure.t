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
    for (qw[../lib inc config]) { my $l = 'lib'; $l->import(File::Spec->rel2abs($_)) }
}

use Test::More 'no_plan';
use Data::Dumper;
use strict;
use CPANPLUS::Internals::Constants;
BEGIN { require 'conf.pl'; }

### purposely avert messages and errors to a file? ###
my $Trap_Output = @ARGV ? 0 : 1;
my $Config_pm   = 'CPANPLUS/Config.pm';


for my $mod (qw[CPANPLUS::Configure]) {
    use_ok($mod) or diag qq[Can't load $mod];
}    

my $c = CPANPLUS::Configure->new();
isa_ok($c, 'CPANPLUS::Configure');

my $r = $c->conf;
isa_ok( $r, 'CPANPLUS::Config' );


### EU::AI compatibility test ###
{   my $base = $c->_get_build('base');
    ok( defined($base),                 "Base retrieved by old compat API");
    is( $base, $c->get_conf('base'),    "   Value as expected" );
}

for my $cat ( $r->ls_accessors ) {

    ### what field can they take? ###
    my @options = $c->options( type => $cat );

    ### copy for use on the config object itself
    my $accessor    = $cat;
    my $prepend     = ($cat =~ s/^_//) ? '_' : '';
    
    my $getmeth     = $prepend . 'get_'. $cat;
    my $setmeth     = $prepend . 'set_'. $cat;
    my $addmeth     = $prepend . 'add_'. $cat;
    
    ok( scalar(@options),               "Possible options obtained" );
    
    ### test adding keys too ###
    {   my $add_key = 'test_key';
        my $add_val = [1..3];
    
        my $found = grep { $add_key eq $_ } @options;
        ok( !$found,                    "Key '$add_key' not yet defined" );
        ok( $c->$addmeth( $add_key => $add_val ),
                                        "   $addmeth('$add_key' => VAL)" ); 

        ### this one now also exists ###
        push @options, $add_key
    }

    ### poke in the object, get the actual hashref out ### 
    my %hash = map {
        $_ => $r->$accessor->$_     
    } $r->$accessor->ls_accessors;
    
    while( my ($key,$val) = each %hash ) {
        my $is = $c->$getmeth($key); 
        is_deeply( $val, $is,           "deep check for '$key'" );
        ok( $c->$setmeth($key => 1 ),   "   $setmeth('$key' => 1)" );
        is( $c->$getmeth($key), 1,      "   $getmeth('$key')" );
        ok( $c->$setmeth($key => $val), "   $setmeth('$key' => ORGVAL)" );
    }

    ### now check if we found all the keys with options or not ###
    delete $hash{$_} for @options;
    ok( !(scalar keys %hash),          "All possible keys found" );
    
}    


### see if we can save the config ###
{   no warnings 'redefine';
    my $dummydir = 'dummy-cpanplus';
    local *CPANPLUS::Internals::Utils::_home_dir = sub { $dummydir };

    my $file = CONFIG_USER_FILE->();
    
    ok( $c->can_save($file),    "Able to save config" );
    ok( $c->save( CONFIG_USER ),"   File saved" );
    ok( -e $file,               "   File exists" );
    ok( -s $file,               "   File has size" );

    ### now see if we can load this config too ###
    {   my $env = ENV_CPANPLUS_CONFIG;
        local $ENV{$env}        = $file;
        local $INC{$Config_pm}  = 0;
        
        my $conf; 
        {   local $^W; # redefining 'sub new'
            $conf = CPANPLUS::Configure->new();
        }       
        ok( $conf,              "Config loaded from environment" );
        isa_ok( $conf,          "CPANPLUS::Configure" );
        
        TODO: {
            local $TODO = 'FIXME after configure api is complete';
            is( $INC{$Config_pm}, $file,
                                "   Proper config file loaded" );
        }
    }
}


{   local $CPANPLUS::Error::ERROR_FH  = output_handle() if $Trap_Output;
    
    CPANPLUS::Error->flush;
    
    {   ### try a bogus method call 
        my $x   = $c->flubber('foo');
        my $err = CPANPLUS::Error->stack_as_string;
        is  ($x, undef,         "Bogus method call returns undef");
        like($err, "/flubber/", "   Bogus method call recognized");
    }
    
    CPANPLUS::Error->flush;
}    


# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
