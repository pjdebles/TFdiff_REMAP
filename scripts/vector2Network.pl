#!/usr/bin/perl 
use strict;
use warnings;

my $DEBUG  = 0;

@ARGV == 2 or die "usage: $0 tf_list regulatory_matrix (vector file)\n";
my ($tfNamesFile, $matrixFile) = @ARGV;

my @tfNames = readFileSimple( $tfNamesFile );
chomp( @tfNames );

my @AoA = readMatrix( $matrixFile );

my $colHeader = `head -n 1 $matrixFile`;
chomp( $colHeader );
my @tfLibrary = split( /\t/, $colHeader );

foreach my $tf ( @tfNames ) {
        my ($index) = grep { $tfLibrary[$_] eq $tf } (0 .. @tfLibrary-1);
        print "$tf\t",defined $index ? $index : -1,"\n" if $DEBUG;
        foreach my $row (1..@AoA-1){
                if ( $AoA[$row][$index] ) {
                    print "$tf\t$AoA[$row][ 0 ]-> Element [$row][$index] = $AoA[$row][$index]\n" if $DEBUG;
                    print "$tf\tpd\t$AoA[$row][ 0 ]\n";
                   }
                }
        }

#########################################################################################################
#
# readMatrix

sub readMatrix {
    my ($file) = shift;
    my @AoA = ();

    open( INFILE, $file );
    while (<INFILE>) {
        chomp();
        next if /^#/;
        push ( @AoA, [ split( /\t/ ) ] );
    }
    close(INFILE);
    return @AoA;
}

#########################################################################################################
#
# readFileSimple

sub readFileSimple {
    my ($file) = shift;
    my @list = ();

    open( INFILE, $file );
    while (<INFILE>) {
        chomp();
        next if /^#/;
        push ( @list, $_ );
    }
    close(INFILE);
    return @list;
}

