#!/usr/bin/env Rscript
suppressMessages(library(biomaRt))

Args <- commandArgs(TRUE);      # retrieve args

if (length(Args) != 1) {
   cat("Usage: ./refseq2hgnc.R refseqs (file: 1 refseq ID per line)\n")
   stop("Check parameters!")
   }

refseqsFile = Args[1]
baseName = sapply(strsplit(basename(refseqsFile),"\\."), function(x) paste(x[1:(length(x)-1)], collapse="."))[1]

# Some default parameters used for development testing...
# Args[1] = "E2F_up.refseq"

library(biomaRt)

# Define biomart object
mart <- useMart(biomart = "ensembl", dataset = "hsapiens_gene_ensembl")

# Read in file with gene names
refseqs <- read.csv( refseqsFile )

# Extract information from biomart
results <- getBM(attributes = c("refseq_mrna", "hgnc_symbol"), filters = "refseq_mrna", uniqueRows = TRUE, values = refseqs[,1], mart = mart)
# see uniqueRows = TRUE/FALSE to return unique list of IDs or not

# Write to result file
resultFile = paste(baseName,"_hgnc.csv",sep="")
write.table(results, resultFile,col.names=TRUE,sep="\t",quote=FALSE, row.names=FALSE)
