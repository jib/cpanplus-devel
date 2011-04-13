use strict;
use Data::Dumper;

my $Target  = "sandbox.$$";       # Target dir to copy to
my $NoWhipe = @ARGV ? 1 : 0;      # clean up afterwards?

warn "\n\n\n\tBuilding in $Target\n\n\n";

print "\n\n\t*** Making Dist***\n\n";
system("$^X Makefile.PL JFDI=1");
system("make dist");


my $cmd = q[ls -1 | grep CPANPLUS | grep 'gz$'];
chomp(my($tar) = `$cmd`);

my $dir = $tar; $dir =~ s/\.tar\.gz//;


print "\n\n\t*** Moving files to target dir***\n\n";
### create a sandbox
system("mkdir $Target");

### move the tarfile
system("mv $tar $Target");

print "\n\n\t*** Extracting $tar***\n\n";
### chdir & extract
system("cd $Target; tar -zxvf $tar");

### chdir to the dist dir
system("cd $dir");

print "\n\n\t*** Running Makefile.PL***\n\n";
map { delete $ENV{$_} } grep /PERL/, keys %ENV;

system("$^X Makefile.PL");
system("make test");

system("cd ../..");

print "\n\n\t*** Cleaning up***\n\n";
system("rm -rf $Target") unless $NoWhipe;


__END__


### p4 open everything
system("find $Target -type f | xargs p4 edit");


for my $entry (@Copy) {
    my $dir = $Prefix . $entry . $Libdir;

    system("cp -R $dir $Target");
}

### revert all that wasn't touched
system("p4 revert -a");
system("find $Target -type f | xargs p4 add");
system("p4 diff | less");
system("p4 submit");


__END__
find $dir -type f | xargs p4 edit
p4 revert -a
find $dir -type f | xargs p4 add
