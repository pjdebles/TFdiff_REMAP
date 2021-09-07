#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  job.pm
#
#        USAGE:  use job;
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
#      CREATED:  2014-12-12 Fri 15:46:56
#     REVISION:  
# ============================================================================ #

use strict;
use warnings;

package JobFacade;
use Capture::Tiny qw( capture );
use Data::Dumper;
use FindBin;
use JSON::XS;
use Try::Tiny;

use lib $FindBin::RealBin;
use JobStatus;

#$Capture::Tiny::TIMEOUT = 0;

$Data::Dumper::Terse = 1;
$Data::Dumper::Pad = '    ';

my $True = 1;
my $False = undef;

sub new
{
   my $class = shift;
   my %config = @_;

   # ----

   my $self = {};
   bless( $self, $class );

   # ----

   %{$self} = %config;
   $self->should_sleep(undef);
   $self->error(undef);

   # ----

   $self->{Logger}->gossip('JOB CONFIG: %s', Dumper( $self->{config} ) );

   # ----

   if( ! -f $self->{call_script} ) {
      $self->throw('Unable to find `call_script`: %s', $self->{call_script});
   }

   # ----
   
   return $self;
}

# ============================================================================ #

sub process {

   my $self = shift;

   $self->{Logger}->warn( 'Running in DRY_RUN mode!' ) if $self->{dry_run};

   ## Reserve
   $self->reserve;
   $self->save_status('processing');

   # Prepare
      
   my $cmd = sprintf(
      'perl %s %s %s --bg-runs %d --bg-cachedir %s --randomLines=%s --pval-cutoff %d --outdir %s -v ',
      $self->{call_script},
      $self->file( $self->{config}{up_list_filename} ),
      $self->file( $self->{config}{down_list_filename} ),
      $self->get_background_runs,
      $self->get_bg_cachedir,
      $self->get_random_lines,
      $self->get_pval_cutoff,
      $self->extrapolate_path( $self->{config}{output_dirname} ),
   );

   # Execute

   $self->{Logger}->warn( 'CALL : %s', $cmd );

   my ($stdout, $stderr, $exitcode) = capture {

      system( $cmd ) if !$self->{dry_run};
   };

   $stdout =~ s/\n/\n    /g;
   $stderr =~ s/\n/\n    /g;
   $exitcode = $exitcode >> 8;

   $self->{Logger}->debug('RUN-EXITCODE: %s' , $exitcode );
   $self->{Logger}->debug('RUN-STDOUT : %s'  , $stdout   );
   $self->{Logger}->debug('RUN-STDERR : %s'  , $stderr   );

   if( $exitcode != 0 ) {

      $self->throw( 
         'Unexpected error occured during job-processing: %s',
         sprintf(
            "CMD: %s \nEXITCODE: %d \nSTDOUT: %s \nSTDERR: %s" ,
            $cmd, $exitcode, $stdout, $stderr
         )
      );
   }
   
   # Release

   $self->release;
   $self->save_status('success');
   return $True;
}

# ============================================================================ #

sub throw {

   my $self    = shift;
   my $msg_tpl = shift;
   my $msg     = sprintf( $msg_tpl, @_ );

   $self->save_status('failed') if $self->{JobStatus};
   $self->save_msg( $msg ) if $self->{JobStatus};
   $self->error( $msg );
   $self->release;
   die( $msg );
}

# ============================================================================ #

sub error {

   my $self = shift;
   my $msg = shift;

   if( defined $msg ) {

      $self->{error} = $msg;
   }

   return $self->{error};
}

# ============================================================================ #

sub should_sleep {

   my $self = shift;
   my $interval = shift;
   
   if( defined $interval ) { $self->{sleep} = $interval }

   return $self->{sleep};
}

# ============================================================================ #
# Facade methods + dependencies
# ============================================================================ #

sub reserve {

   my $self = shift;

   $self->{job} = ( !$self->{dry_run} )
      ? $self->{BdHandle}->reserve
      : $self->{BdHandle}->peek_ready;

   if( ! $self->{job} ) {

      if( $self->{BdHandle}->error eq "NOT_FOUND" ) {
         $self->{Logger}->warn('NO JOBS (peek) ready' );
      }
      $self->throw( $self->{BdHandle}->error );
      $self->should_sleep( $True );
   }

   $self->{Logger}->log('RESERVED JOB: id: %d', $self->{job}->id );
   $self->{Logger}->debug( 'JOB STATS: %s', Dumper( $self->{job}->stats ) );

   $self->decode_data();
   $self->post_reserve();

   return $self->{job};
}

