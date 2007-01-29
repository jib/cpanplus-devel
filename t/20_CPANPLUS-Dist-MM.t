BEGIN { 
    if( $ENV{PERL_CORE} ) {
        chdir '../lib/CPANPLUS' if -d '../lib/CPANPLUS';
        unshift @INC, '../../../lib';
    
        ### fix perl location too
        $^X = '../../../t/' . $^X;
    }
} 

#!/usr/bin/perl -w

BEGIN { chdir 't' if -d 't' };

### this is to make devel::cover happy ###
BEGIN {
    use File::Spec;
    require lib;
    for (qw[../lib inc]) { my $l = 'lib'; $l->import(File::Spec->rel2abs($_)) }
}

### leave this BEFORE any use of CPANPLUS::modules, especially ::inc!
BEGIN { require 'conf.pl'; }

use strict;

use CPANPLUS::Configure;
use CPANPLUS::Backend;
use CPANPLUS::Dist;
use CPANPLUS::Dist::MM;
use CPANPLUS::Internals::Constants;

use Test::More 'no_plan';
use Cwd;
use Config;
use Data::Dumper;
use File::Basename ();
use File::Spec ();

my $conf    = gimme_conf();
my $cb      = CPANPLUS::Backend->new( $conf );
my $noperms = ($< and not $conf->get_program('sudo')) &&
              ($conf->get_conf('makemakerflags') or
                not -w $Config{installsitelib} );
my $ModName = 'Foo::Bar';
my $File    = 'Bar.pm';


### don't start sending test reports now... ###
$cb->_callbacks->send_test_report( sub { 0 } );
$conf->set_conf( cpantest => 0 );


### Redirect errors to file ###
local $CPANPLUS::Error::ERROR_FH = output_handle() unless @ARGV;
local $CPANPLUS::Error::MSG_FH   = output_handle() unless @ARGV;
*STDERR                          = output_handle() unless @ARGV;

### dont uncomment this, it screws up where STDOUT goes and makes
### test::harness create test counter mismatches
#*STDOUT                          = output_handle() unless @ARGV;
### for the same test-output counter mismatch, we disable verbose
### mode
$conf->set_conf( verbose => 0 );
$conf->set_conf( allow_build_interactivity => 0 );

### start with fresh sources ###
ok( $cb->reload_indices( update_source => 0 ),
                                "Rebuilding trees" );

### set alternate install dir ###
### XXX rather pointless, since we can't uninstall them, due to a bug
### in EU::Installed (6871). And therefor we can't test uninstall() or any of
### the EU::Installed functions. So, let's just install into sitelib... =/
#my $prefix  = File::Spec->rel2abs( File::Spec->catdir(cwd(),'dummy-perl') );
#my $rv = $cb->configure_object->set_conf( makemakerflags => "PREFIX=$prefix" );
#ok( $rv,                        "Alternate install path set" );

### enable signature checks ###
ok( $conf->set_conf( signature => 1 ),
                                "Enabling signature checks" );

my $Mod = $cb->module_tree( $ModName );

### format_available tests ###
{   ok( CPANPLUS::Dist::MM->format_available,
                                "Format is available" );

    ### whitebox test!
    {   local $^W;
        local *CPANPLUS::Dist::MM::can_load = sub { 0 };
        ok(!CPANPLUS::Dist::MM->format_available,
                                "   Making format unavailable" );
    }

    ### test if the error got logged ok ###
    like( CPANPLUS::Error->stack_as_string,
          qr/You do not have .+?'CPANPLUS::Dist::MM' not available/s,
                                "   Format failure logged" );

    ### flush the stack ###
    CPANPLUS::Error->flush;
}

ok( $Mod->fetch,                "Fetching module" );
ok( $Mod->extract,              "Extracting module" );

ok( $Mod->test,                 "Testing module" );
ok( $Mod->status->dist_cpan->status->test,
                                "   Test success registered as status" );
ok( $Mod->status->dist_cpan->status->prepared,
                                "   Prepared status registered" );
ok( $Mod->status->dist_cpan->status->created,
                                "   Created status registered" );
is( $Mod->status->dist_cpan->status->distdir, $Mod->status->extract,
                                "   Distdir status registered properly" );

### test the convenience methods
ok( $Mod->prepare,              "Preparing module" );
ok( $Mod->create,               "Creating module" );

