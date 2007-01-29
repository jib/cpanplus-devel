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
use Test::More      'no_plan';
use File::Basename  'dirname';

use Data::Dumper;
use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;

BEGIN { require 'conf.pl'; }
my $conf = gimme_conf();

### purposely avert messages and errors to a file? ###
my $Trap_Output = @ARGV ? 0 : 1;

my $Class = 'CPANPLUS::Backend';
### D::C has troubles with the 'use_ok' -- it finds the wrong paths.
### for now, do a 'use' instead
#use_ok( $Class ) or diag "$Class not found";
use CPANPLUS::Backend;

my $cb = $Class->new( $conf );
isa_ok( $cb, $Class );

my $mt = $cb->module_tree;
my $at = $cb->author_tree;
ok( scalar keys %$mt,       "Module tree has entries" ); 
ok( scalar keys %$at,       "Author tree has entries" ); 

### module_tree tests ###
my $Name = 'Foo::Bar::EU::NOXS';
my $mod  = $cb->module_tree($Name);

### XXX SOURCEFILES FIX
{   my @mods = $cb->module_tree($Name,$Name);
    my $none = $cb->module_tree('fnurk');
    
    ok( IS_MODOBJ->(mod => $mod),           "Module object found" );
    is( scalar(@mods), 2,                   "   Module list found" );
    ok( IS_MODOBJ->(mod => $mods[0]),       "   ISA module object" );
    ok( !IS_MODOBJ->(mod => $none),         "   Bogus module detected");
}

### author_tree tests ###
{   my @auths = $cb->author_tree( $mod->author->cpanid,
                                  $mod->author->cpanid );
    my $none  = $cb->author_tree( 'fnurk' );
    
    ok( IS_AUTHOBJ->(auth => $mod->author), "Author object found" );
    is( scalar(@auths), 2,                  "   Author list found" );
    ok( IS_AUTHOBJ->( author => $auths[0] ),"   ISA author object" );
    is( $mod->author, $auths[0],            "   Objects are identical" );
    ok( !IS_AUTHOBJ->( author => $none ),   "   Bogus author detected" );
}

my $conf_obj = $cb->configure_object;
ok( IS_CONFOBJ->(conf => $conf_obj),    "Configure object found" );


