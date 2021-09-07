#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  TFdiffReMap.pl
#
#        USAGE:  ./TFdiffReMap.pl  
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
#      CREATED:  08/17/2015 03:40:24 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use File::Basename;
use File::Path;
use Cwd qw(abs_path);

my $DEBUG = 1;

my $scriptdir = abs_path($0);
$scriptdir =~ s=/[^/]+.pl==;
print "script dir: $scriptdir\n" if $DEBUG;

# configuration
# scripts:
my $repeatDdmTyrantNoCache = "/home/pieterdb/TFdiff_REMAP/scripts/repeatDdmTyrantNoCache.pl";
my $buildRankTable = "/home/pieterdb/TFdiff_REMAP/scripts/buildRankTable.pl";
my $rankProductExactPvalue = "/home/pieterdb/TFdiff_REMAP/scripts/rank_product_exact_pvalue.R";
my $createSubMatrix = "/home/pieterdb/TFdiff_REMAP/scripts/createSubMatrix.pl";
my $vector2Network = "/home/pieterdb/TFdiff_REMAP/scripts/vector2Network.pl";
my $network2Vector = "/home/pieterdb/TFdiff_REMAP/scripts/network2vector.pl";
my $vector2Cluto = "/home/pieterdb/TFdiff_REMAP/scripts/vector2cluto.R";

# data:
my $hg19_genes_tf_targeted_1_jaccard_distmat_TAGC_vector = "/home/pieterdb/TFdiff_REMAP/data/hg19_genes_tf_targeted_1_jaccard_distmat_TAGC.vector";
my $hg19_genes_tf_targeted_5_jaccard_distmat_TAGC_vector = "/home/pieterdb/TFdiff_REMAP/data/hg19_genes_tf_targeted_5_jaccard_distmat_TAGC.vector";
my $hg19_genes_tf_targeted_10_jaccard_distmat_TAGC_vector = "/home/pieterdb/TFdiff_REMAP/data/hg19_genes_tf_targeted_10_jaccard_distmat_TAGC.vector";

@ARGV >= 3 or die "usage: $0 genes.list (HGNC; 1 gene name per line) number_iterations (e.g. 3) qvalue_cutoff (e.g. 0.05) norepeat (optional)\n";
my ($genesFile, $numberIterations, $qvalueCutOff, $norepeat) = @ARGV;

if ( !defined($norepeat) ) { qx|$repeatDdmTyrantNoCache $genesFile $numberIterations|; }

# anticipate on the name of the output file e.g.:
# EZH2_genes_vs_randomSet16_ddm_pval_annotated_results.txt

my ($baseName, $path, $suffix) = fileparse($genesFile, (".genes",".list") );
print "base name of $genesFile: $baseName\n" if $DEBUG;
    
my $numberLines = `wc -l $genesFile`;
my ($numberGenes,undef) = split( / /, $numberLines);
my $numberRandomGenes = $numberGenes * 2; # hardcoded... :(

my $annotatedResultsFile = $baseName."_vs_randomSet".$numberRandomGenes."_ddm_pval_annotated_results.txt";
print "anticipated annotated results file: $annotatedResultsFile\n" if $DEBUG; 

my $rankResultsFile = $baseName."_vs_randomSet".$numberRandomGenes."_Rank.csv";
print "anticipated rank results file: $rankResultsFile\n" if $DEBUG; 
qx|$buildRankTable . $annotatedResultsFile > $rankResultsFile|;

qx|$rankProductExactPvalue $rankResultsFile|;
# output file looks like EZH2_genes_vs_randomSet16_Rank_RP_meta_analysis.csv

my $rankProductFile = $baseName."_vs_randomSet".$numberRandomGenes."_Rank_RP_meta_analysis.csv";
print "anticipated rank product file: $rankProductFile\n" if $DEBUG; 

my $cofactorsList = $baseName."_cofactors.list";
system("awk \'  \$NF <= $qvalueCutOff \' $rankProductFile | cut -f 1 > $cofactorsList");  

my $genesVector = $baseName.".vector";
print "$createSubMatrix $genesFile $hg19_genes_tf_targeted_5_jaccard_distmat_TAGC_vector > $genesVector\n" if $DEBUG;
system("$createSubMatrix $genesFile $hg19_genes_tf_targeted_5_jaccard_distmat_TAGC_vector > $genesVector");

my $networkFile = $baseName.".network";
qx|$vector2Network $cofactorsList $genesVector > $networkFile|;


qx|$network2Vector $networkFile > $genesVector|;
qx|$vector2Cluto $genesVector|;

my $clutoFile = $baseName.".cluto";
my $plotMatrixFile = $baseName.".ps";

qx|vcluster -fulltree -clustercolumns -plotmatrix=$plotMatrixFile $clutoFile 1|;

qx|evince $plotMatrixFile|;


