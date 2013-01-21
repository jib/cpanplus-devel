my $Ver = shift or die usage();
my $Scm = shift || 'git';

my %Files = (
    qq[s/VERSION\\s*=.*?;/VERSION = "$Ver";/]
        => [qw[ lib/CPANPLUS.pm
                lib/CPANPLUS/Internals.pm
                lib/CPANPLUS/Shell/Default.pm
                lib/CPANPLUS/Internals/Source/SQLite/Tie.pm
                lib/CPANPLUS/Internals/Source/Memory.pm
                lib/CPANPLUS/Internals/Source/SQLite.pm
                lib/CPANPLUS/Internals/Constants/Report.pm
                lib/CPANPLUS/Internals/Utils/Autoflush.pm
                lib/CPANPLUS/Internals/Extract.pm
                lib/CPANPLUS/Internals/Constants.pm
                lib/CPANPLUS/Internals/Fetch.pm
                lib/CPANPLUS/Internals/Report.pm
                lib/CPANPLUS/Internals/Search.pm
                lib/CPANPLUS/Internals/Source.pm
                lib/CPANPLUS/Internals/Utils.pm
                lib/CPANPLUS/Backend/RV.pm
                lib/CPANPLUS/Module/Author/Fake.pm
                lib/CPANPLUS/Module/Author.pm
                lib/CPANPLUS/Module/Checksums.pm
                lib/CPANPLUS/Module/Fake.pm
                lib/CPANPLUS/Module/Signature.pm
                lib/CPANPLUS/Dist/Autobundle.pm
                lib/CPANPLUS/Dist/Base.pm
                lib/CPANPLUS/Dist/MM.pm
                lib/CPANPLUS/Dist/Sample.pm
                lib/CPANPLUS/Configure/Setup.pm
                lib/CPANPLUS/Shell/Default/Plugins/CustomSource.pm
                lib/CPANPLUS/Shell/Default/Plugins/Remote.pm
                lib/CPANPLUS/Shell/Default/Plugins/Source.pm
                lib/CPANPLUS/Shell/Classic.pm
                lib/CPANPLUS/Backend.pm
                lib/CPANPLUS/Config.pm
                lib/CPANPLUS/Configure.pm
                lib/CPANPLUS/Dist.pm
                lib/CPANPLUS/Error.pm
                lib/CPANPLUS/Module.pm
                lib/CPANPLUS/Selfupdate.pm
                lib/CPANPLUS/Shell.pm
                lib/CPANPLUS/Config/HomeEnv.pm
            ]],
    qq[s/^version:.*\$/version: $Ver/]
        => [qw[ META.yml]],
);

#map { system( "p4 edit $_" ) } map { @$_ } values %Files;

while( my($re,$aref) = each %Files ) {

    for my $file (@$aref) {

        my $cmd = qq[$^X -pi -e'$re'];
        print "Running [$cmd $file]\n";

        system( "$cmd $file" );
    }
}

system("$Scm diff | less");
system("$Scm commit" . ($Scm eq 'git' ? ' -a' : ''));



sub usage {
    return qq[
Usage:
    $0 NEW_VERSION [git]

    ];
}
