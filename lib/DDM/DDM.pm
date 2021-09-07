#!/usr/bin/perl
# ============================================================================ #
#
#         FILE:  DDM.pm
#
#        USAGE:  use DDM
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Pieter De Bleser (pieter.debleser@irc.vib-UGent.be)
#      COMPANY:  VIB-UGent
#      VERSION:  0.1
#      CREATED:  2014-10-28 Tue 09:03:46
#     REVISION:  
# ============================================================================ #

package DDM;

use strict;
use warnings;

use Algorithm::DistanceMatrix;
use CAD::Calc qw( slope dist2d);
use Exporter 'import';
use File::Temp qw/ tempfile /;
use FindBin;
use lib $FindBin::RealBin;
use Math::Matrix;
use Tfdiff;

our @EXPORT = qw(
   runDDM
   runMDS
   createDistanceMatrix
   print2DMatrixRef
   euclidean
   print2DMatrixRef
   read2DMatrixFromFile
);

our $VERBOSITY;

################################################################################
#
# runMDS (wrapper for Kleiwegs' 'mds' program)
#

sub runDDM {

   my $upFile     = shift;
   my $downFile   = shift;
   my $resultFile = shift;
   my $unlink     = shift || 0;

   llog( sprintf('$upFile : %s'     , $upFile)     , $V_DEBUG );
   llog( sprintf('$downFile : %s'   , $downFile)   , $V_DEBUG);
   llog( sprintf('$resultFile : %s' , $resultFile) , $V_DEBUG);
   llog( sprintf('$unlink : %s'     , $unlink)     , $V_DEBUG);

   my ( $dmUp, @PWM )    = createDistanceMatrix( $upFile );
   my ( $dmDown, undef ) = createDistanceMatrix( $downFile );

   # calculate distance difference matrix

   my $ddm = $dmUp->subtract($dmDown);
   my ($m, $n) = $ddm->size;
 
   if( $VERBOSITY >= $V_GOSSIP ) {

      print STDERR "runDDM: ddm->print:\n";
      $ddm->print;
      print STDERR "\n";
   }

   # calculate the trend - column sums of the distance difference matrix
   #
   my @trends = ();
   my $trends = $ddm->columnSums();

   if( $VERBOSITY >= $V_GOSSIP ) {

      print STDERR "runDDM: trends->print:\n";
      $trends->print;
      print STDERR "\n";
   }

   my ($r, $c) = $trends->size;
   $c -= 1;

   for my $i (0..$c) {

      push( @trends, $trends->[0]->[$i] );
   }

   my %trendsHash = ();

   for ( my $i = 0 ; $i <= $#PWM ; $i++ ) {

      $trendsHash{ $PWM[ $i ] } = $trends[ $i ];
   }

   my @mdsResults = runMDS( $ddm, \@PWM, $m, $n );
   chomp(@mdsResults);

   open(OUT,">$resultFile") || die "can't create file $resultFile\n";
   my @origin2d = (0.0, 0.0);

   foreach (@mdsResults) {

      (my $pwmId, my $x2, my $y2) = split(/\t/);
      $pwmId =~ s/"//g;

      my @mdsPoint = ($x2, $y2);
      my $dist2Origin = dist2d(\@origin2d, \@mdsPoint);
      my $slope = slope( \@origin2d, \@mdsPoint);
      my $trend = $trendsHash{ $pwmId };

      print OUT "$pwmId\t$x2\t$y2\t$dist2Origin\t$slope\t$trend\n"; 
   }
   close(OUT);

   unlink $upFile, $downFile if $unlink;

}

################################################################################
#
# runMDS (wrapper for Kleiwegs' 'mds' program)
#

