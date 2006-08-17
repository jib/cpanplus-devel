#!/usr/bin/perl

### we /need/ perl5.6.1 or higher -- we use coderefs in @INC,
### and 5.6.0 is just too buggy
use 5.006001;

use strict;
use warnings;

BEGIN {   
    ### chdir to the makefile.pl dir
    use FindBin;
    chdir $FindBin::Bin;

    use File::Spec;

    ### add the directory to our bundled modules
    use vars qw[@ORIG_INC];
    @ORIG_INC = @INC;       # store for later use

    require lib;
    my $l = 'lib'; 
    $l->import( qw[lib], File::Spec->catdir(qw[inc bundle]) );
}


### there's issues with redhat 9.0's stock perl -- they applied some
### custom patches on their 5.8.0 and it breaks use constant a => sub {};
if( $^O eq 'linux' and -e '/etc/redhat-release' and 
    $] == '5.008' and (grep /Red Hat, Inc/, values %Config::Config)
) {
    print qq(
### IMPORTANT! ######################################################

You are using perl $] supplied by RedHat, who have applied custom
patches that break various perl modules, including this one.

You will have to migrate to a perl without these flaws. You could
do this for example by building a perl installation by hand. 
You can obtain the sources from www.cpan.org.

We're sorry for the inconvenience.

#####################################################################

    ) . $/;

    require 5.008001;
}

### dont use, we dont want the coderef in @INC
### XXX other modules use it, so the coderef will still be there ;(
require CPANPLUS::inc;              # XXX get rid of me!
### it spews warnings though, so grep those out
### also grep out the warnings we get from using Module::Loaded
BEGIN { 
    $SIG{__WARN__} = sub {
        print STDERR "@_" if 
            "@_" !~ /^CPANPLUS::inc/        and
            "@_" !~ /Constant subroutine/;
    };
}

use inc::Module::Install;
use Getopt::Long;
use CPANPLUS::Backend;
use CPANPLUS::Configure;
use CPANPLUS::Configure::Setup;
use CPANPLUS::Internals::Constants;
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';


use constant BASIC_TESTS =>     qq[t/00_CPANPLUS-Internals-Utils.t];


my $Tests;
my $Prereq = {};    
my $RunSetup;
GetOptions( 'setup' => \$RunSetup );

my $Backend = CPANPLUS::Backend->new;
my $Config  = CPANPLUS::Configure->new;

### no setup? this is easy.. print the message and move a long
unless( $RunSetup ) {
    print qq[
### IMPORTANT! ######################################################
    
    
As of CPANPLUS 0.070, configuration during 'perl Makefile.PL'
is no longer required. A default config is now shipped that
should work out of the box on most machines, for priviliged
and unprivileged users.

If you wish to configure CPANPLUS to your environment, you can 
either do that from the interactive shell after installation:

    \$ cpanp
    CPAN Terminal> s conf user      # per user config
    CPAN Terminal> s conf system    # system wide config
    
Or you can invoke this program as follows, to do it now:

    \$ $^X Makefile.PL --setup      

This also means that any config created by any CPANPLUS older
than 0.070 will no longer work, and you are required to 
reconfigure. See the ChangeLog file for details.

We appologize for the inconvenience.
    ] . $/;

### ok, we're asked to run the setup stuff, let's do it
} else {

    my $setup = CPANPLUS::Configure::Setup->new(
                    backend             => $Backend,
                    configure_object    => $Config,
                );

    $setup->init;
}    
    
### mention our prereqs
{   print loc("
### PLEASE NOTE ###################################################

Since CPANPLUS 0.050 has a few prerequisites that are not core
perl (yet), they are bundled with the distribution for boot-
strapping purposes.

You should install these prerequisites before continueing to
install CPANPLUS. You can use the bootstrapped CPANPLUS to do
this for you with the following command:

    %1

Or let your package manager take care of it.

###################################################################
    
    ", "$^X bin/cpanp-boxed -i Bundle::CPANPLUS::Dependencies" );  
    print "\n";
}


### toss out the old source files, they might be compiled
### in an incompatilbe format (rt #18121)
{   my $stored = $Backend->__storable_file( $Config->get_conf('base') );      
    1 while unlink $stored;
}

### write the makefile.pl
{   
    $Prereq = {
        'File::Fetch'               => '0.08', # win32 ftp support
        'File::Spec'                => '0.82',
        'IPC::Cmd'                  => '0.24',
        'Locale::Maketext::Simple'  => '0.01',
        'Log::Message'              => '0.01',
        'Module::Load'              => '0.10',
        'Module::Load::Conditional' => '0.10', # %INC lookup support
        'Params::Check'             => '0.22',
        'Package::Constants'        => '0.01',
        'Term::UI'                  => '0.05',
        'Test::Harness'             => '2.62', # due to bug #19505
                                               # only 2.58 and 2.60 are bad
        'Test::More'                => '0.47', # to run our tests
        'Archive::Extract'          => '0.11', # bzip2 support
        'Archive::Tar'              => '1.23',
        'IO::Zlib'                  => '1.04',
        'Object::Accessor'          => '0.03',
        'Module::CoreList'          => '1.97',
        'Module::Pluggable'         => '2.4',
        'Module::Loaded'            => '0.01',
        #'Config::Auto'             => 0,   # not yet, not using it yet
    };

    ### depending on your choices, we might need to add some modules
    ### to your PREREQ_PM
    {   if( !$Config->get_conf('prefer_makefile')  ) {
            $Prereq->{ 'CPANPLUS::Dist::Build' } = '0.04';
        }
        
        if( $^O eq 'MSWin32') {
            $Prereq->{ 'Win32::Process' } = 0;
        }

        ### used to have 0.80, but not it was never released by coral
        ### 0.79 *should* be good enough for now... asked coral to 
        ### release 0.80 on 10/3/2006
        ### Win32 and Cygwin users need it.. otherwise, no buffers
        ### can be captured
        if( $^O eq 'MSWin32' or $^O eq 'Cygwin' ) {
            $Prereq->{ 'IPC::Run' } = '0.79';
        }            
    }


    ### restore the original @INC, so proper probing of missing 
    ### prereqs can be done
    @INC = @ORIG_INC;
    name            ('CPANPLUS');
    author          ('Jos Boumans <kane@cpan.org>');
    abstract        ('Ameliorated interface to the CPAN');
    version_from    ('lib/CPANPLUS/Internals.pm');
    license         ('perl');
    no_index        ( directory => 'lib/CPANPLUS/inc' );
    install_script  ($_) for glob('bin/*');
    requires        (%$Prereq);
    makemaker_args  ( test => { TESTS => $Tests } ) if $Tests;
    makemaker_args  ( clean => { FILES => 't/.*.output .cpanplus t/dummy-cpanplus/* t/dummy-cpanplus/.cpanplus' } );

    ### write the makefile 
    ### this makes all prereqs rediscovered
    {   use Module::Loaded;
        for ( keys %$Prereq ) {
            mark_as_unloaded( $_ ) if is_loaded( $_ );
        }            
        
        ### silence warnings about redefines... 
        ### this will still warn about redefine of CONSTANTS subs...
        no warnings; local $^W;
        &WriteAll( check_nmake => 1 ); 
    }
}

