#!/usr/bin/perl 
use strict;
use warnings;

my $DEBUG  = 0;

@ARGV == 2 or die "usage: $0 genes_list regulatory_matrix (vector file)\n";
my ($geneNamesFile, $matrixFile) = @ARGV;

my @geneNames = readFile( $geneNamesFile );

my $colHeader = `head -n 1 $matrixFile`;
chomp( $colHeader );
print $colHeader,"\n";
foreach my $gene ( @geneNames ) {
        #remove white space from both ends of a string:
        $gene =~ s/^\s+|\s+$//g;
        my $row = `egrep ^$gene\[[:space:]] $matrixFile`;
        chomp( $row );
        print $row,"\n";
        }

#########################################################################################################
#
# readFile

sub readFile {
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
