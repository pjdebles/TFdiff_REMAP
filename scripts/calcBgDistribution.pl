#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  calcBgDistribution.pl
#
#        USAGE:  perl calcBgDistribution.pl [OPTIONS] [ARGUMENTS]
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Soete Arne (arne.soete@irc.vib-ugent.be)
#      COMPANY:  VIB-UGent
#      VERSION:  0.1
#      CREATED:  2014-11-25 Tue 14:01:59
#     REVISION:  
# ============================================================================ #

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;
use Pod::Usage;
use FindBin;

my $POD_FILE = sprintf( '%s/../docs/calcBgDistribution.pod', $FindBin::RealBin );
my $LIST_FILE_SPECIFIED = 0;
my @BG_FILES = ();
my $OUTDIR = '.';

# ============================================================================ #

my $result = GetOptions (
   'infile|f=s' => \&infile_to_list,
   'outdir|o=s' => \$OUTDIR,
);

if( !$LIST_FILE_SPECIFIED ) {

   @BG_FILES = @ARGV;
}

if( @BG_FILES == 0 ) {

   pod2usage(
      input => $POD_FILE,
      msg => 'No list/set of background results defined',
   );
}

# ============================================================================ #

my %bgHash = ();
my %trendHash = ();

# Collect all background results
foreach my $bg (@BG_FILES) {
   # print "--- $bg ---\n";
   open( INFILE, $bg );
   while (<INFILE>) {
      my ($pwmId, $x2, $y2, $dist2Origin, $slope, $trend) = split(/\t/);
      push( @{ $bgHash{$pwmId} }, $dist2Origin);
      push( @{ $trendHash{$pwmId} }, $trend);
   }
}

# ---------------------------------------------------------------------------- #
# Sort distances AND TRENDS ascending...

foreach my $pwm (keys %bgHash) {
   @{ $bgHash{$pwm} } = sort { $a <=> $b } @{ $bgHash{$pwm} };
   @{ $trendHash{$pwm} } = sort { $a <=> $b } @{ $trendHash{$pwm} };
}

# ---------------------------------------------------------------------------- #
# save to file

my $bgHash_file = sprintf( '%s/bgHash.json', $OUTDIR );

open( my $bgHash_FH, '>', $bgHash_file) or die( sprintf(
   'Unable to open file for writing: `%s` -- %s',
   $bgHash_file,
   $!
));

print $bgHash_FH encode_json( \%bgHash );

close( $bgHash_FH);

# ----

my $trendHash_file = sprintf( '%s/trendHash.json', $OUTDIR );

open( my $trendHash_FH, '>', $trendHash_file) or die( sprintf(
   'Unable to open file for writing: `%s` -- %s',
   $trendHash_file,
   $!
));

print $trendHash_FH encode_json( \%trendHash );

close( $trendHash_FH);

# ============================================================================ #
# Subs
# ============================================================================ #

sub infile_to_list {

   my $opt = shift;
   my $file = shift;

   $LIST_FILE_SPECIFIED = 1;

   open( INFILE, $file ) || die( sprintf(
      'Unable to open file for reading: `%s` -- %s',
      $file,
      $!
   ));

   while (<INFILE>) {
      chomp();
      next if /^#/;
      push ( @BG_FILES, $_ );
   }
   close(INFILE);
}