sub runMDS {
   my ($matrixFile, $PWMRef, $m, $n) = @_;

   my ( $th, $convertedFile ) = tempfile(
      sprintf( 'runMDS_%d_x_%d_XXXXXXXXXXXXXXXX', $m, $n),
      DIR    => '/tmp',
      SUFFIX => '.converted',
      UNLINK => 1,
   );
   my $i;
   my $j;
   print $th "$n\n";
   for ($i = 0; $i < $n; $i++) {
      print $th $PWMRef->[$i],"\n";
   }
   for ($i = 1; $i < $n; $i++) {
      for ($j = 0; $j < $i; $j++)  {
         print $th $matrixFile->[$i]->[$j],"\n";
      }
   }

   close( $th );

   # run the mds program and store result
   ( $th, my $resultFile ) = tempfile( 
      sprintf( 'runMDS_%d_x_%d_XXXXXXXXXXXXXXXX', $m, $n),
      DIR    => '/tmp',
      SUFFIX => '.res',
      UNLINK => 1,
   );

   my $mds_cmd = sprintf( 'timeout 5 %s/mds -o %s 2 %s 2>&1',
      $FindBin::RealBin,
      $resultFile,
      $convertedFile
   );

   llog( sprintf('MDS command : %s', $mds_cmd) , $V_DEBUG);
   my $mds_stdout = qx/$mds_cmd/;
   print STDERR "mds printed: $mds_stdout\n" if $VERBOSITY >= $V_DEBUG;

   # adjust the output format for easier parsing...
   my $vec2tab_cmd = sprintf( '%s/vec2tab %s',
      $FindBin::RealBin,
      $resultFile
   );

   return qx/$vec2tab_cmd/;
}

################################################################################
#
# createDistanceMatrix
#

sub createDistanceMatrix {
   my ($matrixFile) = shift;
   my ($m, $n) = (); # to store matrix dimensions: 'm x n'

   llog( sprintf('createDistanceMatrix: $matrixFile: %s', $matrixFile), $V_DEBUG);

   my @td_Up = read2DMatrixFromFile($matrixFile);
   my $up = new Math::Matrix( @td_Up );
   my $lidx = $#{ $up->[0] };

   # get the names of the PWMs, omit the first ( = 'REFSEQ')...
   my @pwm =  @{$up->[0]}[1..$lidx]; 
   #my @tfbs = @{ $up->[0] }[1..$#{ $up->[0] }]; 
   #print "@tfbs\n" if ($DEBUG);

   # get the 'up' peak regions, omit the first (= 'REFSEQ')...
   # we do not really need this...so comment out
   # my @upRegios = ();
   # foreach my $i (1..$#{$up}) {
   #        push @upRegios, $up->[$i][0];
   #       }
   # print "@upRegios\n" if ($DEBUG);

   # remove colnames (row 0) and rownames (column 0)
   $up = $up->adjustMatrixforDDM;

   ($m, $n) = $up->size;

   if( $VERBOSITY >= $V_GOSSIP ) {

      print STDERR "createDistanceMatrix: Up matrix: $m x $n:\n";
      $up->print;
      print STDERR "\n"
   }

   # transpose
   my $tUp = $up->transpose;
   # get dimensions of transposed matrix
   ($m, $n) = $tUp->size;

   my @upArray = @{ $tUp };
   my $dm = Algorithm::DistanceMatrix->new( metric=>\&euclidean, objects=>\@upArray, mode=>"full" );
   my $distmatrix =  $dm->distancematrix;

   my $dmUp = new Math::Matrix( @{$distmatrix} );

   # normalize
   my $factor = 1.0/sqrt($n);
   $dmUp = $dmUp->multiply_scalar($factor);

   if( $VERBOSITY >= $V_GOSSIP ) {

      print STDERR "createDistanceMatrix: dmUp->print:\n";
      $dmUp->print;
      print STDERR "\n";
   }

   return( $dmUp, @pwm );
}

################################################################################
#
# print2DMatrixRef
#

sub print2DMatrixRef {
   my $dm = shift;
   my $out = "";
   for my $row (@{$dm}) {
      for my $col (@{$row}) {
         $out = $out . sprintf "%10.5f ", $col;
      }
      $out = $out . sprintf "\n";
   }
   print $out;
}

################################################################################
#
# euclidean distance 
#

sub euclidean  {
   my ( $x, $y ) = @_;
   my $v = 0.0;
   for ( my $i = 0 ; $i < $#{$x} ; $i++ ) {
      $v += ( $x->[$i] - $y->[$i] ) * ( $x->[$i] - $y->[$i] );
   }
   return ( sqrt($v) );
}

################################################################################
#
# read2DMatrixFromFile
#

sub read2DMatrixFromFile {
   my ($file) = shift;

   open(FILE, $file) or die "Cannot open $file: $!";
   # A 2D array is an array of references to anonymous arrays
   my @td_array = map [ split ], <FILE>;
   close(FILE);
   return @td_array;
}

################################################################################
#
# Log
#

sub llog {

   my $msg = shift;
   my $level = shift;
   plog( sprintf( 'DDM.pm: %s', $msg), $level);
}

################################################################################

1;

################################################################################
