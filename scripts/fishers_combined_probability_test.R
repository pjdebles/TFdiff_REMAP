#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(qvalue))

Args <- commandArgs(TRUE);

if (length(Args) != 1) {
  cat("Usage: ./fishers_combined_probability_test.R combined_p-values_file (result from 'buildIDRTable.pl' script)\n")
  stop("Check parameters!")
}

pvaluesFile = Args[1]

pvaluesTable = read.table(pvaluesFile, row.names=1, sep="\t", stringsAsFactors=FALSE)

Fisher.test <- function(p) {
  Xsq <- -2*sum(log(p))
  p.val <- pchisq(Xsq, df = 2*length(p), lower.tail = FALSE)
  #return(c(Xsq = Xsq, p.value = p.val))
  return(c(p.value = p.val))
}
 
#combinedProbability = as.numeric(apply(pvaluesTable, 1, function(p) Fisher.test(p)))
combinedProbability = apply(pvaluesTable, 1, function(p) Fisher.test(p))

k <- dim(pvaluesTable)[2]

#Perform FDR estimation from the collection of p-values.
#Calculate qvalue object:
qobj <- qvalue(combinedProbability)

#Create results table:
resultsTable <- cbind(pvaluesTable,combinedProbability,qobj$qvalues)
colnames(resultsTable) <- c(paste(rep("R",k),c(1:k),sep=""),"p-value","q-value")

#Order by q-value:
resultsTable <- resultsTable[ order(resultsTable["q-value"]), ]

# Write to result file
baseName = sapply(strsplit(basename(pvaluesFile),"\\."), function(x) paste(x[1:(length(x)-1)], collapse="."))[1]
resultFile = paste(baseName,"_Fishers_meta_analysis.csv",sep="")
write.table(resultsTable, resultFile, col.names=FALSE, sep="\t", quote=FALSE, row.names=TRUE)
            
cat("Results written to ", resultFile," ...\n")
