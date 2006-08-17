my $Ver = shift or die usage();

my %Files = (
    qq[s/VERSION\\s*=.*?;/VERSION = "$Ver";/]
        => [qw[ lib/CPANPLUS.pm
                lib/CPANPLUS/Internals.pm
                lib/CPANPLUS/Shell/Default.pm
            ]],
    qq[s/version:.*\$/version: $Ver/]                  
        => [qw[ META.yml]],
);        

map { system( "p4 edit $_" ) } map { @$_ } values %Files;

while( my($re,$aref) = each %Files ) {

    for my $file (@$aref) {
    
        my $cmd = qq[$^X -pi -e'$re'];
        print "Running [$cmd $file]\n";

        system( "$cmd $file" );
    }
}    

system("p4 diff | less");
system("p4 submit");



sub usage {
    return qq[
Usage:
    $0 NEW_VERSION

    ];
}    
