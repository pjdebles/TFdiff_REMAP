#!/usr/bin/perl 
use strict;
use warnings;

my $DEBUG  = 0;

@ARGV == 1 or die "usage: $0 network_file (from beta2network.pl)\n";
my ($networkFile) = @ARGV;

my %HoA = readData2HoA( $networkFile );

if ( $DEBUG ) {
     use Data::Dumper;
     print Dumper \%HoA;
   }

my @tfList = ();
foreach my $key (sort keys %HoA) {
    print "$key\t@{ $HoA{ $key } }\n" if $DEBUG;
    push( @tfList, @{ $HoA{ $key } });
}

# get the array of regulatory tfs
@tfList = uniq( sort @tfList );
my %tf2Index = matrixIDs2Hash(@tfList);

# column names to output
print "GENE","\t",join("\t",@tfList),"\n";

my @vector = ();
foreach my $gene ( keys %HoA ) {
        @vector = (0) x scalar(@tfList);
        foreach my $tf ( @{ $HoA{ $gene } } ) {
                $vector[ $tf2Index{ $tf } ]++;
                }
        print $gene,"\t",join("\t",@vector),"\n";
}

#########################################################################################################
#
# matrixIDs2Hash

sub matrixIDs2Hash {
    my (@array) = @_;
    my %matrixIDsHash = ();

    my $i;
    for ( $i = 0 ; $i <= $#array ; $i++ ) {
        $matrixIDsHash{ $array[$i] } = $i;
    }

    return (%matrixIDsHash);
}

#########################################################################################################
#
# uniq

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

#########################################################################################################
#
# readData2HoA

sub readData2HoA {
    my ($file) = shift;
    my %HoA = ();

    open( INFILE, $file );
    while (<INFILE>) {
        chomp();
        next if /^#/;
        my ($tf, $interaction, $gene) = split( /\t/ );
        push @{ $HoA{ $gene } }, $tf;
    }
    close(INFILE);
    return %HoA;
}
