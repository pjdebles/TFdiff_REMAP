#!/usr/bin/perl 
use strict;
use warnings;
use File::Basename;
use Data::Dumper;		
use FindBin;
use Getopt::Long;
use List::Compare;

my $DEBUG      = 0;

@ARGV == 2 or die "usage: $0 genes_list (1 gene per line) tfbs_vectors_db (e.g. ../data/hg19_genes_tf_targeted_10_jaccard_distmat.vector) \n";
my ($geneNamesFile, $geneTfbsFile) = @ARGV;

if( !-f $geneNamesFile || !-r $geneNamesFile ) {

   die( sprintf( 'Unable to read file: `%s` -- %s', $geneNamesFile, $! ) );
}

if( !-f $geneTfbsFile || !-r $geneTfbsFile ) {

   die( sprintf( 'Unable to read file: `%s` -- %s', $geneTfbsFile, $! ) );
}

print STDERR "file with genes and associated TFBS: $geneTfbsFile\n" if $DEBUG;

my $firstLine = `head -n 1 $geneTfbsFile`;

my @geneNames = readFile( $geneNamesFile );

#print STDERR Dumper \@geneNames;

my @List = ();
foreach my $gene ( @geneNames ) {

   $gene =~ s/^\s*//g;
   $gene =~ s/\s*$//g;
   my $geneTfbsCounts = `egrep ^$gene\[[:space:]] $geneTfbsFile`;
   push ( @List, $geneTfbsCounts );
}
chomp( @List );

print $firstLine;
foreach my $result ( @List ) {
   next if $result =~ /^\s*$/;
   print $result,"\n";
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

