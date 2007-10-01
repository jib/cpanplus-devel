### make sure we can find our conf.pl file
BEGIN { 
    use FindBin; 
    require "$FindBin::Bin/inc/conf.pl";
}

use strict;

use CPANPLUS::Backend;
use CPANPLUS::Internals::Constants;

use Test::More 'no_plan';
use Data::Dumper;
use File::Basename qw[dirname];

my $conf = gimme_conf();

my $cb = CPANPLUS::Backend->new( $conf );
isa_ok($cb, "CPANPLUS::Internals" );

my $mt      = $cb->_module_tree;
my $at      = $cb->_author_tree;
my $modname = TEST_CONF_MODULE;

for my $name (qw[auth mod dslip] ) {
    my $file = File::Spec->catfile( 
                        $conf->get_conf('base'),
                        $conf->_get_source($name)
                );            
    ok( (-e $file && -f _ && -s _), "$file exists" );
}    

ok( scalar keys %$at,           "Authortree loaded successfully" );
ok( scalar keys %$mt,           "Moduletree loaded successfully" );

### test lookups
{   my $auth    = $at->{'EUNOXS'};
    my $mod     = $mt->{$modname};

    isa_ok( $auth,              'CPANPLUS::Module::Author' );
    isa_ok( $mod,               'CPANPLUS::Module' );
}


### check custom sources
{   ### first, find a file to serve as a source
    my $mod     = $mt->{$modname};
    my $package = File::Spec->rel2abs(
                        File::Spec->catfile( 
                            $FindBin::Bin,
                            TEST_CONF_CPAN_DIR,
                            $mod->path,
                            $mod->package,
                        )
                    );      
       
    ok( $package,               "Found file for custom source" );
    ok( -e $package,            "   File '$package' exists" );
    
    ### next, set up the sources file
    my $src_dir = File::Spec->catdir( 
                        $conf->get_conf('base'),
                        $conf->_get_build('custom_sources'),
                    );          
    
    ok( $src_dir,               "Setting up source dir" );
    ok( $cb->_mkdir( dir => $src_dir ),
                                "   Dir '$src_dir' created" );
    
    ### the file we have to write the package names *into*
    my $src_file = File::Spec->catdir(
                        $src_dir,    
                        $cb->_uri_encode(
                            uri =>'file://'.File::Spec->catfile(
                                                dirname($package) 
                                            )
                        )
                    );            
    ok( $src_file,              "Sources will be written to '$src_file'" );                     
                     
    ### and write the file                     
    {   my $fh = OPEN_FILE->( $src_file, '>' );
        ok( $fh,                "   File opened" );
        print $fh $mod->package . $/;
        close $fh;
    }              

    ### now we can have it be loaded in
    {   my $meth = '__create_custom_module_entries';
        can_ok( $cb,    $meth );

        ### now add our own sources
        ok( $cb->$meth,         "Sources file loaded" );

        my $add_name = TEST_CONF_INST_MODULE;
        my $add      = $mt->{$add_name};
        ok( $add,               "   Found added module" );

        ok( $add->status->_fetch_from,  
                                "   Full download path set" );
        is( $add->author->cpanid, CUSTOM_AUTHOR_ID,
                                "   Attributed to custom author" );
    }
}


# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
