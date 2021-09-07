#!/usr/bin/perl 
# ============================================================================ #
#
#         FILE:  ddmTyrant.pl
#
#        USAGE:  perl ddmTyrant.pl [OPTIONS] [ARGUMENTS]
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Pieter De Bleser (pieterdb@irc.vib-ugent.be)
#                Soete Arne (arne.soete@irc.vib-ugent.be)
#      COMPANY:  VIB-UGent
#      VERSION:  0.1
#      CREATED:  2014-10-27 Mon 13:39:29
#     REVISION:  
# ============================================================================ #

#
# test run: ./ddmTyrant.pl E2F_up_hgnc.list E2F_down_hgnc.list 10000
#

use strict;
use warnings;

use Cwd 'abs_path';
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Copy;
use File::Temp qw/ tempfile /;
use FindBin;
use Getopt::Long;
use POSIX qw(strftime);

use lib $FindBin::RealBin;
use Tfdiff;

# ============================================================================ #

my @ARGV_ORIG = @ARGV;
$POD_FILE = pod2path( 'ddmTyrant.pod' );

# ----

$DATADIR           = sprintf( '%s/data', dirname( $FindBin::RealBin) );
#my $NOF_BG_RUNS    = 1000;
my $NOF_BG_RUNS    = 100;
#my $PVAL_CUTOFF    = 10;
my $PVAL_CUTOFF    = 5;
my $CACHE_BASE_DIR = 0;
my $CPUS           = `nproc`; chomp $CPUS;
my $RAND_LINES     = 'randomLines';

my $result = GetOptions (
   'cpu|j=i'         => \$CPUS,
   'r|bg-runs=i'     => \$NOF_BG_RUNS,
   'bg-cachedir|c=s' => \$CACHE_BASE_DIR,
   'debug'           => sub { $VERBOSITY = $V_DEBUG },
   'n|dry-run'       => \$DRY_RUN,
   'o|outdir=s'      => \$OUTDIR,
   'randomLines=s'   => \$RAND_LINES,
   'pval-cutoff|p=f' => \$PVAL_CUTOFF,
   'silent'          => sub { $VERBOSITY = $V_SILENT },
   'verbose|v+'      => \$VERBOSITY,
   'help'            => sub{ help( verbose              => 1) },
   'man'             => sub{ help( verbose              => 2) },
);

# ----

print STDERR "\n";

plog( sprintf('Data directory            : %s' , $DATADIR) , $V_VERBOSE );
plog( sprintf('Number of background runs : %d' , $NOF_BG_RUNS), $V_VERBOSE );

# ----

help() if( @ARGV < 2 || @ARGV > 3 );

# ----

$OUTDIR = createOutdir() if !$OUTDIR;
plog( sprintf('Output directory          : %s' , $OUTDIR)  , $V_VERBOSE );

mkdir $OUTDIR if !-d $OUTDIR && !$DRY_RUN;

# ----

my ($upHgnc, $downHgnc ) = @ARGV;

$NOF_BG_RUNS = $ARGV[2] if $ARGV[2];

# ---------------------------------------------------------------------------- #

my $upHgnc_file = abs_path( $upHgnc );
help( msg => sprintf(
   'Unable to read upHgnc_file: %s (from %s) -- %s',
   $upHgnc_file,
   $upHgnc,
   $!
) ) if ( ! -f $upHgnc_file || ! -r $upHgnc_file );

# ----

my $downHgnc_file = abs_path( $downHgnc );
help( msg => sprintf(
   'Unable to read upHgnc_file: %s (from %s) -- %s',
   $downHgnc_file,
   $upHgnc,
   $!
) ) if ( ! -f $downHgnc_file|| ! -r $downHgnc_file);

# ----

plog( sprintf('$upHgnc_file   : Up-regulated list (file): %s' ,
   $upHgnc_file
), $V_VERBOSE );

plog( sprintf('$downHgnc_file : Down-regulated list (file): %s' ,
   $downHgnc_file
), $V_VERBOSE );

help( msg => 'Input file(s) are empty' ) if ( -z $upHgnc_file || -z $downHgnc_file );

# ---------------------------------------------------------------------------- #

my $tfbsCountDatabase_filename = sprintf(
   'hg19_genes_tf_targeted_%d_jaccard_distmat_TAGC.vector',
   pvalToInt( $PVAL_CUTOFF )
);

