package CPANPLUS::Selfupdate;

use strict;
use IPC::Cmd        qw[can_run];
use CPANPLUS::Error qw[error msg];

=head2 $self = CPANPLUS::Selfupdate->new( $backend_object );

=cut

sub new {
    my $class = shift;
    my $cb    = shift or return;
    return bless sub { $cb }, $class;
}    

my %Modules = (
    dependencies => {
        'File::Fetch'               => '0.08', # win32 ftp support
        'File::Spec'                => '0.82',
        'IPC::Cmd'                  => '0.29',
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
        'Object::Accessor'          => '0.32', # overloaded stringification
        'Module::CoreList'          => '2.09',
        'Module::Pluggable'         => '2.4',
        'Module::Loaded'            => '0.01',
    },

    features => {
        prefer_makefile => sub {
            my $cb = shift;
            $cb->configure_object->get_conf('prefer_makefile') 
                ? { 'CPANPLUS::Dist::Build' => '0.04' }
                : { 'CPANPLUS::Dist::MM'    => '0.0'  };
        },            
        cpantest        => {
            LWP              => '0.0',
            'LWP::UserAgent' => '0.0',
            'HTTP::Request'  => '0.0',
            URI              => '0.0',
            YAML             => '0.0',
            'Test::Reporter' => 1.27,
        },
        dist_type => sub { 
            my $cb      = shift;
            my $dist    = $cb->configure_object->get_conf('dist_type');
            return { $dist => '0.0' } if $dist;
            return;
        },            
        md5 => {
            'Digest::MD5'   => '0.0',
        },            
        shell => sub { 
            my $cb      = shift;
            my $dist    = $cb->configure_object->get_conf('shell');
            return { $dist => '0.0' } if $dist;
            return;
        },            
        signature => sub {
            my $cb      = shift;
            return if can_run('gpg') and 
                $cb->configure_object->get_conf('prefer_bin');
            return { 'Crypt::OpenPGP' => '0.0' };
        },            
        storable => { 'Storable' => '0.0' }                
    },
    core => {
        'CPANPLUS' => '0.0',
    },
    
    
    
);


=head2 $self->selfupdate

=cut

=head2 $self->modules_for_feature

=cut

sub modules_for_feature {
    my $self    = shift;
    my $feature = shift or return;
    my $cb      = $self->();
    
    unless( exists $Modules{'features'}->{$feature} ) {
        error(loc("Unknown feature '%1'", $feature));
        return;
    }
    
    my $ref = $Modules{'features'}->{$feature};
    
    ### it's either a list of modules/versions or a subroutine that
    ### returns a list of modules/versions
    my $href = UNIVERSAL::isa( $ref, 'HASH' ) ? $ref : $ref->( $cb );
    
    return unless $href;    # nothing needed for the feature?
    
    return map { 
            CPANPLUS::Selfupdate::Module->new(
                $cb->module_tree($_) => $href->{$_}
            )
        } keys %$href;
}

=head2 $self->list_features

=cut

sub list_features {
    my $self = shift;
    return keys %{ $Modules{'features'} };
}

=head2 $self->list_enabled_features

=cut

=head2 $self->list_core_dependencies

=cut


{   package CPANPLUS::Selfupdate::Module;
    use base 'CPANPLUS::Module';
    
    my $Acc = '_cpanplus_requires_version';

    ### create an accessor
    ### XXX this is WHITEBOX code -- if the implementation of CPANPLUS::Module
    ### changes, this code will break!
    {   no strict 'refs';
        *$Acc = sub {
            $_[0]->{$Acc} = $_[1] if @_ > 1;
            return $_[0]->{$Acc};
        }
    }
    
    sub new {
        my $class = shift;
        my $mod   = shift or return;
        my $ver   = shift or return;
        
        my $obj   = $mod->clone;    # clone the module object
        bless $obj, $class;         # rebless it to our class
        
        $obj->$Acc( $ver );
    }
    
    sub is_uptodate_for_cpanplus {
        my $self = shift;
        return $self->is_uptodate( $self->$Acc );
    }
}    

1;

=pod

=head1 AUTHOR

This module by
Jos Boumans E<lt>kane@cpan.orgE<gt>.

=head1 COPYRIGHT

The CPAN++ interface (of which this module is a part of) is
copyright (c) 2001 - 2006, Jos Boumans E<lt>kane@cpan.orgE<gt>.
All rights reserved.

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=cut

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:
