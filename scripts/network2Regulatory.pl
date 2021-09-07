#!/usr/bin/perl 
use strict;
use warnings;

@ARGV == 1 or die "usage: $0 network_file (from beta2NetWork.pl)\n";
my ($network) = @ARGV;

my @relations = readFile($network);
chomp( @relations );

my %Regulators = ();
my %RegulatedOnes = ();

print "Gene\tRegulatory function\n";
foreach my $interaction (@relations) {
        my ($regulator, $interactionType, $regulated, undef ) = split( /\t/, $interaction);
        $Regulators{ $regulator } = 1;
        $RegulatedOnes{ $regulated } = 1;
        }

print "$_\tRegulator\n" for (keys %Regulators);
print "$_\tRegulated\n" for (keys %RegulatedOnes);

#########################################################################################################
#
# readFile 
#

sub readFile {
    my ($file) = shift;
    my @list = ();

    open( INFILE, $file );
    while (<INFILE>) {
        chomp();
        push ( @list, $_ );
    }
    close(INFILE);
    return @list;
}
