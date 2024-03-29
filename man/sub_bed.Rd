% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/bed-class.R
\name{sub_bed}
\alias{sub_bed}
\title{Replace extension '.bed'}
\usage{
sub_bed(path, replacement = "", stop_if_not_ext = TRUE)
}
\arguments{
\item{path}{String with extension '.bed'.}

\item{replacement}{Replacement of '.bed'. Default replaces by nothing.
Can be useful to replace e.g. by '.bim' or '.fam'.}

\item{stop_if_not_ext}{If \code{replacement != ""}, whether to error if
replacement is not an extension (starting with a '.').}
}
\value{
String with extension '.bed' replaced by \code{replacement}.
}
\description{
Replace extension '.bed'
}
\examples{
path <- "toto.bed"
sub_bed(path)
sub_bed(path, ".bim")
sub_bed(path, ".fam")
sub_bed(path, "_QC", stop_if_not_ext = FALSE)
}
