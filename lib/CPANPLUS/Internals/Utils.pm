package CPANPLUS::Internals::Utils;

use strict;

use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;

use Cwd;
use File::Copy;
use Params::Check               qw[check];
use Module::Load::Conditional   qw[can_load];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

local $Params::Check::VERBOSE = 1;

=pod

=head1 NAME

CPANPLUS::Internals::Utils

=head1 SYNOPSIS

    my $bool = $cb->_mkdir( dir => 'blah' );
    my $bool = $cb->_chdir( dir => 'blah' );
    my $bool = $cb->_rmdir( dir => 'blah' );

    my $bool = $cb->_move( from => '/some/file', to => '/other/file' );
    my $bool = $cb->_move( from => '/some/dir',  to => '/other/dir' );

    my $cont = $cb->_get_file_contents( file => '/path/to/file' );


    my $version = $cb->_perl_version( perl => $^X );

=head1 DESCRIPTION

C<CPANPLUS::Internals::Utils> holds a few convenience functions for
CPANPLUS libraries.

=head1 METHODS

=head2 $cb->_mkdir( dir => '/some/dir' )

C<_mkdir> creates a full path to a directory.

Returns true on success, false on failure.

=cut

sub _mkdir {
    my $self = shift;

    my %hash = @_;

    my $tmpl = {
        dir     => { required => 1 },
    };

    my $args = check( $tmpl, \%hash ) or (
        error(loc( Params::Check->last_error ) ), return
    );       

    unless( can_load( modules => { 'File::Path' => 0.0 } ) ) {
        error( loc("Could not use File::Path! This module should be core!") );
        return;
    }

    eval { File::Path::mkpath($args->{dir}) };

    if($@) {
        chomp($@);
        error(loc(qq[Could not create directory '%1': %2], $args->{dir}, $@ ));
        return;
    }

    return 1;
}

=pod

=head2 $cb->_chdir( dir => '/some/dir' )

C<_chdir> changes directory to a dir.

Returns true on success, false on failure.

=cut

sub _chdir {
    my $self = shift;
    my %hash = @_;

    my $tmpl = {
        dir     => { required => 1, allow => DIR_EXISTS },
    };

    my $args = check( $tmpl, \%hash ) or return;

    unless( chdir $args->{dir} ) {
        error( loc(q[Could not chdir into '%1'], $args->{dir}) );
        return;
    }

    return 1;
}

=pod

=head2 $cb->_rmdir( dir => '/some/dir' );

Removes a directory completely, even if it is non-empty.

Returns true on success, false on failure.

=cut

sub _rmdir {
    my $self = shift;
    my %hash = @_;

    my $tmpl = {
        dir     => { required => 1, allow => IS_DIR },
    };

    my $args = check( $tmpl, \%hash ) or return;

    unless( can_load( modules => { 'File::Path' => 0.0 } ) ) {
        error( loc("Could not use File::Path! This module should be core!") );
        return;
    }

    eval { File::Path::rmtree($args->{dir}) };

    if($@) {
        chomp($@);
        error(loc(qq[Could not delete directory '%1': %2], $args->{dir}, $@ ));
        return;
    }

    return 1;
}

=pod

=head2 $cb->_perl_version ( perl => 'some/perl/binary' );

C<_perl_version> returns the version of a certain perl binary.
It does this by actually running a command.

Returns the perl version on success and false on failure.

=cut

sub _perl_version {
    my $self = shift;
    my %hash = @_;

    my $perl;
    my $tmpl = {
        perl    => { required => 1, store => \$perl },
    };

    check( $tmpl, \%hash ) or return;
    
    my $perl_version;
    ### special perl, or the one we are running under?
    if( $perl eq $^X ) {
        ### just load the config        
        require Config;
        $perl_version = $Config::Config{version};
        
    } else {
        my $cmd  = $perl .
                ' -MConfig -eprint+Config::config_vars+version';
        ($perl_version) = (`$cmd` =~ /version='(.*)'/);
    }
    
    return $perl_version if defined $perl_version;
    return;
}

=pod

=head2 $cb->_version_to_number( version => $version );

Returns a proper module version, or '0.0' if none was available.

=cut

sub _version_to_number {
    my $self = shift;
    my %hash = @_;

    my $version;
    my $tmpl = {
        version => { default => '0.0', store => \$version },
    };

    check( $tmpl, \%hash ) or return;

    return $version if $version =~ /^\.?\d/;
    return '0.0';
}

