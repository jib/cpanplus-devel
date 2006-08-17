use strict;
use Cwd;
use CPANPLUS::Backend;

my $Prefix      = '../../other/';           # updir from cpanplus/devel 
my $Libdir      = 'lib/';
my $Target      = cwd() . '/inc/bundle';    # Target dir to copy to
my $CB          = CPANPLUS::Backend->new;
my $MineOnly    = @ARGV ? 1 : 0;

$CB->configure_object->set_conf( verbose => 1 );

### p4 open everything
system("find $Target -type f | xargs p4 edit");

### from p4 
{   my @Copy    = qw[
        archive-extract/
        archive-tar-new/
        file-fetch/
        ipc-cmd/
        log-message/
        log-message-simple/
        module-load/
        module-loaded/
        module-load-conditional/
        object-accessor/
        package-constants/
        params-check/
        term-ui/
    ];

    for my $entry (@Copy) {
        my $dir = $Prefix . $entry . $Libdir;
        
        print "Copying files from $entry...";
        system("cp -R $dir $Target");
        print "done\n";
    }
}



### from installations 
unless( $MineOnly ) {  
    my @Modules = qw[
        File::Spec
        IO::String
        IO::Zlib
        IPC::Run
        Locale::Maketext::Simple
        Module::CoreList
        Module::Pluggable
    ];
    
    for my $module ( @Modules ) {
        print "Updating $module...";

        my $obj = $CB->module_tree( $module );

        $obj->fetch( fetchdir => '/tmp' )   or die "Could not fetch";
        my $dir = $obj->extract( extractdir => '/tmp' )  
                                            or die "Could not extract";
       
        ### either they have the lib structure
        if( -d $dir . "/lib" ) {
            chdir $dir . "/lib" or die "Could not chdir: $!";
            system("cp -R . $Target") and die "Could not copy files";

            print "done\n";
            next;
        } 

        ### ok, so no libdir... let's see if they have just the pm in
        ### the topdir
        chdir $dir or die "Could not chdir to $dir: $!";
        
        my @parts = split '::', $module;
        my $file = pop(@parts) . '.pm';
        if ( -e $file ) {
            my $to = $Target . '/' . join '/', @parts, $file;
            system("cp $file $to") and die "Could not copy $file to $to: $!\n";
            
            print "done\n";
            next;
        }
        
        die "Dont know how to copy $module from $dir\n";
        
    }        
}        
        

# 
# ### set all the versions to -1
# if(0) {
#     for my $file ( map { chomp; $_ } `find $Target -type f` ) {
#         system( "p4 edit $file" );
#     
#         my $code = q[s/(\$|:)VERSION\s*=.+$/${1}VERSION = "-1";/];
# 
#         my $cmd  = qq[$^X -pi -e'$code'];
#         print "Running [$cmd $file]\n";
# 
#         system( "$cmd $file" );
#     }        
# }

### revert all that wasn't touched
system("p4 revert -a");
system("find $Target -type f | xargs p4 add");
system("p4 diff | less");
system("p4 submit");


__END__
find $dir -type f | xargs p4 edit
p4 revert -a
find $dir -type f | xargs p4 add
