% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/bigSNP-class.R
\name{bigSNP-class}
\alias{bigSNP-class}
\alias{bigSNP}
\title{Class bigSNP}
\value{
A named list with at least 3 slots: \describe{
\item{genotypes}{A \link[bigstatsr:FBM.code256-class]{FBM.code256} which is
a special Filebacked Big Matrix encoded with type \code{raw} (one byte
unsigned integer), representing genotype calls and possibly imputed
allele dosages. Rows are individuals and columns are SNPs.}
\item{fam}{A \code{data.frame} containing some information on the individuals
(read from a ".fam" file).}
\item{map}{A \code{data.frame} giving some information on the variants
(read from a ".bim" file).}
}
}
\description{
An S3 class for representing information on massive SNP arrays.
}
\seealso{
\link{snp_readBed}
}
\keyword{class}
