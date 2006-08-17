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
use CPANPLUS::Module::Fake;
use CPANPLUS::Module::Author::Fake;
use CPANPLUS::Internals::Constants;

use Test::More 'no_plan';
use Data::Dumper;
use File::Path ();

BEGIN { require 'conf.pl'; }

### silence errors, unless you tell us not to ###
local $CPANPLUS::Error::ERROR_FH = output_handle() unless @ARGV;

my $conf    = gimme_conf();
my $cb      = CPANPLUS::Backend->new( $conf );

### start with fresh sources ###
ok( $cb->reload_indices( update_source => 0 ),  "Rebuilding trees" );  

my $auth    = $cb->author_tree('AYRNIEU');
my $mod     = $cb->module_tree('Text::Bastardize');

isa_ok( $auth, 'CPANPLUS::Module::Author' );
isa_ok( $mod,  'CPANPLUS::Module' );

### author accessors ###
is( $auth->email,     'julian@imaji.net',             "Author email");
is( $auth->author,    'julian fondren',               "Author name");
is( $auth->cpanid,    'AYRNIEU',                      "Author CPANID");
isa_ok( $auth->parent,'CPANPLUS::Internals',          "Author parent");

### module accessors ###
is( $mod->module,     'Text::Bastardize',             "Module name");
is( $mod->name,       'Text::Bastardize',             "Module name");
is( $mod->comment,    undef,                          "Module comment");
is( $mod->package,    'Text-Bastardize-0.06.tar.gz',  "Module package");
is( $mod->path,       'authors/id/A/AY/AYRNIEU',      "Module path");
is( $mod->version,    '0.06',                         "Module version");
is( $mod->dslip,      'cdpO ',                        "Module dslip");
is( $mod->description,'corrupts text in various ways',"Module description");

### convenience methods ###
is($mod->package_name,      'Text-Bastardize',        "Package name");
is($mod->package_version,   '0.06',                   "Package version");
is($mod->package_extension, 'tar.gz',                 "Package extension");
ok(!$mod->package_is_perl_core,                       "Package not core");
ok(!$mod->module_is_supplied_with_perl_core,          "Module not core" );
ok(!$mod->is_bundle,                                  "Package not bundle");

### check objects ###
isa_ok( $mod->parent, 'CPANPLUS::Internals',          "Module parent" );
isa_ok( $mod->author, 'CPANPLUS::Module::Author',     "Module author" );
is( $mod->author->author(), $auth->author,            "Module eq Author" );

### XXX whitebox test 
{   ok( !$mod->_status,     "Status object empty on start" );
    
    my $status = $mod->status;
    ok( $status,            "   Status object defined after query" );
    is( $status, $mod->_status,
                            "   Object stored as expected" );
    isa_ok( $status,        'Object::Accessor' );
}

    

{   ### extract + error test ###
    ok( !$mod->extract(),   "Cannot extract unfetched file" );
    like( CPANPLUS::Error->stack_as_string, qr/You have not fetched/,
                            "   Error properly logged" );
}      

{   ### fetch tests ###
    ### enable signature checks for checksums ###
    my $old = $conf->get_conf('signature');
    $conf->set_conf(signature => 1);  
    
    my $where = $mod->fetch( force => 1 );
    ok( $where,             "Module fetched" );
    ok( -f $where,          "   Module is a file" );
    ok( -s $where,          "   Module has size" );
    
    $conf->set_conf( signature => $old );
}

{   ### extract tests ###
    my $dir = $mod->extract( force => 1 );
    ok( $dir,               "Module extracted" );
    ok( -d $dir,            "   Dir exsits" );
}


{   ### readme tests ###
    my $readme = $mod->readme;
    ok( length $readme,     "Readme found" );
    is( $readme, $mod->status->readme,
                            "   Readme stored in module object" );
}

{   ### checksums tests ###
    SKIP: {
        skip(q[You chose not to enable checksum verification], 5)
            unless $conf->get_conf('md5');
    
        my $cksum_file = $mod->checksums( force => 1 );
        ok( $cksum_file,    "Checksum file found" );
        is( $cksum_file, $mod->status->checksums,
                            "   File stored in module object" );
        ok( -e $cksum_file, "   File exists" );
        ok( -s $cksum_file, "   File has size" );
    
        ### XXX test checksum_value if there's digest::md5 + config wants it
        ok( $mod->status->checksum_ok,
                            "   Checksum is ok" );
    }
}