my $tfbsCountDatabase = dataname2path( $tfbsCountDatabase_filename );

plog( sprintf('$tfbsCountDatabase : %s', $tfbsCountDatabase ), $V_VERBOSE );

# ---------------------------------------------------------------------------- #

# log the CLI arguments in 'parameters.txt'
my $parameters = sprintf( "%s/parameters.sh", $OUTDIR );
plog( sprintf('Parameters logfile : %s', $parameters), $V_VERBOSE );

if( !$DRY_RUN ) {

   open(PARMS, ">$parameters");
   print PARMS "# TIMESTAMP      : ".strftime( '%Y-%m-%d %H:%M:%S', localtime )."\n";
   print PARMS "# CWD            : ". Cwd::getcwd() . "\n";
   print PARMS "# UP (group 1)   : $upHgnc_file\n";
   print PARMS "# DOWN (group 2) : $downHgnc_file\n";
   print PARMS "# NOF. BG-RUNS   : $NOF_BG_RUNS\n";
   print PARMS "# CACHE ROOT     : $CACHE_BASE_DIR\n";
   print PARMS 'cd ' . Cwd::getcwd() . " && \\\n";
   print PARMS sprintf( "perl %s %s\n", $0, join( ' ', @ARGV_ORIG ) );
   close(PARMS);
}

# ----

# get the base name of the files
my ( $uName, $uPath, $uSuffix ) = fileparse( $upHgnc_file, ( ".list",".txt",".csv" ) );
my ( $dName, $dPath, $dSuffix ) = fileparse( $downHgnc_file, ( ".list",".txt",".csv" ) );

plog( sprintf( 'Up-regulated set   : filename : %s', $uName ), $V_DEBUG );
plog( sprintf( 'Down-regulated set : filename : %s', $dName), $V_DEBUG );

################################################################################
#
# II. Identify transcription factor binding sites (using 'tyrant approach') 
#
################################################################################

plog( 'II. Identifying TFBSs...' );

# names of count files required for DDM scripts
my $upCounts   = outfile2path( $uName."_counts.csv" );
my $downCounts = outfile2path( $dName."_counts.csv" );

plog( sprintf( '$upCounts (file)   : %s', $upCounts ), $V_VERBOSE );
plog( sprintf( '$downCounts (file) : %s', $downCounts ), $V_VERBOSE );

call( sprintf( '%s %s %s > %s',
   script2path( 'buildTfbsCounts.pl' ),
   $upHgnc_file,
   $tfbsCountDatabase,
   $upCounts
) );

call( sprintf( '%s %s %s > %s',
   script2path('buildTfbsCounts.pl'),
   $downHgnc_file,
   $tfbsCountDatabase,
   $downCounts
) );


plog( "Done...(results written to $upCounts and $downCounts)" );

# ---------------------------------------------------------------------------- #

my $upSize = call( "wc -l $upCounts", $V_DEBUG );
chomp($upSize);
--$upSize; # omit header

# ----

my $downSize = call( "wc -l $downCounts", $V_DEBUG );
chomp($downSize);
--$downSize;

# ----

if( $upSize == 0 ) {

   warn( sprintf('buildTfbsCounts.pl produced NO RESULTS for %s', $upHgnc_file ) );
   exit 0;
}

if( $downSize == 0 ) {

   warn( sprintf('buildTfbsCounts.pl produced NO RESULTS for %s', $downHgnc_file ) );
   exit 0;
}

################################################################################
#
# III. DDM-MDS calculation
#
################################################################################

plog( "IV. Calculating DDM-MDS on $upCounts versus $downCounts ..." );

# name of DDM result file
my $ddmResultFile = outfile2path( $uName."_vs_".$dName."_ddm_results.txt" );

plog( sprintf( '$ddmResultFile : %s', $ddmResultFile ), $V_VERBOSE );

if ( !-e $ddmResultFile ) {

   call( sprintf( '%s %s %s %s --set-verbosity %d',
      script2path('DDM.pl'),
      $upCounts,
      $downCounts,
      $ddmResultFile,
      $VERBOSITY
   ));
}

plog( "Done...(results written to $ddmResultFile)" );

################################################################################
#
# IV. DDM-MDS background calculations
#
################################################################################

# my $cache_dir = get_cache_dir( $upSize, $downSize );
my $cache_dir = 0;

# ---------------------------------------------------------------------------- #

plog( 
   "V. DDM-MDS calculations on $NOF_BG_RUNS random sets of $upSize A and ".
   "$downSize B..."
);

 if( ! $cache_dir ) {

   call( sprintf( 
      '%s %s %d %d %d --randomLines=%s --outdir %s --cpu %d --set-verbosity %d',
      script2path('DDMbg.pl'),
      $tfbsCountDatabase,
      $NOF_BG_RUNS,
      $upSize,
      $downSize,
      $RAND_LINES,
      $OUTDIR,
      $CPUS,
      $VERBOSITY
   ) );

 }
 else {

   plog( sprintf('SKIPPING: using cache: %s', $cache_dir), $V_RUN );
 }

################################################################################
#
################################################################################

my $ddmPvalResultFile = outfile2path(
   $uName."_vs_".$dName."_ddm_pval_results.txt"
);

my $bgHash_jsonfile = outfile2path( 'bgHash.json' );
my $trendHash_jsonfile = outfile2path( 'trendHash.json' );

plog( sprintf( '$ddmPvalResultFile: %s' ,$ddmPvalResultFile ), $V_VERBOSE );
plog( "VI. Calculation of the significances of the obtained results..." );


if( !$cache_dir ) {

   my $randomization_results_file = outfile2path( 'randomization_results.list' );

   call( sprintf( 'ls -1 %s > %s',
      outfile2path('BG_*_results.csv'),
      $randomization_results_file
   ) );

   call( sprintf( '%s --infile  %s --outdir %s',
      script2path('calcBgDistribution.pl'),
      $randomization_results_file,
      $OUTDIR
   ) );
}
else {

   plog( sprintf('SKIPPING: using cache: cp %s %s',
      sprintf( '%s/{%s,%s}', $cache_dir, 'bgHash.json', 'trendHash.json'),
      $OUTDIR
   ), $V_RUN );

   copy( sprintf( '%s/bgHash.json', $cache_dir ), $bgHash_jsonfile );
   copy( sprintf( '%s/trendHash.json', $cache_dir ), $trendHash_jsonfile );
}

call( sprintf( '%s %s %s %s > %s',
   script2path('calcSignificance.pl'),
   $bgHash_jsonfile,
   $trendHash_jsonfile,
   $ddmResultFile,
   $ddmPvalResultFile
) );

#clean up
call( sprintf( 'rm %s',
   outfile2path( 'BG_*_results.csv' )
) ) if !$cache_dir;

my $filesToDelete = outfile2path( "BG_*_".$upSize."_".$downSize."_counts.csv" );
call( "rm $filesToDelete" )if !$cache_dir;

################################################################################
#
# VI. Annotation of the results
#
################################################################################

my $ddmAnnotatedFile = outfile2path(
   $uName."_vs_".$dName."_ddm_pval_annotated_results.txt"
);

plog( sprintf( '$ddmAnnotatedFile : %s' ,$ddmAnnotatedFile ), $V_VERBOSE);

plog( "VII. Annotating the obtained results..." );


if( !$DRY_RUN ) {

   # create the matrixid to transcription factor dictionary
   my %matrixID2TF = ();
   while (<DATA>) {
      chomp();
      my ($matrixID, $TF) = split( /\t/ );
      $matrixID2TF{ $matrixID } = $TF;
   }

   my @dataFile = readFile($ddmPvalResultFile);

   my ( $fh, $tmpFile ) = tempfile(
      'annotating-XXXXXXXX',
      DIR    => $OUTDIR,
      SUFFIX => '.tmp',
      UNLINK => 1,
   );

   foreach my $line (@dataFile) {
      chomp($line);
      my @array = split(/\t/, $line);
      print $fh join("\t",@array)."\t";
      if ( $matrixID2TF{ $array[0] } ) {
         print $fh $matrixID2TF{ $array[0] },"\n";
      }
      else { 
         print $fh "?\n"; 
      }
   }
   call( sprintf( 'sort -k 6n,6 -k 7rn,7 -k8n,8 %s > %s',

      $tmpFile,
      $ddmAnnotatedFile
   ) );
}
else {

   plog( 'SKIPPING: DRY RUN', $V_RUN );
}


