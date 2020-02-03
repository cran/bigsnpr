################################################################################

flip_strand <- function(allele) {

  if (!requireNamespace("dplyr", quietly = TRUE))
    stop2("Please install package 'dplyr'.")

  dplyr::case_when(
    allele == "A" ~ "T",
    allele == "C" ~ "G",
    allele == "T" ~ "A",
    allele == "G" ~ "C",
    TRUE ~ NA_character_
  )
}

#' Match alleles
#'
#' Match alleles between summary statistics and SNP information.
#' Match by ("chr", "a0", "a1") and ("pos" or "rsid"), accounting for possible
#' strand flips and reverse reference alleles (opposite effects).
#'
#' @param sumstats A data frame with columns "chr", "pos", "a0", "a1" and "beta".
#' @param info_snp A data frame with columns "chr", "pos", "a0" and "a1".
#' @param strand_flip Whether to try to flip strand? (default is `TRUE`)
#'   If so, ambiguous alleles A/T and C/G are removed.
#' @param join_by_pos Whether to join by chromosome and position (default),
#'   or instead by rsid.
#' @param match.min.prop Minimum proportion of variants in the smallest data
#'   to be matched, otherwise stops with an error. Default is `50%`.
#'
#' @return A single data frame with matched variants.
#' @export
#'
#' @seealso [snp_modifyBuild]
#'
#' @import data.table
#'
#' @example examples/example-match.R
snp_match <- function(sumstats, info_snp,
                      strand_flip = TRUE,
                      join_by_pos = TRUE,
                      match.min.prop = 0.5) {

  sumstats$`_NUM_ID_` <- rows_along(sumstats)
  info_snp$`_NUM_ID_` <- rows_along(info_snp)

  join_by <- c("chr", NA, "a0", "a1")
  join_by[2] <- `if`(join_by_pos, "pos", "rsid")

  if (!all(c(join_by, "beta") %in% names(sumstats)))
    stop2("Please use proper names for variables in 'sumstats'. Expected '%s'.",
          paste(c(join_by, "beta"), collapse = ", "))
  if (!all(c(join_by, "pos") %in% names(info_snp)))
    stop2("Please use proper names for variables in 'info_snp'. Expected '%s'.",
          paste(unique(c(join_by, "pos")), collapse = ", "))

  message2("%s variants to be matched.", format(nrow(sumstats), big.mark = ","))

  # augment dataset to match reverse alleles
  if (strand_flip) {
    is_ambiguous <- with(sumstats, paste(a0, a1) %in% c("A T", "T A", "C G", "G C"))
    message2("%s ambiguous SNPs have been removed.",
             format(sum(is_ambiguous), big.mark = ","))
    sumstats2 <- sumstats[!is_ambiguous, ]
    sumstats3 <- sumstats2
    sumstats2$`_FLIP_` <- FALSE
    sumstats3$`_FLIP_` <- TRUE
    sumstats3$a0 <- flip_strand(sumstats2$a0)
    sumstats3$a1 <- flip_strand(sumstats2$a1)
    sumstats3 <- rbind(sumstats2, sumstats3)
  } else {
    sumstats3 <- sumstats
    sumstats3$`_FLIP_` <- FALSE
  }

  sumstats4 <- sumstats3
  sumstats3$`_REV_` <- FALSE
  sumstats4$`_REV_` <- TRUE
  sumstats4$a0 <- sumstats3$a1
  sumstats4$a1 <- sumstats3$a0
  sumstats4$beta <- -sumstats3$beta
  sumstats4 <- rbind(sumstats3, sumstats4)

  matched <- merge(as.data.table(sumstats4), as.data.table(info_snp),
                   by = join_by, all = FALSE, suffixes = c(".ss", ""))
  message2("%s variants have been matched; %s were flipped and %s were reversed.",
           format(nrow(matched),         big.mark = ","),
           format(sum(matched$`_FLIP_`), big.mark = ","),
           format(sum(matched$`_REV_`),  big.mark = ","))

  if (nrow(matched) < (match.min.prop * min(ncol(sumstats), ncol(info_snp))))
    stop2("Not enough variants have been matched.")

  as.data.frame(matched[, c("_FLIP_", "_REV_") := NULL][order(chr, pos)])
}

################################################################################

