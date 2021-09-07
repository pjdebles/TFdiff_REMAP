#!/usr/bin/env Rscript
# essential libraries
suppressMessages( library(ade4) )
suppressMessages( library(fBasics) )
suppressMessages( library(rrcov) )
suppressMessages( library(sqldf) )

Args <- commandArgs(TRUE);      # retrieve args

if (length(Args) != 4) {
   cat("Usage: ./ddmMDSPlot.R ddm_pval_annotated_results.csv threshold (e.g. 0.05) mode (normal or probadj) outfile (e.g. ddm_liver)\n")
   errorMessage<-paste( "Error with # arguments:",length(Args),"\n" )
   cat(errorMessage)
   stop("Check parameters!")
   }

# read data file

#Args[1]="liver_top_expressors_800_vs_liver_min_expressors_800_tfp20103_vertebrates_nr_ddm_pval_annotated_results.txt"
resultFile = Args[1]
threshold = Args[2]
mode = Args[3]
outfile = Args[4]

cat("results file: ",resultFile,"\n")
content = read.csv(resultFile, sep="\t")

# From the calcSignificance.pl script:
# $pwmId\t$x2\t$y2\t$dist2Origin\t$slope\t$pvalue\t$trend\t$pvalue_trend
colnames(content) = c("pwmId","x2","y2","dist2Origin","slope","pvalue","trend","pvalue_trend","tfbs")

# some general plotting parameters
colrange=c("green", "red")
#mode="probadj"
#threshold=0.05
pch = 20
cex=1

#COLORS

nrcolors <- 256
palette  <- colorRampPalette(colrange, space="Lab", bias=1, interpolate="spline")(nrcolors)
  
#print(content$trend)

xrange   <- range(content$trend, na.rm=TRUE)

z2icol_origin   <- function(z) {
    res = round((z-xrange[1])/diff(xrange)*(nrcolors-1))+1
    res[res > nrcolors] <- nrcolors
    res[res < 1] <- 1
    return(res)
}

###more comparable plot colors have the zero points with the middle color
coltocenter <- function(c,min,max) {
	if(c > 0) kleur <- trunc((c/max)*(nrcolors/2)+(nrcolors/2))
	else if (c < 0) kleur <- trunc((nrcolors/2)-(c/min)*(nrcolors/2)+1)
	else kleur <- trunc(nrcolors/2) #c=0
}
  
z2icol <- function(z) {
    res <- sapply(z,coltocenter,min(z),max(z)) 
    return(res)
  }

######

if(mode == "normal") { #CLASSICAL

reportFile <- paste(outfile,"_regular_",threshold,".ps",sep="")
postscript(reportFile, paper = "special", pointsize = 15, horizontal = FALSE,width = 1024./72., height = 768./72.)

plot(content$x2,content$y2,col = palette[z2icol(as.vector(content$trend))], asp=1, main="regular DDM-MDS plot",abline(h=0,v=0),xlim=range(content$x2)*1.1,ylim=range(content$y2)*1.1,xlab="",ylab="",pch=pch)
chh <- strheight(" ")
selection <- content[content$pvalue < threshold,]  
text(selection$x2+0.5*chh, selection$y2+0.5*chh, labels = selection$tfbs, cex = 0.5, adj=0)

dev.off()
}

#else if (mode == "probadj") {
if (mode == "probadj") {

#TRANSFORMED
#original coordinates determine the angle, but the distance to zero will be adapted according to the significance
#hence we need to change the original coordinates
content$anglestoposx <- atan(content$y2/content$x2) #angles in radial units in relation to the positive X-axis

index<-1
content$angles<-sapply(content$anglestoposx,function(x) {
				value <- x
				if(content$x2[index]< 0) {value<-value+pi} #second and third quadrant
				index<-index+1
				return(value)
			}
)

###NONLOG pvalues
#nonlogpart <- function() {
#
#content$newdistancetozero <- 1-content$pvalue
#
#content$newx <- content$newdistancetozero * cos(content$angles)
#content$newy <- content$newdistancetozero * sin(content$angles)
#
#plot(content$newx,content$newy,col = palette[z2icol(as.vector(content$trend))],asp=1,main="transformed DDM-MDS plot (linear scale)",abline(h=0,v=0),xlim=range(content$newx)*1.1,ylim=range(content$newy)*1.1)
#chh <- strheight(" ")
#selection <- content[content$pvalue < threshold,]
#text(selection$newx+0.5*chh,selection$newy+0.5*chh, labels = content$tfbs, cex = 0.5, adj=0)
#
#}

###LOG pvalues
e<-2.71828183
content$padj <- content$pvalue + min(content$pvalue[content$pvalue != 0])/10 #to avoid infinite values when taking log
content$newdistancetozero <- - log(content$padj)/log(10)

content$newx <- content$newdistancetozero * cos(content$angles)
content$newy <- content$newdistancetozero * sin(content$angles)

reportFile <- paste(outfile,"_probabilistic_",threshold,".ps",sep="")
#reportFile <- paste(outfile,"_probabilistic_",threshold,".png",sep="")

postscript(reportFile, paper = "special", pointsize = 15, horizontal = FALSE,width = 1024./72., height = 768./72.)
#png(reportFile)
plot(content$newx,content$newy,col = palette[z2icol(as.vector(content$trend))], asp=1, main="probabilistic DDM-MDS plot",abline(h=0,v=0),xlim=range(content$newx)*1.1,ylim=range(content$newy)*1.1,xlab="",ylab="",pch=pch)
#labelling only the significant ones
chh <- strheight(" ")
selection <- content[content$pvalue < threshold & content$pvalue_trend < 0.5,]
#selection <- content[content$pvalue < threshold,]
text(selection$newx+0.5*chh,selection$newy+0.5*chh, labels = selection$tfbs, cex = 0.5, adj=0)
#probability circles (as much as needed)
potcircles <- seq(1,100,1)
maxsig <- max(content$newdistancetozero)
circlestodraw <- potcircles[potcircles<maxsig]
grid <- seq(0, 2 * pi, length = 360 / 5 + 1)
for(circleradius in circlestodraw) { lines(circleradius * cos(grid), circleradius * sin(grid), col = "gray") }
angle.axis<- -90
text(circlestodraw * cos(angle.axis * pi / 180) + 1.5*chh, circlestodraw * sin(angle.axis * pi / 180)-chh, paste("e-0",circlestodraw,sep=""),col="gray") 
dev.off()

} #end probadj

##############################################################################
