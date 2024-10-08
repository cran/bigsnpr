% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/modify-positions.R
\name{download_genetic_map}
\alias{download_genetic_map}
\alias{snp_asGeneticPos2}
\title{Download a genetic map}
\usage{
download_genetic_map(
  type = c("hg19_OMNI", "hg19_hapmap", "hg38_price"),
  dir,
  ncores = 1
)

snp_asGeneticPos2(infos.chr, infos.pos, genetic_map)
}
\arguments{
\item{type}{Which genetic map to download.}

\item{dir}{Directory where to download and decompress files.}

\item{ncores}{Number of cores used. Default doesn't use parallelism.
You may use \code{\link[bigstatsr:reexports]{bigstatsr::nb_cores()}}.}

\item{infos.chr}{Vector of integers specifying each SNP's chromosome.\cr
Typically \verb{<bigSNP>$map$chromosome}.}

\item{infos.pos}{Vector of integers specifying the physical position
on a chromosome (in base pairs) of each SNP.\cr
Typically \verb{<bigSNP>$map$physical.pos}.}

\item{genetic_map}{A data frame with 3 columns: \code{chr}, \code{pos}, and \code{pos_cM}.
You can get it using \code{\link[=download_genetic_map]{download_genetic_map()}}.}
}
\value{
A data frame with 3 columns: \code{chr}, \code{pos}, and \code{pos_cM}.

The new vector of genetic positions.
}
\description{
This function uses linear interpolation, whereas \code{snp_asGeneticPos()} uses
nearest neighbors.
}
\details{
The hg19 genetic maps are downloaded from
\url{https://github.com/joepickrell/1000-genomes-genetic-maps/}
while the hg38 one is downloaded from
\verb{https://alkesgroup.broadinstitute.org/Eagle/downloads/tables/}.
}
