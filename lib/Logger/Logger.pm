#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  logger.pm
#
#        USAGE:  use logger
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
#      CREATED:  2014-12-12 Fri 23:27:50
#     REVISION:  
# ============================================================================ #

use strict;
use warnings;

package Logger;
use Exporter 'import';
use Data::Dumper;
use Scalar::Util qw( looks_like_number );

our @EXPORT = qw(

   $ERROR
   $WARN
   $LOG
   $GOSSIP
   $DEBUG
);

our $SILENT  = our $ERROR = my $level = 0;
our $QUIET   = ++$level;
our $WARN    = ++$level;
our $LOG     = ++$level;
our $GOSSIP = ++$level;
our $DEBUG   = ++$level;

# ---------------------------------------------------------------------------- #

my %level_lookup = (
   'error'  => $ERROR,
   'warn'   => $WARN,
   'log'    => $LOG,
   'gossip' => $GOSSIP,
   'debug'  => $DEBUG,
);

# ============================================================================ #

sub new {

   my $class = shift;
   my $closure = shift;
   my $level = shift;

   # ----
   
   my $self = {};
   bless( $self, $class );

   $self->{closure}   = $closure;
   $self->setLevel( $level );

   # ----

   return $self;
}

# ============================================================================ #

sub error {

   my $self = shift;

   $self->_generic_log( 'error', @_ )
}

# ============================================================================ #

sub warn {

   my $self = shift;

   $self->_generic_log( 'warn', @_ )
}

# ============================================================================ #

sub log {

   my $self = shift;

   $self->_generic_log( 'log', @_ )
}

# ============================================================================ #

sub gossip {

   my $self = shift;

   $self->_generic_log( 'gossip', @_ )
}

# ============================================================================ #

sub debug {

   my $self = shift;

   $self->_generic_log( 'debug', @_ )
}

# ============================================================================ #

sub _generic_log {

   my $self = shift;
   my $level = shift;
   my $msg  = shift;
   my $when = $self->normalize_level( $level );
   my @data = @_;

   if( $when <= $self->{log_level} ) {

      return $self->{closure}->(
         msg => $msg,
         args => \@_,
         level => $level,
         when => $when
      );
   }
}

# ============================================================================ #

sub setLevel {

   my $self = shift;
   my $new_level = shift;

   $self->{log_level} = $self->normalize_level( $new_level );

}

# ============================================================================ #

sub normalize_level {

   my $self = shift;
   my $level = shift;

   if( looks_like_number( $level ) ) {

      return $level;
   }

   return $level_lookup{ lc( $level) };
}



# ============================================================================ #
1;
# ============================================================================ #
