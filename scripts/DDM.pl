#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  DDM.pl
#
#        USAGE:  ./DDM.pl  
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
use FindBin;
use Getopt::Long;

use lib $FindBin::RealBin;
use Tfdiff;
use DDM;

# ----

#
# Defined in Tfdiff.pm
#   $V_SILENT $V_NORMAL $V_DEBUG $DRY_RUN $VERBOSITY $DATADIR $OUTDIR $POD_FILE
#   $DOCSDIR

$POD_FILE = pod2path( 'DDM.pod' );
$DDM::DEBUG = 0;

# ----

my $result = GetOptions (
   'help'            => sub{ help( verbose => 1) },
   'man'             => sub{ help( verbose => 2) },
   'debug'           => sub{ $VERBOSITY = $V_DEBUG; $DDM::DEBUG = 1 },
   'silent'          => sub{ $VERBOSITY = $V_SILENT },
   'set-verbosity=i' => \$VERBOSITY, # use onlu from other script that share Tfdiff
   'n|dry-run'       => \$DRY_RUN,
);

# ----

help() if @ARGV != 3;

# ----

my ($upFile, $downFile, $resultFile) = @ARGV;

plog( sprintf( '$upFile     : %s' , $upFile ), $V_VERBOSE );
plog( sprintf( '$downFile   : %s' , $downFile ), $V_VERBOSE );
plog( sprintf( '$resultFile : %s' , $resultFile ), $V_VERBOSE );

$DDM::VERBOSITY = $VERBOSITY;

# ----

runDDM( $upFile, $downFile, $resultFile );