### parse_module tests ###
{   ### basic tests to find a single module
    for my $guess ( qw[ Foo::Bar::EU::NOXS
                        Foo-Bar-EU-NOXS
                        Foo-Bar-EU-NOXS-0.01
                        EUNOXS/Foo-Bar-EU-NOXS
                        EUNOXS/Foo-Bar-EU-NOXS-0.01
                    ],
                    $mod
    ) {

        ok( $guess,             "Attempting to parse $guess" );

        my $obj = $cb->parse_module( module => $guess );
        my ($auth) = $guess =~ m|(.+?)/| ? $1 : $obj->author->cpanid;

        ok( IS_MODOBJ->( mod => $obj ), 
                                "   parse_module success by '$guess'" );     
        like( $obj->author->cpanid, "/$auth/i", 
                                "   proper author found");
        like( $obj->path,           "/$auth/i", 
                                "   proper path found" );
    }

    ### find different authors, extensions and so on
    for my $guess ( qw[
                    Foo-Bar-EU-NOXS-0.09
                    MBXS/Foo-Bar-EU-NOXS-0.01
                    EUNOXS/Foo-Bar-EU-NOXS-0.09
                    EUNOXS/Foo-Bar-EU-NOXS-0.09.zip
                    FROO/Flub-Flob-1.1.zip
                    G/GO/GOYALI/SMS_API_3_01.tar.gz
    ] ) {
        my $obj = $cb->parse_module( module => $guess );
        my ($auth) = $guess =~ m|^(.+?)/| ? $1 : $obj->author->cpanid;
        
        ok( IS_FAKE_MODOBJ->(mod => $obj), "parse_module success by '$guess'" );     
        like( $obj->author->cpanid, "/$auth/i", "   proper author found" );
        like( $obj->path,           "/$auth/i", "   proper path found" );

    }

    ### more complicated ones 
    for my $guess ( qw[ E/EY/EYCK/Net/Lite/Net-Lite-FTP-0.091
                        EYCK/Net/Lite/Net-Lite-FTP-0.091
                        M/MA/MAXDB/DBD-MaxDB-7.5.00.24a
                    ] 
    ) {
        my $obj     = $cb->parse_module( module => $guess );
        my ($ver)   = $guess =~ m|-([^-]+)$|            ? $1 : '';
        my ($auth)  = $guess =~ m|(?:./../)?(.+?)/|     ? $1 : '';
        my ($path)  = $guess =~ m|^(.+)/|               ? $1 : '';

        ok( IS_FAKE_MODOBJ->(mod => $obj), "parse_module success by '$guess'" );

        ok( $auth,                  "   Author '$auth' parsed from '$guess'");
        ok( $path,                  "   Path '$path' parsed from '$guess'");
        ok( $ver,                   "   Version '$ver' parsed from '$guess'");

        like( $obj->author->cpanid, qr/^$auth$/i, 
                                    "   proper author found" );
        like( $obj->path,           qr/$path$/i, 
                                    "   proper path found" );
        is( $obj->version, $ver,    "   proper version found" );        
    }

    ### test for things that look like real modules, but aren't ###
    {   local $CPANPLUS::Error::MSG_FH    = output_handle() if $Trap_Output;
        local $CPANPLUS::Error::ERROR_FH  = output_handle() if $Trap_Output;
        
        my @map = (
            [ 'Foo::Bar'.$$ => [
                [qr/does not contain an author/,"Missing author part detected"],
                [qr/Cannot find .+? in the module tree/,"Unable to find module"]
            ] ],
            [ {}, => [
                [ qr/module string from reference/,"Unable to parse ref"] 
            ] ],
        );

        for my $entry ( @map ) {
            my($mod,$aref) = @$entry;
            
            my $none = $cb->parse_module( module => $mod );
            ok( !IS_MODOBJ->(mod => $none),     
                                "Non-existant module detected" );
            ok( !IS_FAKE_MODOBJ->(mod => $none),
                                "Non-existant fake module detected" );
        
            my $str = CPANPLUS::Error->stack_as_string;
            for my $pair (@$aref) {
                my($re,$diag) = @$pair;
                like( $str, $re,"   $diag" );
            }
        }    
    }
    
    ### test parsing of arbitrary URI
    for my $guess ( qw[ http://foo/bar.gz
                        http://a/b/c/d/e/f/g/h/i/j
                        flub://floo ]
    ) {
        my $obj = $cb->parse_module( module => $guess );
        ok( IS_FAKE_MODOBJ->(mod => $obj), "parse_module success by '$guess'" );
        is( $obj->status->_fetch_from, $guess,
                                            "   Fetch from set ok" );
    }                                       
}         

### RV tests ###
{   my $method = 'readme';
    my %args   = ( modules => [$Name] );  
    
    my $rv = $cb->$method( %args );
    ok( IS_RVOBJ->( $rv ),              "Got an RV object" );
    ok( $rv->ok,                        "   Overall OK" );
    cmp_ok( $rv, '==', 1,               "   Overload OK" );
    is( $rv->function, $method,         "   Function stored OK" );     
    is_deeply( $rv->args, \%args,       "   Arguments stored OK" );
    is( $rv->rv->{$Name}, $mod->readme, "   RV as expected" );
}

### reload_indices tests ###
{
    my $file = File::Spec->catfile( $conf->get_conf('base'),
                                    $conf->_get_source('mod'),
                                );
  
    ok( $cb->reload_indices( update_source => 0 ),  "Rebuilding trees" );                              
    my $age = -M $file;
    
    ok( $cb->reload_indices( update_source => 1 ),  
                                    "Rebuilding and refetching trees" );
    cmp_ok( $age, '>', -M $file,    "    Source file updated" );                                      
}

### flush tests ###
{
    for my $cache( qw[methods hosts modules lib all] ) {
        ok( $cb->flush($cache), "Cache $cache flushed ok" );
    }
}

### installed tests ###
{   $DB::single = 1;
    ok( scalar $cb->installed,    "Found list of installed modules" );
}    
                
### autobudle tests ###
{
    my $where = $cb->autobundle;
    ok( $where,     "Autobundle written" );
    ok( -s $where,  "   File has size" );
}

### local_mirror tests ###
{   ### turn off md5 checks for the 'fake' packages we have 
    my $old_md5 = $conf->get_conf('md5');
    $conf->set_conf( md5 => 0 );

    ### otherwise 'status->fetch' might be undef! ###
    my $rv = $cb->local_mirror( path => 'dummy-localmirror' );
    ok( $rv,                        "Local mirror created" );
    
    for my $mod ( values %{ $cb->module_tree } ) {
        my $name    = $mod->module;
        
        my $cksum   = File::Spec->catfile(
                        dirname($mod->status->fetch),
                        CHECKSUMS );
        ok( -e $mod->status->fetch, "   Module '$name' fetched" );
        ok( -s _,                   "       Module '$name' has size" );
        ok( -e $cksum,              "   Checksum fetched for '$name'" );
        ok( -s _,                   "       Checksum for '$name' has size" );
    }      

    $conf->set_conf( md5 => $old_md5 );
}    

### check ENV variable
{   my $name = 'PERL5_CPANPLUS_IS_RUNNING';
    ok( $ENV{$name},                "Env var '$name' set" );
    is( $ENV{$name}, $$,            "   Set to current process id" );
}

__END__    
                                          
# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:                    
                    
