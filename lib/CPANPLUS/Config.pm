package CPANPLUS::Config;

use strict;
use warnings;

use base 'Object::Accessor';

use base 'CPANPLUS::Internals::Utils';

use Config;
use File::Spec;
use Module::Load;
use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;

use IPC::Cmd                    qw[can_run];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';
use Module::Load::Conditional   qw[check_install];

my $Conf = {
    '_fetch' => {
        'blacklist' => [ 'ftp' ],
    },
    'conf' => {
        ### default host list
        'hosts' => [
            {
                'scheme' => 'ftp',
                'path' => '/pub/CPAN/',
                'host' => 'ftp.cpan.org'
            },
            {
                'scheme' => 'http',
                'path' => '/',
                'host' => 'www.cpan.org'
            },
            {
                'scheme' => 'ftp',
                'path' => '/pub/CPAN/',
                'host' => 'ftp.nl.uu.net'
            },
            {
                'scheme' => 'ftp',
                'path' => '/pub/CPAN/',
                'host' => 'cpan.valueclick.com'
            },
            {
                'scheme' => 'ftp',
                'path' => '/pub/languages/perl/CPAN/',
                'host' => 'ftp.funet.fi'
            }
        ],
        'allow_build_interactivity' => 1,
        'base'                      => File::Spec->catdir(
                                        __PACKAGE__->_home_dir, DOT_CPANPLUS ),
        'buildflags'                => '',
        'cpantest'                  => 0,
        'debug'                     => 0,
        'dist_type'                 => '',
        'email'                     => DEFAULT_EMAIL,
        'extractdir'                => '',
        'fetchdir'                  => '',
        'flush'                     => 1,
        'force'                     => 0,
        'lib'                       => [],
        'makeflags'                 => '',
        'makemakerflags'            => '',
        'md5'                       => ( 
                            check_install( module => 'Digest::MD5' ) ? 1 : 0 ),
        'no_update'                 => 0,
        'passive'                   => 1,
        ### if we dont have c::zlib, we'll need to use /bin/tar or we
        ### can not extract any files. Good time to change the default
        'prefer_bin'                => (eval {require Compress::Zlib; 1}?0:1),
        'prefer_makefile'           => 1,
        'prereqs'                   => PREREQ_ASK,
        'shell'                     => 'CPANPLUS::Shell::Default',
        'signature'                 => ( (can_run( 'gpg' ) || 
                            check_install( module => 'Crypt::OpenPGP' ))?1:0 ),
        'skiptest'                  => 0,
        'storable'                  => (
                            check_install( module => 'Storable' )  ? 1 : 0 ),
        'timeout'                   => 300,
        'verbose'                   => $ENV{PERL5_CPANPLUS_VERBOSE} || 0,
        'write_install_logs'        => 1,
    },
    ### Paths get stripped of whitespace on win32 in the constructor
    ### sudo gets emptied if there's no need for it in the constructor
    'program' => {
        'editor'    => ( $ENV{'EDITOR'}  || $ENV{'VISUAL'} ||
                         can_run('vi')   || can_run('pico')
                       ),
        'make'      => ( can_run($Config{'make'}) || can_run('make') ),
        'pager'     => ( $ENV{'PAGER'} || can_run('less') || can_run('more') ),
        ### no one uses this feature anyway, and it's only working for EU::MM
        ### and not for module::build
        #'perl'      => '',
        'shell'     => ( $^O eq 'MSWin32' ? $ENV{COMSPEC} : $ENV{SHELL} ),
        'sudo'      => ( $>    # check for all install dirs!
                            ? ( -w $Config{'installsitelib'} &&
                                -w $Config{'installsiteman3dir'} &&
                                -w $Config{'installsitebin'} 
                                    ? undef
                                    : can_run('sudo') 
                              )
                            : can_run('sudo')
                        ),
    },

    ### _source, _build and _mirror are supposed to be static
    ### no changes should be needed unless pause/cpan changes
    '_source' => {
        'hosts'             => 'MIRRORED.BY',
        'auth'              => '01mailrc.txt.gz',
        'stored'            => 'sourcefiles',
        'dslip'             => '03modlist.data.gz',
        'update'            => '86400',
        'mod'               => '02packages.details.txt.gz'
    },
    '_build' => {
        'plugins'           => 'plugins',
        'moddir'            => 'build',
        'startdir'          => '',
        'distdir'           => 'dist',
        'autobundle'        => 'autobundle',
        'autobundle_prefix' => 'Snapshot',
        'autdir'            => 'authors',
        'install_log_dir'   => 'install-logs',
        'sanity_check'      => 1,
    },
    '_mirror' => {
        'base'              => 'authors/id/',
        'auth'              => 'authors/01mailrc.txt.gz',
        'dslip'             => 'modules/03modlist.data.gz',
        'mod'               => 'modules/02packages.details.txt.gz'
    },
};
    
sub new {
    my $class   = shift;
    my $obj     = $class->SUPER::new;

    $obj->mk_accessors( keys %$Conf );

    for my $acc ( keys %$Conf ) {
        my $subobj = Object::Accessor->new;
        $subobj->mk_accessors( keys %{$Conf->{$acc}} );

        ### read in all the settings from the sub accessors;
        for my $subacc ( $subobj->ls_accessors ) {
            $subobj->$subacc( $Conf->{$acc}->{$subacc} );
        }

        ### now store it in the parent object
        $obj->$acc( $subobj );
    }
    
    $obj->_clean_up_paths;
    
    ### shut up IPC::Cmd warning about not findin IPC::Run on win32
    $IPC::Cmd::WARN = 0;
    
    return $obj;
}

sub _clean_up_paths {
    my $self = shift;

    ### clean up paths if we are on win32
    if( $^O eq 'MSWin32' ) {
        for my $pgm ( $self->program->ls_accessors ) {
            $self->program->$pgm(
                Win32::GetShortPathName( $self->program->$pgm )
            ) if $self->program->$pgm =~ /\s+/;      
        }
    }

    return 1;
}

1;
