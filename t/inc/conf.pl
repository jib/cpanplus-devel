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

use strict;
use CPANPLUS::Configure;

use FileHandle;
use File::Basename  qw[basename];

{   ### Force the ignoring of .po files for L::M::S
    $INC{'Locale::Maketext::Lexicon.pm'} = __FILE__;
    $Locale::Maketext::Lexicon::VERSION = 0;
}

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

1;