{   ### installer type tests ###
    my $installer  = $mod->get_installer_type;
    ok( $installer,         "Installer found" );
    is( $installer, INSTALLER_MM,
                            "   Proper installer found" );
}

{   ### check signature tests ###
    SKIP: {
        skip(q[You chose not to enable signature checks], 1)
            unless $conf->get_conf('signature');
            
        ok( $mod->check_signature,
                            "Signature check OK" );
    }
}
    
    ### don't throw things away, it would confuse the stored status ###
    #unlink $where if $where;
    #File::Path::rmtree( $dir ) if $dir;

{   ### details() test ###   
    my $href = {
        'Support Level'     => 'Developer',
        'Package'           => 'Text-Bastardize-0.06.tar.gz',
        'Description'       => 'corrupts text in various ways',
        'Development Stage' => 
                'under construction but pre-alpha (not yet released)',
        'Author'            => 'julian fondren (julian@imaji.net)',
        'Version on CPAN'   => '0.06',
        'Language Used'     => 
                'Perl-only, no compiler needed, should be platform independent',
        'Interface Style'   => 
                'Object oriented using blessed references and/or inheritance',
        'Public License'    => 'Unknown',                
        ### XXX we can't really know what you have installed ###
        #'Version Installed' => '0.06',
    };   

    my $res = $mod->details;
    
    ### delete they key of which we don't know the value ###
    delete $res->{'Version Installed'};
    
    is_deeply( $res, $href, "Details OK" );        
}

{   ### contians() test ###
    my @list = $mod->contains;
    ok( scalar @list,           "Found modules contained in this one" );
    is_deeply( \@list, [$mod],  "   Found all modules expected" );
}

{   ### testing distributions() ###
    my @mdists = $mod->distributions;
    is( scalar @mdists, 1, "Distributions found via module" );

    my @adists = $auth->distributions;
    is( scalar @adists, 2,  "Distributions found via author" );
}

{   ### test status->flush ###
    ok( $mod->status->mk_flush,
                            "Status flushed" );
    ok(!$mod->status->fetch,"   Fetch status empty" );
    ok(!$mod->status->extract,
                            "   Extract status empty" );
    ok(!$mod->status->checksums,
                            "   Checksums status empty" );
    ok(!$mod->status->readme,
                            "   Readme status empty" );
}

{   ### testing bundles ###
    my $bundle = $cb->module_tree('Bundle::MP3');
    isa_ok( $bundle,  'CPANPLUS::Module' );

    ok( $bundle->is_bundle, "It's a Bundle:: module" );
    ok( $bundle->fetch,     "   Fetched the bundle" );
    ok( $bundle->extract,   "   Extracted the bundle" );

    my @objs = $bundle->bundle_modules;
    is( scalar @objs, 4,    "   Found all prerequisites" );
    
    for( @objs ) {
        isa_ok( $_, 'CPANPLUS::Module', 
                            "   Prereq" );
        ok( defined $bundle->status->prereqs->{$_->module},
                            "   Prereq was registered" );
    }
}

### test module from perl core ###
{   my $core = $cb->module_tree('B::Deparse');
    isa_ok( $core,                  'CPANPLUS::Module' );
    ok($core->package_is_perl_core, "Package found in perl core" );
    
    {   local $] = '5.006001';
        ok($core->module_is_supplied_with_perl_core,
                                    "   Module also found in perl core");
    }
    
    ok(! $core->install,            "   Package not installed" );
    like( CPANPLUS::Error->stack_as_string, qr/core Perl/,
                                    "   Error properly logged" );
}    
 
### testing that the uptodate/installed tests don't find things in the
### cpanplus::inc tree
### XXX CPANPLUS::inc code is now obsolete, so it has been removed.
# {   my $href    = CPANPLUS::inc->interesting_modules;
#     my $incpath = quotemeta CPANPLUS::inc->inc_path;
# 
#     for my $name ( keys %$href ) {
# 
#         ### clone a module, change the name
#         ### as that's all the installed functions look at
#         my $clone = $mod->clone;
#         $clone->module( $name );
#         
#         my $file = $clone->installed_file;
#         unlike( $file, qr/$incpath/,"   File not found in CP::inc ($file)" );
#     }
# }

### testing odd version numbers 
{   my $clone = $mod->clone;
    $clone->package( 'Foo-1.2_1.tar.gz' );
    is( $clone->package_version, '1.2_1',   
                                    "Odd Package version detected ok" );
}


### testing EU::Installed methods in Dist::MM tests ###

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