ok( $Mod->dist,                 "Building distribution" );
ok( $Mod->status->dist_cpan,    "   Dist registered as status" );
isa_ok( $Mod->status->dist_cpan,    "CPANPLUS::Dist::MM" );

### flush the lib cache
### otherwise, cpanplus thinks the module's already installed
### since the blib is already in @INC
$cb->_flush( list => [qw|lib|] );

### XXX new EU::I should be forthcoming pending this patch from Steffen
### Mueller on p5p: http://www.xray.mpe.mpg.de/mailing-lists/ \ 
###     perl5-porters/2007-01/msg00895.html
### This should become EU::I 1.42.. if so, we should upgrade this bit
### of code and remove the diag, since we can then install in our dummy dir..
diag("\nSorry, installing into your real perl dir, rather than our test area");
diag('since ExtUtils::Installed does not probe for .packlists in other dirs');
diag('than those in %Config. See bug #6871 on rt.cpan.org for details');

SKIP: {

    skip(q[No install tests under core perl], 10) if $ENV{PERL_CORE};

    skip(q[Probably no permissions to install, skipping], 10)
        if $noperms;

    
    diag(q[Note: 'sudo' might ask for your password to do the install test])
        if $conf->get_program('sudo');

    ok( $Mod->install( force =>1 ),
                                "Installing module" );
    ok( $Mod->status->installed,"   Module installed according to status" );


    SKIP: {   ### EU::Installed tests ###
        skip("makemakerflags set -- probably EU::Installed tests will fail", 8)
            if $conf->get_conf('makemakerflags');

        skip("Old perl on cygwin detected -- tests will fail due to know bugs", 8)
            if ON_OLD_CYGWIN;

        {   ### validate
            my @missing = $Mod->validate;

            is_deeply( \@missing, [],
                                    "No missing files" );
        }

        {   ### files
            my @files = $Mod->files;

            ### number of files may vary from OS to OS
            ok( scalar(@files),     "All files accounted for" );
            ok( grep( /$File/, @files),
                                    "   Found the module" );

            ### XXX does this work on all OSs?
            #ok( grep( /man/, @files ),
            #                        "   Found the manpage" );
        }

        {   ### packlist
            my ($obj) = $Mod->packlist;
            isa_ok( $obj,           "ExtUtils::Packlist" );
        }

        {   ### directory_tree
            my @dirs = $Mod->directory_tree;
            ok( scalar(@dirs),      "Directory tree obtained" );

            my $found;
            for my $dir (@dirs) {
                ok( -d $dir,        "   Directory exists" );

                my $file = File::Spec->catfile( $dir, $File );
                $found = $file if -e $file;
            }

            ok( -e $found,          "   Module found" );
        }

        SKIP: {
            skip("Probably no permissions to uninstall", 1)
                if $noperms;

            ok( $Mod->uninstall,    "Uninstalling module" );
        }
    }
}

### test exceptions in Dist::MM->create ###
{   ok( $Mod->status->mk_flush, "Old status info flushed" );
    my $dist = CPANPLUS::Dist->new( module => $Mod,
                                    format => INSTALLER_MM );

    ok( $dist,                  "New dist object made" );
    ok(!$dist->prepare,         "   Dist->prepare failed" );
    like( CPANPLUS::Error->stack_as_string, qr/No dir found to operate on/,
                                "       Failure logged" );

    ### manually set the extract dir,
    $Mod->status->extract($0);

    ok(!$dist->create,          "   Dist->create failed" );
    like( CPANPLUS::Error->stack_as_string, qr/not successfully prepared/s,
                                "       Failure logged" );

    ### pretend we've been prepared ###
    $dist->status->prepared(1);

    ok(!$dist->create,          "   Dist->create failed" );
    like( CPANPLUS::Error->stack_as_string, qr/Could not chdir/s,
                                "       Failure logged" );
}