# ============================================================================ #

sub decode_data {

   my $self = shift;

   $self->{data} = decode_json( $self->{job}->data );
   $self->{Logger}->debug(
      'Decoded DATA (HashRef) : %s',
      Dumper($self->{data})
   );

   return $self->{data};
}

# ============================================================================ #

sub post_reserve {

   my $self = shift;
   my $root = $self->{config}{root_directory};
   $root =~ s/\/*$//;

   $self->set_working_dir( sprintf( '%s/%s', $root, $self->{data}{dirname} ) );

   $self->{Logger}->gossip(
      'Set WORKING DIRECTORY to %s',
      $self->get_working_dir
   );

   $self->{JobStatus} = JobStatus->new(
      $self->file( $self->{config}{status_filename} )
   );

   return $True;
}

# ============================================================================ #

sub release {

   my $self = shift;

   return $True if ! defined $self->{job};

   # ---

   my $stats = $self->{job}->stats;

   if( $stats->releases > $self->{config}{max_releases} ) {

      $self->{job}->bury
   }

   if( $self->{dry_run } || $self->error ) {

      $self->{job}->release;
   }
   else {

      $self->{job}->delete;
   }
}

# ============================================================================ #
# ============================================================================ #

sub save_status {

   my $self = shift;
   my $status = shift;

   return if $self->{DRY_RUN};

   $self->{Logger}->gossip( 'Save STATUS: %s', Dumper( $status ) );

   $self->{JobStatus}->set_status(
      $self->{statuses}{$status}
   );
}

# ============================================================================ #

sub save_msg {

   my $self = shift;
   my $msg = shift;

   return if $self->{DRY_RUN};

   $self->{JobStatus}->set_msg(
      $self->{statuses}{$msg}
   );
}

# ============================================================================ #
sub set_working_dir {

   my $self = shift;
   my $working_dir = shift;

   if( !-d $working_dir ) {

      $self->throw( 
         'Unable to set working directory: %s -- %s', $working_dir, $! 
      );
   }

   return $self->{working_dir} = $working_dir;
}

# ============================================================================ #

sub get_working_dir {

   my $self = shift;
   return $self->{working_dir};
}

# ============================================================================ #

sub extrapolate_path {

   my $self = shift;
   my $path = shift;

   return sprintf( '%s/%s', $self->{working_dir}, $path );
}

# ============================================================================ #

sub file {

   my $self = shift;
   my $file = shift;
   $file =~ s/^\/*//g;
   $file =~ s/\/*$//g;
 
   my $extrapolated_file = $self->extrapolate_path( $file );

   if( ! -f $extrapolated_file || -z $extrapolated_file  ) {

      return $self->throw( "Error extrapolating file: %s -- %s (%s)",
         $file, $!, $extrapolated_file
      );
   }

   return $extrapolated_file;
}

# ============================================================================ #

sub get_bg_cachedir {

   my $self = shift;

   return undef if( ! $self->{config}{background_cache_root} );

   my $bg_cachedir = sprintf( '%s/%d',
      $self->{config}{background_cache_root},
      $self->get_background_runs
   );

   if( !-d $bg_cachedir ) {

      $self->throw('Unable to find bg_cachedir: `%s` -- %s', $bg_cachedir, $! );
   }

   return $bg_cachedir;
}

# ============================================================================ #

sub get_random_lines {


   my $self = shift;
   my $randLines = $self->{worker}->{randomLines};

   if( !$randLines ) {

      $self->throw('Error determening exec: randomLines: `%s`', $randLines);
   }

   return $randLines;
}

# ============================================================================ #

sub get_background_runs {


   my $self = shift;
   my $runs = $self->{data}->{bg_runs};

   if( !$runs ) {

      $self->throw('Error determening number of background-runs: `%s`', $runs);
   }

   return $runs;
}

# ============================================================================ #

sub get_pval_cutoff{


   my $self = shift;
   my $p_cutoff = $self->{data}->{p_cutoff};

   if( !$p_cutoff ) {

      $self->throw('Error determening pval-cutoff: `%s`', $p_cutoff);
   }

   return $p_cutoff;
}

# ============================================================================ #
1;
# ============================================================================ #
