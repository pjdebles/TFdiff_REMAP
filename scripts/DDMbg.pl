#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  DDMbg.pl
#
#        USAGE:  ./DDMbg.pl  
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
#      CREATED:  06/22/2011 02:26:53 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Algorithm::DistanceMatrix;
use CAD::Calc qw( slope dist2d);
use File::Temp qw/ tempfile /;
use FindBin;
use Getopt::Long;
use Proc::Simple;

use lib $FindBin::RealBin;
use Tfdiff;
use DDM;

# ----

#
# Defined in Tfdiff.pm
#   $V_SILENT $V_NORMAL $V_DEBUG $DRY_RUN $VERBOSITY $DATADIR $OUTDIR $POD_FILE
#   $DOCSDIR

$POD_FILE   = pod2path( 'DDMbg.pod' );
$DDM::DEBUG = 0;
my $CPUS    = `nproc`; chomp $CPUS;
$OUTDIR = '.';
my $UNLINK = 0;
my $RAND_LINES = 'randomLines';

# ----

my $result = GetOptions (
   'cpu|j=i'         => \$CPUS,
   'debug'           => sub{ $VERBOSITY = $V_DEBUG; $DDM::DEBUG = 1 },
   'dry-run|n'       => \$DRY_RUN,
   'help'            => sub{ help( verbose => 1) },
   'man'             => sub{ help( verbose => 2) },
   'outdir|o=s'      => \$OUTDIR,
   'randomLines|r=s' => \$RAND_LINES,
   'set-verbosity=i' => \$VERBOSITY, # use ony from other scipts that share Tdiff
   'silent'          => sub{ $VERBOSITY = $V_SILENT },
   'unlink-up-down|u'=> \$UNLINK,
);

mkdir $OUTDIR if( !-d $OUTDIR );

# ----

help() if( @ARGV != 4 );

# ----

my ($backgroundFile, $numberTries, $sizeUp, $sizeDown) = @ARGV;

plog( sprintf( '$backgroundFile : %s', $backgroundFile ), $V_VERBOSE );
plog( sprintf( '$numberTries    : %s', $numberTries ), $V_VERBOSE );
plog( sprintf( '$sizeUp         : %s', $sizeUp ), $V_VERBOSE );
plog( sprintf( '$sizeDown       : %s', $sizeDown ), $V_VERBOSE );

my $try;
my @numberTries = (1..$numberTries);
my $bg1;
my $bg2;

# ----

# save the first line with the column names
my $firstLine = `head -n 1 $backgroundFile`;
plog( sprintf('Headers: %s', $firstLine), $V_DEBUG );

my $backgroundFileNoFirstLine = outfile2path( "null_no_first.csv" );
plog( sprintf(
   'backgroundFileNoFirstLine file path: "%s"',
   $backgroundFileNoFirstLine), 
$V_DEBUG );

# delete first line from backgroundSet file (contains column names)
my $sed_string = "1 d";
call(
   "sed '$sed_string' $backgroundFile > $backgroundFileNoFirstLine",
   $V_DEBUG
);

# ---------------------------------------------------------------------------- #
#
# start parallellization
#

$| = 1;     # debuffer output
my $max_parallel_jobs = $CPUS;     # jobs processed in parallel
my @running = ();    # array of running jobs

while ( $#numberTries >= 0 || $#running >= 0 ) {

   @running = grep { $_->poll() } @running;    # remove finished jobs

   if ( $#running + 1 < $max_parallel_jobs && defined( $try = pop(@numberTries) ) ) { # space free in running?

      ($bg1, $bg2) = generateBackgroundSets(
         $backgroundFileNoFirstLine,
         $firstLine,
         $sizeUp,
         $sizeDown,
         $try,
         $numberTries
      );

      my $myProcess = Proc::Simple->new();

#      $myProcess->start( \&runDDMbg, $bg1, $bg2, $try ) || 
#         die "Cannot start processing background run $try!\n";
      $myProcess->start( 
         \&runDDM,
         $bg1,
         $bg2,
         outfile2path( sprintf( 'BG_%d_results.csv', $try ) ),
         $UNLINK
      ) || die "Cannot start processing background run $try!\n";

      push( @running, $myProcess ); # include in running list

      print "STARTED. (Remaining: ", $#numberTries + 1, " Running: ", $#running + 1, ")\n";

      next; # proceed without delay
   }
   sleep(1); # pause ... and proceed
}

################################################################################
#
# generateBackgroundSets
#

sub generateBackgroundSets {

   my ($backgroundFileNoFirstLine, $firstLine, $sizeUp, $sizeDown, $try, $numberTries) = @_;

   my $seed = int(rand($numberTries));
   # generate first background set

   my $bg1 = outfile2path(
      "BG_".$try."_Up_".$sizeUp."_".$sizeDown."_counts.csv"
   );

   call(
      #"randomLines -seed=$seed $backgroundFileNoFirstLine $sizeUp $bg1",
      sprintf( '%s -seed=%d %s %d %s',
         $RAND_LINES,
         $seed,
         $backgroundFileNoFirstLine,
         $sizeUp,
         $bg1
      ),
      $V_DEBUG
   );

   # insert header line back (part 1)
   my $sed_string = "1 i ".$firstLine; 
   call("sed -i '$sed_string' $bg1", $V_DEBUG);

   $seed = int(rand($numberTries)); # shuffle again...

   # generate second background set
   my $bg2 = outfile2path(
      "BG_".$try."_Down_".$sizeUp."_".$sizeDown."_counts.csv"
   );

   call(
      #"randomLines -seed=$seed $backgroundFileNoFirstLine $sizeDown $bg2",
      sprintf( '%s -seed=%d %s %d %s',
         $RAND_LINES,
         $seed,
         $backgroundFileNoFirstLine,
         $sizeDown,
         $bg2
      ),
      $V_DEBUG
   );

   # insert header line back (part 2)
   call( "sed -i '$sed_string' $bg2", $V_DEBUG );

   return($bg1, $bg2);
}
