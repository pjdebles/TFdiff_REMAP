#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  calcSignificance.pl
#
#        USAGE:  ./calcSignificance.pl  
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
#      CREATED:  07/07/2011 01:20:33 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;
use FindBin;

# ============================================================================ #

my $DEBUG = 0;
@ARGV == 3 or die "usage: $0 <bgHash.json> <trendHash.json> <result_file>\n";
my ( $bgHash_file, $trendHash_file, $resultFile ) = @ARGV;


my %bgHash    = %{ load_json( $bgHash_file ) };
my %trendHash = %{ load_json( $trendHash_file ) };

# ============================================================================ #
# Calculate p-values

open( INFILE, $resultFile );
while (<INFILE>) {

   chomp();
   (my $pwmId, my $x2, my $y2, my $dist2Origin, my $slope, my $trend) = split(/\t/);
   my (undef, undef, $pvalue) = pvalue($dist2Origin, \@{ $bgHash{$pwmId} });
   my (undef, undef, $pvalue_trend) = pvalue($trend, \@{ $trendHash{$pwmId} });

   print "$pwmId\t$x2\t$y2\t$dist2Origin\t$slope\t$pvalue\t$trend\t$pvalue_trend\n";
}

################################################################################
#
# pvalue (empirical)
#
# (find the percentage of replicates that are bigger than the observed value)

sub pvalue {
    my ($x, $a) = @_;            # binary search for x in SORTED (asc) array a
    my ($l, $u, $ldx) = (0, @$a - 1, @$a - 1);  # lower, upper end of search interval (x2 - aliased)
    my $pval;
    my $i;                       # index of probe
    while ($l <= $u) {
	$i = int(($l + $u)/2);
	if ($a->[$i] < $x) {
	    $l = $i+1;
	}
	elsif ($a->[$i] > $x) {
	    $u = $i-1;
	} 
	else {
         $pval = (($ldx+1)-($i+1))/($ldx+1);
	     return ($i,$ldx,$pval); # exact match...
	     }
    }
    $pval = (($ldx+1)-($i))/($ldx+1);
    return ($i,$ldx,$pval); # or not...
}

# ============================================================================ #

sub load_json {

   my $file = shift;

   local $/;
   open( my $fh, $file );
   my $json_blob = <$fh>;
   close ($fh);

   return decode_json $json_blob;
}
