#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  buildIDRTable.pl
#
#        USAGE:  ./buildIDRTable.pl  
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
#      CREATED:  05/18/2015 05:14:19 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
my $DEBUG = 0;

@ARGV == 3 or die "usage: $0 results_directory file_name column_number (starting from 0) \n";
my ($resultsFolder, $resultsFileName, $colNumber) = @ARGV;

print "colnumber = $colNumber\n" if $DEBUG;

my %IDRTableHash = buildTFHash();

my @resultFiles = `find . -name $resultsFileName`;
chomp( @resultFiles );
print join("\n",@resultFiles),"\n" if $DEBUG;

foreach my $result ( @resultFiles ) {
        processResultFile( $result, \%IDRTableHash, $colNumber );
        }

printHash( %IDRTableHash );


################################################################################
#
# processResultFile
#

sub processResultFile {
    my ( $file, $IDRTableHash, $colNumber ) = @_;

    open( INFILE, $file );
    while (<INFILE>) {
          chomp();
          my @fields = split( /\t/ );
          print "TF: $fields[ 0 ]\tcolnumber: $fields[ $colNumber ]\n" if $DEBUG;
          my $rounded = sprintf( "%.3g", $fields[ $colNumber ] );
          push($IDRTableHash{ $fields[0] }, $rounded);
          }
   close(INFILE);
}

################################################################################
#
# buildTFList
#

sub buildTFList {
    my @tfArray = ();
    while (<DATA>) {
           chomp();
           push( @tfArray, $_ );
          }
return( @tfArray );
}

################################################################################
#
# buildTFHash
#

sub buildTFHash {
    my %tfHash = ();
    while (<DATA>) {
           chomp();
           $tfHash{ $_ } = [];
          }
return( %tfHash );
}

################################################################################
#
# printHash
#

sub printHash {
    my %TempHash = @_;

    my @array = sort { $TempHash{$b} <=> $TempHash{$a} }
    keys %TempHash;
    foreach my $item (@array) {
            my $printString = "$item\t@{$TempHash{$item}}";
            $printString =~ s/\s/\t/g;
            print $printString,"\n";
          }
}


__DATA__
AFF4
AHR
AR
ARID3A
ARNT
ATF1
ATF2
ATF3
ATRX
BACH1
BATF
BCL11A
BCL3
BCL6
BCLAF1
BCOR
BDP1
BHLHE40
BRCA1
BRD2
BRD3
BRD4
BRF1
BRF2
CBFB
CBX3
CCNT2
CDK8
CDK9
CDX2
CEBPA
CEBPB
CEBPD
CHD1
CHD2
CREB1
CTBP2
CTCF
CTCFL
CTNNB1
DCP1A
E2F1
E2F4
E2F6
E2F7
EBF1
EGR1
ELF1
ELF5
ELK1
ELK4
ELL2
EOMES
ERG
ESR1
ESR2
ESRRA
ETS1
ETV1
EZH2
FAM48A
FLI1
FOS
FOSL1
FOSL2
FOXA1
FOXA2
FOXH1
FOXM1
FOXP1
FOXP2
GABPA
GATA1
GATA2
GATA3
GATA6
GATAD1
GPS2
GREB1
GTF2B
GTF2F1
GTF3C2
HDAC1
HDAC2
HDAC6
HDAC8
HMGN3
HNF4A
HNF4G
HSF1
IKZF1
IRF1
IRF3
IRF4
JUN
JUNB
JUND
KDM5A
KDM5B
KLF4
MAFF
MAFK
MAX
MAZ
MBD4
MED12
MEF2A
MEF2C
MEIS1
MTA3
MXI1
MYBL2
MYC
NANOG
NCOA1
NCOR1
NCOR2
NELFE
NF1C
NFATC1
NFE2
NFKB1
NFYA
NFYB
NIPBL
NKX2-1
NKX3-1
NOTCH1
NR2C2
NR2F2
NR3C1
NR3C3
NRF1
ONECUT1
ORC1
PAX5
PBX3
PHF8
PML
POU2F2
POU5F1
PPARG
PPARGC1A
PRAME
PRDM1
PRDM14
RAC3
RAD21
RB1
RBBP5
RBPJ
RCOR1
RELA
REST
RFX5
RNF2
RPC155
RUNX1
RUNX1+3
RUNX1T1
RUNX2
RUNX3
RXRA
SAP30
SETDB1
SFMBT1
SIN3A
SIRT6
SIX5
SMAD1
SMAD2+3
SMAD3
SMAD4
SMARCA4
SMARCB1
SMARCC1
SMARCC2
SMC1A
SMC3
SMC4
SNAPC1
SNAPC4
SNAPC5
SOX2
SP1
SP2
SP4
SPI1
SREBP1
SRF
STAG1
STAT1
STAT2
STAT3
STAT4
STAT5A
STAT5B
SUZ12
TAF1
TAF2
TAF3
TAF7
TAL1
TAp73a
TAp73b
TBL1
TBL1XR1
TBP
TCF12
TCF3
TCF4
TCF7L2
TEAD4
TFAP2A
TFAP2C
TFAP4
THAP1
TLE3
TP53
TP63
TRIM28
UBTF
USF1
USF2
VDR
WRNIP1
YY1
ZBTB33
ZBTB7A
ZEB1
ZKSCAN1
ZNF143
ZNF217
ZNF263
ZNF274
ZNF76
ZZZ3
