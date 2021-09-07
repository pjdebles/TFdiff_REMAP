#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  example.pl
#
#        USAGE:  perl example.pl
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
#      CREATED:  2014-12-12 Fri 23:26:52
#     REVISION:  
# ============================================================================ #

use strict;
use warnings;

use FindBin;
use lib $FindBin::RealBin;
use Logger;
use Getopt::Long;

my $LEVEL = 'log';

my $result = GetOptions (
   'level|l=s' => \$LEVEL,
);


my $Logger = Logger->new( sub {

   my %config = @_;

   printf STDERR ( "%6s : %s\n",
      uc( $config{level} ),
      sprintf( $config{msg}, @{$config{args}} )
   );
}, $LEVEL );

$Logger->error  ( 'This is %s'               , 'error'  ) ;
$Logger->warn   ( 'This is %s'               , 'warn'   ) ;
$Logger->log    ( 'This is %s'               , 'log'    ) ;
$Logger->log    ( 'This is log without args'            ) ;
$Logger->gossip ( 'This is %s'               , 'gossip' ) ;
$Logger->debug  ( 'This is %s'               , 'debug'  ) ;
