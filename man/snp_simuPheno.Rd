% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/simu-pheno.R
\name{snp_simuPheno}
\alias{snp_simuPheno}
\title{Simulate phenotypes}
\usage{
snp_simuPheno(
  G,
  h2,
  M,
  K = NULL,
  alpha = -1,
  ind.row = rows_along(G),
  ind.possible = cols_along(G),
  prob = NULL,
  effects.dist = c("gaussian", "laplace"),
  ncores = 1
)
}
\arguments{
\item{G}{A \link[bigstatsr:FBM.code256-class]{FBM.code256}
(typically \verb{<bigSNP>$genotypes}).\cr
\strong{You shouldn't have missing values.} Also, remember to do quality control,
e.g. some algorithms in this package won't work if you use SNPs with 0 MAF.}

\item{h2}{Heritability.}

\item{M}{Number of causal variants.}

\item{K}{Prevalence. Default is \code{NULL}, giving a continuous trait.}

\item{alpha}{Assumes that the average contribution (e.g. heritability)
of a SNP of frequency \eqn{p} is proportional to
\eqn{[2p(1-p)]^{1+\alpha}}. Default is \code{-1}.}

\item{ind.row}{An optional vector of the row indices (individuals) that
are used. If not specified, all rows are used.\cr
\strong{Don't use negative indices.}}

\item{ind.possible}{Indices of possible causal variants.}

\item{prob}{Vector of probability weights for sampling causal indices.
It can have 0s (discarded) and is automatically scaled to sum to 1.
Default is \code{NULL} (all indices have the same probability).}

\item{effects.dist}{Distribution of effects.
Either \code{"gaussian"} (the default) or \code{"laplace"}.}

\item{ncores}{Number of cores used. Default doesn't use parallelism.
You may use \code{\link[bigstatsr:reexports]{bigstatsr::nb_cores()}}.}
}
\value{
A list with 3 elements:
\itemize{
\item \verb{$pheno}: vector of phenotypes,
\item \verb{$set}: indices of causal variants,
\item \verb{$effects}: effect sizes (of scaled genotypes) corresponding to \code{set}.
\item \verb{$allelic_effects}: effect sizes, but on the allele scale (0|1|2).
}
}
\description{
Simulate phenotypes using a linear model. When a prevalence is given, the
liability threshold is used to convert liabilities to a binary outcome.
The genetic and environmental liabilities are scaled such that the variance
of the genetic liability is exactly equal to the requested heritability, and
the variance of the total liability is equal to 1.
}