### writemakefile.pl tests ###
{   ### remove old status info
    ok( $Mod->status->mk_flush, "Old status info flushed" );
    ok( $Mod->fetch,            "Module fetched again" );
    ok( $Mod->extract,          "Module extracted again" );

    ### cheat and add fake prereqs ###
    $Mod->status->prereqs( { strict => '0.001', Carp => '0.002' } );

    my $makefile_pl = MAKEFILE_PL->( $Mod->status->extract );
    my $makefile    = MAKEFILE->(    $Mod->status->extract );

    my $dist        = $Mod->dist;
    ok( $dist,                  "Dist object built" );

    ### check for a makefile.pl and 'write' one
    ok( -s $makefile_pl,        "   Makefile.PL present" );
    ok( $dist->write_makefile_pl( force => 0 ),
                                "   Makefile.PL written" );
    like( CPANPLUS::Error->stack_as_string, qr/Already created/,
                                "   Prior existance noted" );

    ### ok, unlink the makefile.pl, now really write one
    unlink $makefile;

    ok( unlink($makefile_pl),   "Deleting Makefile.PL");
    ok( !-s $makefile_pl,       "   Makefile.PL deleted" );
    ok( !-s $makefile,          "   Makefile deleted" );
    ok($dist->write_makefile_pl,"   Makefile.PL written" );

    ### see if we wrote anything sensible
    my $fh = OPEN_FILE->( $makefile_pl );
    ok( $fh,                    "Makefile.PL open for read" );

    my $str = do { local $/; <$fh> };
    like( $str, qr/### Auto-generated .+ by CPANPLUS ###/,
                                "   Autogeneration noted" );
    like( $str, '/'. $Mod->module .'/',
                                "   Contains module name" );
    like( $str, '/'. quotemeta($Mod->version) . '/',
                                "   Contains version" );
    like( $str, '/'. $Mod->author->author .'/',
                                "   Contains author" );
    like( $str, '/PREREQ_PM/',  "   Contains prereqs" );
    like( $str, qr/Carp.+0.002/,"   Contains prereqs" );
    like( $str, qr/strict.+001/,"   Contains prereqs" );

    close $fh;

    ### seems ok, now delete it again and go via install()
    ### to see if it picks up on the missing makefile.pl and
    ### does the right thing
    ok( unlink($makefile_pl),   "Deleting Makefile.PL");
    ok( !-s $makefile_pl,       "   Makefile.PL deleted" );
    ok( $dist->status->mk_flush,"Dist status flushed" );
    ok( $dist->prepare,         "   Dist->prepare run again" );
    ok( $dist->create,          "   Dist->create run again" );
    ok( -s $makefile_pl,        "   Makefile.PL present" );
    like( CPANPLUS::Error->stack_as_string,
          qr/attempting to generate one/,
                                "   Makefile.PL generation attempt logged" );

    ### now let's throw away the makefile.pl, flush the status and not
    ### write a makefile.pl
    {   local $^W;
        local *CPANPLUS::Dist::MM::write_makefile_pl = sub { 1 };

        unlink $makefile_pl;
        unlink $makefile;

        ok(!-s $makefile_pl,        "Makefile.PL deleted" );
        ok(!-s $makefile,           "Makefile deleted" );
        ok( $dist->status->mk_flush,"Dist status flushed" );
        ok(!$dist->prepare,         "   Dist->prepare failed" );
        like( CPANPLUS::Error->stack_as_string,
              qr/Could not find 'Makefile.PL'/i,
                                    "   Missing Makefile.PL noted" );
        is( $dist->status->makefile, 0,
                                    "   Did not manage to create Makefile" );
    }

    ### now let's write a makefile.pl that just does 'die'
    {   local $^W;
        local *CPANPLUS::Dist::MM::write_makefile_pl = sub {
                my $dist = shift; my $self = $dist->parent;
                my $fh = OPEN_FILE->(
                            MAKEFILE_PL->($self->status->extract), '>' );
                print $fh "exit 1;";
                close $fh;
            };

        ### there's no makefile.pl now, since the previous test failed
        ### to create one
        #ok( -e $makefile_pl,        "Makefile.PL exists" );
        #ok( unlink($makefile_pl),   "   Deleting Makefile.PL");
        ok(!-s $makefile_pl,        "Makefile.PL deleted" );
        ok( $dist->status->mk_flush,"Dist status flushed" );
        ok(!$dist->prepare,         "   Dist->prepare failed" );
        like( CPANPLUS::Error->stack_as_string, qr/Could not run/s,
                                    "   Logged failed 'perl Makefile.PL'" );
        is( $dist->status->makefile, 0,
                                    "   Did not manage to create Makefile" );
    }

    ### clean up afterwards ###
    ok( unlink($makefile_pl),   "Deleting Makefile.PL");
    $dist->status->mk_flush;

}


# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:


