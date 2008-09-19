### make sure we can find our conf.pl file
BEGIN { 
    use FindBin; 
    require "$FindBin::Bin/inc/conf.pl";
}

use strict;
use Test::More 'no_plan';
use Module::Loaded;
use Object::Accessor;

use CPANPLUS::Dist;
use CPANPLUS::Backend;
use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;

my $Conf    = gimme_conf();
my $CB      = CPANPLUS::Backend->new( $Conf );
my $Inst    = INSTALLER_BUILD;

### set the config so that we will ignore the build installer,
### but prefer it anyway
{   Module::Loaded::mark_as_loaded( $Inst );
    CPANPLUS::Dist->_ignore_dist_types( $Inst );
    $Conf->set_conf( prefer_makefile => 0 );
}

my $Mod = $CB->module_tree( 'Foo::Bar::MB::NOXS' );

ok( $Mod,                       "Module object retrieved" );        
ok( not grep { $_ eq $Inst } CPANPLUS::Dist->dist_types,
                                "   $Inst installer not returned" );
            
### fetch the file first            
{   my $where = $Mod->fetch;
    ok( -e $where,              "   Tarball '$where' exists" );
}
    
### extract it, silence warnings/messages    
{   my $where = $Mod->extract;
    ok( -e $where,              "   Tarball extracted to '$where'" );
}

### check the installer type 
{   is( $Mod->status->installer_type, $Inst, 
                                "Proper installer type found: $Inst" );

    my $href = $Mod->status->configure_requires;
    ok( scalar(keys(%$href)),   "   Dependencies recorded" );
    
    ok( defined $href->{$Inst}, "       Dependency on $Inst" );

    my $err = CPANPLUS::Error->stack_as_string;
    like( $err, qr/$Inst/,      "   Message mentions $Inst" );
    like( $err, qr/prerequisites list/,
                                "   Message mentions adding prerequisites" );                            
}

### now run the test, it should trigger the installation of the installer
### XXX whitebox test
{   local *CPANPLUS::Backend::module_tree = sub { 
                           # mark C::D::Build as loaded
        CPANPLUS::Dist->_reset_dist_ignore; # make sure it's picked up next time
        CPANPLUS::Test::Module->new         # and provide an empty object to use
    };

    ok( $Mod->create( skiptest => 1),
                                'Ran $Mod->create()' );

    
    my $diag = CPANPLUS::Error->stack_as_string;
    like( $diag, qr/This module requires.*$Inst/,
                                "   Dependency on $Inst recorded" );
    like( $diag, qr/Bootstrapping installer.*$Inst/,
                                "       Bootstrap notice recorded" );
    like( $diag, qr/Installer '$Inst' succesfully bootstrapped/,
                                "       Successful bootstrap recorded" );
}

END { 1 while unlink output_file()  }

### place holder package to serve as a module object
{   package CPANPLUS::Test::Module;
    sub new     { return bless {} }
    sub install { return 1 }
}

### test package for cpanplus::dist::build
{   package CPANPLUS::Dist::Build;
    use base 'CPANPLUS::Dist::Base';
    
    sub format_available    { 1 }
    sub init                { 1 }
    sub prepare             { 1 }
    sub create              { 1 }
    sub install             { 1 }
}
