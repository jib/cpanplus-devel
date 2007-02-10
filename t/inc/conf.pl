BEGIN { chdir 't' if -d 't' };
BEGIN {
    use File::Spec;
    require lib;
    my @paths = map { File::Spec->rel2abs($_) } qw[../lib inc];
    
    ### include them, relative from t/
    for ( @paths ) { my $l = 'lib'; $l->import( $_ ) }

    ### and add them to the environment, so shellouts get them
    $ENV{'PERL5LIB'} = join ':', grep { defined } $ENV{'PERL5LIB'}, @paths;
}

BEGIN {
    use IPC::Cmd;
   
    ### Win32 has issues with redirecting FD's properly in IPC::Run:
    ### Can't redirect fd #4 on Win32 at IPC/Run.pm line 2801
    $IPC::Cmd::USE_IPC_RUN = 0 if $^O eq 'MSWin32';
    $IPC::Cmd::USE_IPC_RUN = 0 if $^O eq 'MSWin32';
}

use strict;
use CPANPLUS::Configure;

use File::Path      qw[rmtree];
use FileHandle;
use File::Basename  qw[basename];

{   ### Force the ignoring of .po files for L::M::S
    $INC{'Locale::Maketext::Lexicon.pm'} = __FILE__;
    $Locale::Maketext::Lexicon::VERSION = 0;
}

# prereq has to be in our package file && core!
use constant TEST_CONF_PREREQ       => 'Cwd';   
use constant TEST_CONF_MODULE       => 'Foo::Bar::EU::NOXS';
use constant TEST_CONF_INST_MODULE  => 'Foo::Bar';

sub gimme_conf { 
    my $conf = CPANPLUS::Configure->new();
    $conf->set_conf( hosts  => [ { 
                        path        => 'dummy-CPAN',
                        scheme      => 'file',
                    } ],      
    );
    $conf->set_conf( base       => 'dummy-cpanplus' );
    $conf->set_conf( dist_type  => '' );
    $conf->set_conf( signature  => 0 );

    _clean_dot_cpanplus_dir( $conf );

    return $conf;
};

my $fh;
my $file = ".".basename($0).".output";
sub output_handle {
    return $fh if $fh;
    
    $fh = FileHandle->new(">$file")
                or warn "Could not open output file '$file': $!";
   
    $fh->autoflush(1);
    return $fh;
}

sub output_file { return $file }

### whenever we start a new script, we want to clean out our
### old files from the test '.cpanplus' dir..
sub _clean_dot_cpanplus_dir {
    my $conf    = shift;
    my $base    = $conf->get_conf('base');
    my $verbose = shift || 0;

    my $dh;
    opendir $dh, $base or die "Could not open basedir '$base': $!";
    while( my $file = readdir $dh ) { 
        next if $file =~ /^\./;  # skip dot files
        
        my $path = File::Spec->catfile( $base, $file );
        
        ### directory, rmtree it
        if( -d $path ) {
            print "Deleting directory '$path'\n" if $verbose;
            eval { rmtree( $path ) };
            warn "Could not delete '$path' while cleaning up '$base'" if $@;
       
        ### regular file
        } else {
            print "Deleting file '$path'\n" if $verbose;
            1 while unlink $path;
        }            
            
    }
    close $dh;
}
1;