#' Modify genome build
#'
#' Modify the physical position information of a data frame
#' when converting genome build using executable *liftOver*.
#'
#' @param info_snp A data frame with columns "chr" and "pos".
#' @param liftOver Path to liftOver executable.
#'   Binaries can be downloaded at \url{https://bit.ly/2KvHugi} for Mac
#'   and at \url{https://bit.ly/2TbSaEI} for Linux.
#' @param from Genome build to convert from. Default is `hg18`.
#' @param to Genome build to convert to. Default is `hg19`.
#'
#' @references
#' Hinrichs, Angela S., et al. "The UCSC genome browser database: update 2006."
#' Nucleic acids research 34.suppl_1 (2006): D590-D598.
#'
#' @return Input data frame `info_snp` with column "pos" in the new build.
#' @export
#'
snp_modifyBuild <- function(info_snp, liftOver, from = "hg18", to = "hg19") {

  if (!all(c("chr", "pos") %in% names(info_snp)))
    stop2("Please use proper names for variables in 'info_snp'. Expected %s.",
          "'chr' and 'pos'")

  # Need BED UCSC file for liftOver
  BED <- tempfile(fileext = ".BED")
  info_BED <- with(info_snp, data.frame(
    paste0("chr", chr), pos0 = pos - 1L, pos, id = rows_along(info_snp)))
  bigreadr::fwrite2(info_BED, BED, col.names = FALSE, sep = " ")

  # Make sure liftOver is executable
  make_executable(liftOver)

  # Need chain file
  url <- paste0("ftp://hgdownload.cse.ucsc.edu/goldenPath/", from, "/liftOver/",
                from, "To", tools::toTitleCase(to), ".over.chain.gz")
  chain <- tempfile(fileext = ".over.chain.gz")
  utils::download.file(url, destfile = chain)

  # Run liftOver (usage: liftOver oldFile map.chain newFile unMapped)
  lifted <- tempfile(fileext = ".BED")
  unmaped <- tempfile(fileext = ".txt")
  system(paste(liftOver, BED, chain, lifted, unmaped))

  # readLines(lifted, n = 5)
  new_pos <- bigreadr::fread2(lifted)

  # readLines(unmaped, n = 6)
  bad <- grep("^#", readLines(unmaped), value = TRUE, invert = TRUE)
  message2("%d variants have not been mapped.", length(bad))

  info_snp$pos <- NA
  info_snp$pos[new_pos$V4] <- new_pos$V3
  info_snp
}

################################################################################

#' Determine reference divergence
#'
#' Determine reference divergence while accounting for strand flips.
#' **This does not remove ambiguous alleles.**
#'
#' @param ref1 The reference alleles of the first dataset.
#' @param alt1 The alternative alleles of the first dataset.
#' @param ref2 The reference alleles of the second dataset.
#' @param alt2 The alternative alleles of the second dataset.
#'
#' @return A logical vector whether the references alleles are the same.
#'   Missing values can result from missing values in the inputs or from
#'   ambiguous matching (e.g. matching A/C and A/G).
#' @export
#'
#' @seealso [snp_match()]
#'
#' @examples
#' same_ref(ref1 = c("A", "C", "T", "G", NA),
#'          alt1 = c("C", "T", "C", "A", "A"),
#'          ref2 = c("A", "C", "A", "A", "C"),
#'          alt2 = c("C", "G", "G", "G", "A"))
same_ref <- function(ref1, alt1, ref2, alt2) {

  # ACTG <- c("A", "C", "T", "G")
  # REV_ACTG <- stats::setNames(c("T", "G", "A", "C"), ACTG)
  #
  # decoder <- expand.grid(list(ACTG, ACTG, ACTG, ACTG)) %>%
  #   dplyr::mutate(status = dplyr::case_when(
  #     # BAD: same reference/alternative alleles in a dataset
  #     (Var1 == Var2) | (Var3 == Var4) ~ NA,
  #     # GOOD/TRUE: same reference/alternative alleles between datasets
  #     (Var1 == Var3) & (Var2 == Var4) ~ TRUE,
  #     # GOOD/FALSE: reverse reference/alternative alleles
  #     (Var1 == Var4) & (Var2 == Var3) ~ FALSE,
  #     # GOOD/TRUE: same reference/alternative alleles after strand flip
  #     (REV_ACTG[Var1] == Var3) & (REV_ACTG[Var2] == Var4) ~ TRUE,
  #     # GOOD/FALSE: reverse reference/alternative alleles after strand flip
  #     (REV_ACTG[Var1] == Var4) & (REV_ACTG[Var2] == Var3) ~ FALSE,
  #     # BAD: the rest
  #     TRUE ~ NA
  #   )) %>%
  #   reshape2::acast(Var1 ~ Var2 ~ Var3 ~ Var4, value.var = "status")

  decoder <- structure(
    c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, TRUE,
      NA, NA, FALSE, NA, NA, NA, NA, NA, NA, TRUE, NA, NA, FALSE, NA, NA, NA,
      TRUE, NA, NA, NA, NA, NA, FALSE, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      TRUE, NA, NA, FALSE, NA, NA, TRUE, NA, NA, FALSE, NA, NA, NA, NA, FALSE,
      NA, NA, TRUE, NA, NA, NA, NA, NA, NA, FALSE, NA, NA, TRUE, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, FALSE, NA,
      NA, TRUE, NA, NA, FALSE, NA, NA, TRUE, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, TRUE, NA, NA, NA, NA, NA, FALSE, NA, NA, NA, NA, FALSE, NA, NA, NA,
      NA, NA, TRUE, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, TRUE, NA, NA, FALSE,
      NA, NA, TRUE, NA, NA, FALSE, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, TRUE, NA, NA, FALSE, NA, NA, NA, NA,
      NA, NA, TRUE, NA, NA, FALSE, NA, NA, NA, NA, FALSE, NA, NA, TRUE, NA, NA,
      FALSE, NA, NA, TRUE, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, FALSE, NA,
      NA, NA, NA, NA, TRUE, NA, NA, NA, FALSE, NA, NA, TRUE, NA, NA, NA, NA, NA,
      NA, FALSE, NA, NA, TRUE, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA),
    .Dim = rep(4, 4), .Dimnames = rep(list(c("A", "C", "T", "G")), 4)
  )

  to_decode <- do.call("cbind", lapply(list(ref1, alt1, ref2, alt2), as.character))
  decoder[to_decode]
}

################################################################################