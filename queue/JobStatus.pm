#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  JobStatus.pm
#
#        USAGE:  use JobStatus
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
#      CREATED:  2014-12-16 Tue 09:36:22
#     REVISION:  
# ============================================================================ #

use strict;
use warnings;

package JobStatus;

use JSON::XS;
use Data::Dumper;

my $JSON_WRITER = JSON::XS->new->ascii->pretty->allow_nonref;

sub new {

   my $class = shift;
   my $file = shift;

   my $self = {};

   bless( $self, $class );

   $self->{'file'} = $file;
   $self->loadStatus;

   return $self;
}

# ============================================================================ #

sub set_status {

   my $self = shift;
   my $status = shift;

   $self->{state}->{'status'} = $status;
   
   $self->saveStatus;
}

# ============================================================================ #

sub set_msg {

   my $self = shift;
   my $msg = shift;

   $self->{state}->{msg} = $msg;
   $self->saveStatus;
}

# ============================================================================ #
sub loadStatus {

   my $self = shift;

   local $/ = undef;
   open( my $fh, '<', $self->{file} ) || die( sprintf(
      'Unable to open status_file for reading: `%s` -- %s',
      $self->{file},
      $!
   ) );
   my $json = <$fh>;
   close( $fh);

   return $self->{state} = decode_json( $json );
}

# ============================================================================ #

sub saveStatus {

   my $self = shift;

   open( my $fh, '>', $self->{file} ) || die( sprintf(
      'Unable to open status_file for writing: `%s` -- %s',
      $self->{file},
      $!
   ) );
   print $fh $JSON_WRITER->encode( $self->{state} );
   close( $fh);
}
