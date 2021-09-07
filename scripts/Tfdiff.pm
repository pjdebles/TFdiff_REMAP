#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  common.pm
#
#        USAGE:  require 'common.pm'
#
#  DESCRIPTION:  Bundle common functionality in single include...
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Soete Arne (arne.soete@irc.vib-ugent.be)
#      COMPANY:  VIB-UGent
#      VERSION:  0.1
#      CREATED:  2014-10-27 Mon 17:11:26
#     REVISION:  
# ============================================================================ #

package Tfdiff;

use strict;
use warnings;

use FindBin;
use POSIX qw(strftime);
use Exporter 'import';
use File::Path;
use Pod::Usage;
use Capture::Tiny qw/capture/;

our @EXPORT = qw(

   $DATADIR
   $DRY_RUN
   $OUTDIR
   $POD_FILE
   $VERBOSITY
   $V_DEBUG
   $V_RUN
   $V_NORMAL
   $V_SILENT
   $V_VERBOSE
   $V_GOSSIP

   call
   createOutdir
   dataname2path
   help
   outfile2path
   plog
   pod2path
   readFile
   script2path
); 

our $V_SILENT  = 0;
our $V_NORMAL  = 1;
our $V_RUN     = 2;
our $V_VERBOSE = 3;
our $V_DEBUG   = 4;
our $V_GOSSIP  = 5;

our $DRY_RUN   = 0;
our $VERBOSITY = $V_NORMAL;

our $DATADIR;
our $OUTDIR;
our $POD_FILE;
our $DOCSDIR = sprintf( '%s/../docs', $FindBin::RealBin );

################################################################################
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

################################################################################
#
# Create Outdir

sub createOutdir {

   my $dupcounter=1;
   my $date = `date +%F`; chomp($date);
   my $time = `date +%T`; chomp($time);
   my $stampcore = $date."_".$time."_";
   my $stamp = $stampcore.$dupcounter;
   my $resultsDir = "./$stamp";
   while(-d $resultsDir) {
           $dupcounter++;
           $stamp = $stampcore.$dupcounter;
           $resultsDir = "./$stamp";
        }

   if (! -d $resultsDir) {

     mkpath($resultsDir) or die "Failed to create $resultsDir: $!\n";
   }
   
   return $resultsDir;
}

################################################################################
#
# Log msg to STDERR

sub plog {

   my $msg = shift;
   my $when = shift || $V_NORMAL;

   print STDERR sprintf(
      " [%s] %s: %s\n",
      strftime( ' %Y-%m-%d %H:%M:%S ', localtime ),
      $FindBin::Script,
      $msg
   ) if( $VERBOSITY >= $when );
}

################################################################################
#
# Print Help

sub help {

   my %pod2usage_conf = @_ ;
   my %additional_conf = ( input => $POD_FILE );

   %pod2usage_conf = ( %pod2usage_conf, %additional_conf );

   pod2usage( \%pod2usage_conf );
}

################################################################################
#
# data filename to filepath

sub dataname2path {

   my $filename = shift;

   return sprintf( '%s/%s', $DATADIR, $filename );
}

################################################################################
#
# script filename to filepath

sub script2path {

   my $filename = shift;

   return sprintf( '%s/%s', $FindBin::RealBin, $filename );
}

################################################################################
#
# script filename to filepath

sub outfile2path {

   my $filename = shift;

   return sprintf( '%s/%s', $OUTDIR, $filename );
}

################################################################################
#
# Podfilename to path

sub pod2path {

   my $filename = shift;

   return sprintf( '%s/%s', $DOCSDIR, $filename );
}

################################################################################
#
# Call Subscript

sub call_old {

   my $cmd = shift;
   my $log_level = shift || $V_RUN;

   plog( sprintf( 'RUN %s', $cmd ), $log_level );

   return qx|$cmd| unless $DRY_RUN;
}

sub call{

   my $cmd = shift;
   my $log_level = shift || $V_RUN;

   plog( sprintf( 'RUN %s', $cmd ), $log_level );

   return 0 if $DRY_RUN;

   my ( $stdout, $stderr, $exitcode ) = capture {
      
      system( $cmd );
   };

   if( $exitcode == 0 ) {

      return $stdout;
   }

   die( $stderr );

}

################################################################################

 1;
