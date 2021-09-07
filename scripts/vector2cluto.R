#!/usr/bin/env Rscript
Args <- commandArgs(TRUE);      # retrieve args

if (length(Args) != 1) {
  cat("Usage: ./vector2cluto.R vector_file (from tfTargetsToVector.pl)\n")
  stop("Check parameters!")    
}

csvFile   = Args[1]

baseName = sapply(strsplit(basename(csvFile),"\\."), function(x) paste(x[1:(length(x)-1)], collapse="."))[1]
cat("base name: ", baseName,"\n")

profilesVector<-read.csv(csvFile,row.names=1,header=TRUE,sep="\t")
library(slam)
M <- as.matrix(profilesVector)

resultFile = paste(baseName,".cluto",sep="")
write_stm_CLUTO(M, resultFile)
