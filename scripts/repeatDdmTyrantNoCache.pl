#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  repeatDdmTyrantNoCache.pl
#
#        USAGE:  ./repeatDdmTyrantNoCache.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Dr. Pieter De Bleser (), pieterdb@dmbr.vib-ugent.be
#      COMPANY:  Department for Molecular Biomedical Research (DMBR), VIB
#      VERSION:  1.0
#      CREATED:  04/20/2015 11:43:38 AM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

# some configuration
#my $geneNames = "/home/pieterdb/TFdiff_REMAP/data/hg19_genes_tf_targeted_10_jaccard_distmat_TAGC.genenames";
my $geneNames = "/home/pieterdb/TFdiff_REMAP/data/hg19_genes_tf_targeted_5_jaccard_distmat_TAGC.genenames";
my $ddmTyrant = "/home/pieterdb/TFdiff_REMAP/scripts/ddmTyrantNoCache.pl";

@ARGV == 2 or die "usage: $0 genes.list 10 (number times to repeat)\n";

my ( $genesList, $numberTimes ) = @ARGV;
my $numberLines = `wc -l $genesList`;
my ($numberGenes,undef) = split( / /, $numberLines);

my $numberRandomGenes = $numberGenes * 2; # hardcoded... :(
my $randomGenesFile = "randomSet".$numberRandomGenes.".list";

for ( 1..$numberTimes ) {
      print $_,"\t",$genesList,"\t",$numberGenes,"\t",$randomGenesFile,"\n";

      my $range = 10000000;
      my $seed = int(rand($range));
      system("randomLines -seed=$seed $geneNames $numberRandomGenes $randomGenesFile");
      system("cat $randomGenesFile");
      system("$ddmTyrant $genesList $randomGenesFile");
      
    }