plog( "Done...(results written to $ddmAnnotatedFile)" );

################################################################################
#
# VII. Creating results directory
#
################################################################################

#print "\nVIII. Creating results directory...\n";
#
## backup the tfbs counts results
#move($upCounts, $OUTDIR) or die "Failed to move $upCounts: $!\n";
#move($downCounts, $OUTDIR) or die "Failed to move $downCounts: $!\n";
#
## backup the DDM result file
#move($ddmResultFile, $OUTDIR) or die "Failed to move $ddmResultFile: $!\n";
#
## backup the background result files
## foreach my $file ( <BG_*_results.csv> ) {
##         move($file,$OUTDIR) or die "Failed to move $file: $!\n";
##         }
#
## backup the final DDMresults
#move($ddmPvalResultFile, $OUTDIR) or die "Failed to move $ddmPvalResultFile: $!\n";
#move($ddmAnnotatedFile, $OUTDIR) or die "Failed to move $ddmAnnotatedFile: $!\n";
#
## backup the analysis parameters
#move($parameters, $OUTDIR) or die "Failed to move $parameters: $!\n";
#
#print "Done...(results written to $OUTDIR)\n\n";

# ============================================================================ #
# Cache

sub get_cache_dir {

   my $up   = shift;
   my $down = shift;

   return 0 if ! $CACHE_BASE_DIR;

   return 0 if ! -d $CACHE_BASE_DIR;

   my $dir = sprintf( '%s/up%d/down%d', $CACHE_BASE_DIR, $up, $down );

   return 0 if ! -d $dir;

   return 0 if ! -f sprintf( '%s/bgHash.json', $dir );
   return 0 if ! -f sprintf( '%s/trendHash.json', $dir );

   return $dir;
}

# ============================================================================ #
# 

sub pvalToInt {

   my $pval = shift;
   my $factor = shift || 100;

   return $pval if( $pval > 1 );

   return $pval * $factor;
}

################################################################################
#
# MatrixIDs to TF conversion table
#
################################################################################

__DATA__
AFF4	AFF4
AHR	AHR
AR	AR
ARID3A	ARID3A
ARNT	ARNT
ATF1	ATF1
ATF2	ATF2
ATF3	ATF3
ATRX	ATRX
BACH1	BACH1
BATF	BATF
BCL11A	BCL11A
BCL3	BCL3
BCL6	BCL6
BCLAF1	BCLAF1
BCOR	BCOR
BDP1	BDP1
BHLHE40	BHLHE40
BRCA1	BRCA1
BRD2	BRD2
BRD3	BRD3
BRD4	BRD4
BRF1	BRF1
BRF2	BRF2
CBFB	CBFB
CBX3	CBX3
CCNT2	CCNT2
CDK8	CDK8
CDK9	CDK9
CDX2	CDX2
CEBPA	CEBPA
CEBPB	CEBPB
CEBPD	CEBPD
CHD1	CHD1
CHD2	CHD2
CREB1	CREB1
CTBP2	CTBP2
CTCF	CTCF
CTCFL	CTCFL
CTNNB1	CTNNB1
DCP1A	DCP1A
E2F1	E2F1
E2F4	E2F4
E2F6	E2F6
E2F7	E2F7
EBF1	EBF1
EGR1	EGR1
ELF1	ELF1
ELF5	ELF5
ELK1	ELK1
ELK4	ELK4
ELL2	ELL2
EOMES	EOMES
ERG	ERG
ESR1	ESR1
ESR2	ESR2
ESRRA	ESRRA
ETS1	ETS1
ETV1	ETV1
EZH2	EZH2
FAM48A	FAM48A
FLI1	FLI1
FOS	FOS
FOSL1	FOSL1
FOSL2	FOSL2
FOXA1	FOXA1
FOXA2	FOXA2
FOXH1	FOXH1
FOXM1	FOXM1
FOXP1	FOXP1
FOXP2	FOXP2
GABPA	GABPA
GATA1	GATA1
GATA2	GATA2
GATA3	GATA3
GATA6	GATA6
GATAD1	GATAD1
GPS2	GPS2
GREB1	GREB1
GTF2B	GTF2B
GTF2F1	GTF2F1
GTF3C2	GTF3C2
HDAC1	HDAC1
HDAC2	HDAC2
HDAC6	HDAC6
HDAC8	HDAC8
HMGN3	HMGN3
HNF4A	HNF4A
HNF4G	HNF4G
HSF1	HSF1
IKZF1	IKZF1
IRF1	IRF1
IRF3	IRF3
IRF4	IRF4
JUN	JUN
JUNB	JUNB
JUND	JUND
KDM5A	KDM5A
KDM5B	KDM5B
KLF4	KLF4
MAFF	MAFF
MAFK	MAFK
MAX	MAX
MAZ	MAZ
MBD4	MBD4
MED12	MED12
MEF2A	MEF2A
MEF2C	MEF2C
MEIS1	MEIS1
MTA3	MTA3
MXI1	MXI1
MYBL2	MYBL2
MYC	MYC
NANOG	NANOG
NCOA1	NCOA1
NCOR1	NCOR1
NCOR2	NCOR2
NELFE	NELFE
NF1C	NF1C
NFATC1	NFATC1
NFE2	NFE2
NFKB1	NFKB1
NFYA	NFYA
NFYB	NFYB
NIPBL	NIPBL
NKX2-1	NKX2-1
NKX3-1	NKX3-1
NOTCH1	NOTCH1
NR2C2	NR2C2
NR2F2	NR2F2
NR3C1	NR3C1
NR3C3	NR3C3
NRF1	NRF1
ONECUT1	ONECUT1
ORC1	ORC1
PAX5	PAX5
PBX3	PBX3
PHF8	PHF8
PML	PML
POU2F2	POU2F2
POU5F1	POU5F1
PPARG	PPARG
PPARGC1A	PPARGC1A
PRAME	PRAME
PRDM1	PRDM1
PRDM14	PRDM14
RAC3	RAC3
RAD21	RAD21
RB1	RB1
RBBP5	RBBP5
RBPJ	RBPJ
RCOR1	RCOR1
RELA	RELA
REST	REST
RFX5	RFX5
RNF2	RNF2
RPC155	RPC155
RUNX1	RUNX1
RUNX1+3	RUNX1+3
RUNX1T1	RUNX1T1
RUNX2	RUNX2
RUNX3	RUNX3
RXRA	RXRA
SAP30	SAP30
SETDB1	SETDB1
SFMBT1	SFMBT1
SIN3A	SIN3A
SIRT6	SIRT6
SIX5	SIX5
SMAD1	SMAD1
SMAD2+3	SMAD2+3
SMAD3	SMAD3
SMAD4	SMAD4
SMARCA4	SMARCA4
SMARCB1	SMARCB1
SMARCC1	SMARCC1
SMARCC2	SMARCC2
SMC1A	SMC1A
SMC3	SMC3
SMC4	SMC4
SNAPC1	SNAPC1
SNAPC4	SNAPC4
SNAPC5	SNAPC5
SOX2	SOX2
SP1	SP1
SP2	SP2
SP4	SP4
SPI1	SPI1
SREBP1	SREBP1
SRF	SRF
STAG1	STAG1
STAT1	STAT1
STAT2	STAT2
STAT3	STAT3
STAT4	STAT4
STAT5A	STAT5A
STAT5B	STAT5B
SUZ12	SUZ12
TAF1	TAF1
TAF2	TAF2
TAF3	TAF3
TAF7	TAF7
TAL1	TAL1
TAp73a	TAp73a
TAp73b	TAp73b
TBL1	TBL1
TBL1XR1	TBL1XR1
TBP	TBP
TCF12	TCF12
TCF3	TCF3
TCF4	TCF4
TCF7L2	TCF7L2
TEAD4	TEAD4
TFAP2A	TFAP2A
TFAP2C	TFAP2C
TFAP4	TFAP4
THAP1	THAP1
TLE3	TLE3
TP53	TP53
TP63	TP63
TRIM28	TRIM28
UBTF	UBTF
USF1	USF1
USF2	USF2
VDR	VDR
WRNIP1	WRNIP1
YY1	YY1
ZBTB33	ZBTB33
ZBTB7A	ZBTB7A
ZEB1	ZEB1
ZKSCAN1	ZKSCAN1
ZNF143	ZNF143
ZNF217	ZNF217
ZNF263	ZNF263
ZNF274	ZNF274
ZNF76	ZNF76
ZZZ3	ZZZ3