=pod

=head2 $cb->_whoami

Returns the name of the subroutine you're currently in.

=cut

sub _whoami { my $name = (caller 1)[3]; $name =~ s/.+:://; $name }

=pod

=head2 _get_file_contents( file => $file );

Returns the contents of a file

=cut

sub _get_file_contents {
    my $self = shift;
    my %hash = @_;

    my $file;
    my $tmpl = {
        file => { required => 1, store => \$file }
    };

    check( $tmpl, \%hash ) or return;

    my $fh = OPEN_FILE->($file) or return;
    my $contents = do { local $/; <$fh> };

    return $contents;
}

=pod $cb->_move( from => $file|$dir, to => $target );

Moves a file or directory to the target.

Returns true on success, false on failure.

=cut

sub _move {
    my $self = shift;
    my %hash = @_;

    my $from; my $to;
    my $tmpl = {
        file    => { required => 1, allow => [IS_FILE,IS_DIR],
                        store => \$from },
        to      => { required => 1, store => \$to }
    };

    check( $tmpl, \%hash ) or return;

    if( File::Copy::move( $from, $to ) ) {
        return 1;
    } else {
        error(loc("Failed to move '%1' to '%2': %3", $from, $to, $!));
        return;
    }
}

=pod $cb->_copy( from => $file|$dir, to => $target );

Moves a file or directory to the target.

Returns true on success, false on failure.

=cut

sub _copy {
    my $self = shift;
    my %hash = @_;
    
    my($from,$to);
    my $tmpl = {
        file    =>{ required => 1, allow => [IS_FILE,IS_DIR],
                        store => \$from },
        to      => { required => 1, store => \$to }
    };

    check( $tmpl, \%hash ) or return;

    if( File::Copy::copy( $from, $to ) ) {
        return 1;
    } else {
        error(loc("Failed to copy '%1' to '%2': %3", $from, $to, $!));
        return;
    }
}

=head2 $cb->_mode_plus_w( file => '/path/to/file' );

Sets the +w bit for the file.

Returns true on success, false on failure.

=cut

sub _mode_plus_w {
    my $self = shift;
    my %hash = @_;
    
    require File::stat;
    
    my $file;
    my $tmpl = {
        file    => { required => 1, allow => IS_FILE, store => \$file },
    };
    
    check( $tmpl, \%hash ) or return;
    
    ### set the mode to +w for a file and +wx for a dir
    my $x       = File::stat::stat( $file );
    my $mask    = -d $file ? 0100 : 0200;
    
    if( $x and chmod( $x->mode|$mask, $file ) ) {
        return 1;

    } else {        
        error(loc("Failed to '%1' '%2': '%3'", 'chmod +w', $file, $!));
        return;
    }
}    

=head2 $uri = $cb->_host_to_uri( scheme => SCHEME, host => HOST, path => PATH );

Turns a CPANPLUS::Config style C<host> entry into an URI string.

Returns the uri on success, and false on failure

=cut

sub _host_to_uri {
    my $self = shift;
    my %hash = @_;
    
    my($scheme, $host, $path);
    my $tmpl = {
        scheme  => { required => 1,     store => \$scheme },
        host    => { default  => '',    store => \$host },
        path    => { default  => '',    store => \$path },
    };       

    check( $tmpl, \%hash ) or return;

    $host ||= 'localhost';

    return "$scheme://" . File::Spec::Unix->catdir( $host, $path ); 
}

=head2 $cb->_vcmp( VERSION, VERSION );

Normalizes the versions passed and does a '<=>' on them, returning the result.

=cut

sub _vcmp {
    my $self = shift;
    my ($x, $y) = @_;
    
    s/_//g foreach $x, $y;

    return $x <=> $y;
}

=head2 $cb->_homedir

Returns the user's homedir, or C<cwd> if it could not be found

=cut

sub _home_dir {
    my @os_home_envs = qw( APPDATA HOME USERPROFILE WINDIR SYS$LOGIN );

    for my $env ( @os_home_envs ) {
        next unless exists $ENV{ $env };
        next unless defined $ENV{ $env } && length $ENV{ $env };
        return $ENV{ $env } if -d $ENV{ $env };
    }

    return cwd();
}

1;

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4: