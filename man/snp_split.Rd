% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/apply-parallelize.R
\name{snp_split}
\alias{snp_split}
\title{Split-parApply-Combine}
\usage{
snp_split(infos.chr, FUN, combine, ncores = 1, ...)
}
\arguments{
\item{infos.chr}{Vector of integers specifying each SNP's chromosome.\cr
Typically \verb{<bigSNP>$map$chromosome}.}

\item{FUN}{The function to be applied. It must take a
\link[bigstatsr:FBM.code256-class]{FBM.code256} as first argument and \code{ind.chr},
an another argument to provide subsetting over SNPs.
You can access the number of the chromosome by using \code{attr(ind.chr, "chr")}.}

\item{combine}{function that is used by \link[foreach:foreach]{foreach::foreach} to process the tasks
results as they generated. This can be specified as either a function or a
non-empty character string naming the function. Specifying 'c' is useful
for concatenating the results into a vector, for example. The values 'cbind'
and 'rbind' can combine vectors into a matrix. The values '+' and '*' can be
used to process numeric data. By default, the results are returned in a list.}

\item{ncores}{Number of cores used. Default doesn't use parallelism.
You may use \code{\link[bigstatsr:reexports]{bigstatsr::nb_cores()}}.}

\item{...}{Extra arguments to be passed to \code{FUN}.}
}
\value{
The result of \link[foreach:foreach]{foreach::foreach}.
}
\description{
A Split-Apply-Combine strategy to parallelize the evaluation of a function
on each SNP, independently.
}
\details{
This function splits indices for each chromosome, then apply a given function
to each part (chromosome) and finally combine the results.
}
\examples{
# parallelize over chromosomes made easy
# examples of functions from this package
snp_pruning
snp_clumping
snp_fastImpute

}
