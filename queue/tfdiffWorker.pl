#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  bdstat.pl
#
#        USAGE:  perl bdstat.pl
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
#      CREATED:  2014-11-17 Mon 15:38:37
#     REVISION:  
# ============================================================================ #

use strict;
use warnings;

use Beanstalk::Client;
use Capture::Tiny qw( capture );
use Config::IniFiles;
use Cwd qw/abs_path realpath/;
use Data::Dumper;
use File::Basename;
use FindBin;
use Getopt::Long;
use JSON::XS;
use POSIX qw(strftime);
use Time::HiRes;
use Try::Tiny;
use Pod::Usage;

use lib dirname( $FindBin::RealBin );
use queue::JobFacade;
use lib::Logger::Logger;


# ============================================================================ #
# Setup

our $POD_FILE     = sprintf( '%s/tfdiffWorker.pod', $FindBin::RealBin );
my $CALL_SCRIPT   = abs_path( sprintf( '%s/../scripts/ddmTyrant.pl', $FindBin::RealBin ) );
my $DEF_CONF_FILE = sprintf( '%s/default-config.ini', $FindBin::RealBin );
my $CONF_FILE     = $DEF_CONF_FILE;

my $DRY_RUN    = 0;
my $START_TIME = time();
my $UQID       = $START_TIME . $$ ;
my $VERBOSITY  = 'log';

# ---------------------------------------------------------------------------- #

my $DEF_INI      = Config::IniFiles->new( -file => $DEF_CONF_FILE );

# ---------------------------------------------------------------------------- #

Getopt::Long::Configure("pass_through");
GetOptions (
   'config|c=s'  => \$CONF_FILE,
   'verbosity|v=s' => \$VERBOSITY,
);
Getopt::Long::Configure("no_pass_through");

my %INI;
tie %INI, 'Config::IniFiles', ( -file => $CONF_FILE, -import => $DEF_INI );

my $Logger = Logger->new( \&logit, $VERBOSITY );

# ----

GetOptions (
   'host|h=s'               => \$INI{queue}{server},
   'port|p=i'               => \$INI{queue}{port},
   'tube|t=s'               => \$INI{queue}{tube},
   'job-root-directory|d=s' => \$INI{job}{root_directory},
   'background-cache-root'  => \$INI{job}{background_cache_root},
   'max-jobs|l=i'           => \$INI{worker}{max_jobs},
   'max-age=i'              => \$INI{worker}{max_age},
   'sleep-on-error=f'       => \$INI{worker}{sleep_on_error},
   'script=s'               => \$CALL_SCRIPT,
   'dry-run|n'              => \$DRY_RUN,
   'help'                   => sub{ help( verbose             => 1) },
   'man'                    => sub{ help( verbose             => 2) },

);

# ---------------------------------------------------------------------------- #

help( msg => sprintf(
      'Unable to determine abs_path of job.root_directory: `%s` -- %s',
      $INI{job}{root_directory},
      $!
) ) if ( ! abs_path( $INI{job}{root_directory} ) );

$INI{job}{root_directory} = abs_path( $INI{job}{root_directory} );
$INI{job}{root_directory} =~ s/\/*$//;

# ----

$CALL_SCRIPT = abs_path( $CALL_SCRIPT );

if( !-f $CALL_SCRIPT || !-x $CALL_SCRIPT ) {

   help( msg => sprintf( 
         'Specified script-file doesn\'t exist or  isn\'t execuatble: %s',
         $CALL_SCRIPT
   ) );
}

# ---

$Logger->log( "Starting worker with PID           : %d", $$ );
$Logger->log( "Starting worker with UNIQ ID       : %d", $UQID );
$Logger->log( "Starting worker with JOBS ROOT DIR : %s", $INI{job}{root_directory});
{
   local $Data::Dumper::Terse = 1;
   local $Data::Dumper::Pad = '    ';
   $Logger->gossip(
      "Starting worker with INI         : \n%s", Dumper( \%INI )
   );
}

# ============================================================================ #
# Connect

my $BdHandle = Beanstalk::Client->new({
   'server' => sprintf( '%s:%d',
      $INI{'queue'}{'server'},
      $INI{'queue'}{'port'}
   ),
   'default_tube' => $INI{'queue'}{'tube'},
});

# ============================================================================ #
# Loop

my $counter = 0;

while( $counter < scalar $INI{worker}{max_jobs} ) {

   print STDERR "\n";
   ## ------------------------------------------------------------------------- #
   ## Setup

   guard_lifetime();
   $counter++;

   $Logger->log( "Starting LOOP: %d", $counter );

   my $Job;
   try{

      $Job = JobFacade->new(
         config      => $INI{job},
         statuses    => $INI{jobstatuses},
         worker      => $INI{worker},
         BdHandle    => $BdHandle,
         Logger      => $Logger,
         call_script => $CALL_SCRIPT,
         dry_run     => $DRY_RUN
      );
      $Job->process();
   } catch{

      $Logger->error( 'caught error: %s', $_ );
      sleep 5
   };
}

print STDERR "\n";
$Logger->log('DIE : Maximum number runs (max-job) reached: %d', $counter );

sub my_next {

   print "Hello, I'm going to advance you...\n";
   next;
}

# ============================================================================ #
# Subs
# ============================================================================ #

# ============================================================================ #
# Guard lifetime

sub guard_lifetime {

   return if $INI{worker}{max_age} == 0;
   if( ( time() - $START_TIME ) > $INI{worker}{max_age} ) {

      $Logger->log('DIE : Maximum age (%ds) reached: %ds',
         $INI{worker}{max_age},
         (time() - $START_TIME)
      );
      exit;
   }
}

# ============================================================================ #
# Log msg to STDERR

sub logit {

   my %config = @_;

   print STDERR sprintf(
      " [%s] : %6s : %s\n",
      strftime( ' %Y-%m-%d %H:%M:%S ', localtime ),
      uc( $config{level} ),
      sprintf( $config{msg}, @{$config{args}} )
   ) ;
}


# ============================================================================ #
# job to job_dir

# ============================================================================ #
# fmt_hash

sub fmt_hash {

   my $href = shift;
   my $spacer = shift || 10;
   my $prefx = shift || '';
   my @output;

   foreach my $key ( sort( keys %{ $href } ) ) {

      push( 
         @output,
         sprintf("$prefx%-".$spacer."s: %s", $key, $href->{$key} )
      );
   }
   return join( "\n", @output);
}

################################################################################
#
# Notify

sub notify {

   my $public_msg = shift;
   my $private_msg = shift || $public_msg;

   # TODO
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
