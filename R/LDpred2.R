################################################################################

#' @importFrom bigsparser as_SFBM
#' @export
bigsparser::as_SFBM

################################################################################

#' LDpred2
#'
#' LDpred2. Tutorial at \url{https://privefl.github.io/bigsnpr/articles/LDpred2.html}.
#'
#' @inheritParams snp_ldsc2
#' @param corr Sparse correlation matrix as an [SFBM][SFBM-class].
#'   If `corr` is a dsCMatrix or a dgCMatrix, you can use `as_SFBM(corr)`.
#' @param h2 Heritability estimate.
#'
#' @return `snp_ldpred2_inf`: A vector of effects, assuming an infinitesimal model.
#'
#' @export
#'
#' @rdname LDpred2
#'
snp_ldpred2_inf <- function(corr, df_beta, h2) {

  assert_df_with_names(df_beta, c("beta", "beta_se", "n_eff"))
  assert_lengths(rows_along(corr), cols_along(corr), rows_along(df_beta))
  assert_pos(df_beta$beta_se, strict = TRUE)
  assert_pos(h2, strict = TRUE)

  N <- df_beta$n_eff
  scale <- sqrt(N * df_beta$beta_se^2 + df_beta$beta^2)
  beta_hat <- df_beta$beta / scale

  beta_inf <- bigsparser::sp_solve_sym(
    corr, beta_hat, add_to_diag = ncol(corr) / (h2 * N))

  beta_inf * scale
}

################################################################################

#' @param grid_param A data frame with 3 columns as a grid of hyper-parameters:
#'   - `$p`: proportion of causal variants
#'   - `$h2`: heritability (captured by the variants used)
#'   - `$sparse`: boolean, whether a sparse model is sought
#'   They can be run in parallel by changing `ncores`.
#' @param burn_in Number of burn-in iterations.
#' @param num_iter Number of iterations after burn-in.
#' @inheritParams bigsnpr-package
#' @param return_sampling_betas Whether to return all sampling betas (after
#'   burn-in)? This is useful for assessing the uncertainty of the PRS at the
#'   individual level (see \doi{10.1101/2020.11.30.403188}).
#'   Default is `FALSE` (only returns the averaged final vectors of betas).
#'   If `TRUE`, only one set of parameters is allowed.
#'
#' @return `snp_ldpred2_grid`: A matrix of effect sizes, one vector (column)
#'   for each row of `grid_param`. Missing values are returned when strong
#'   divergence is detected. If using `return_sampling_betas`, each column
#'   corresponds to one iteration instead (after burn-in).
#'
#' @export
#'
#' @rdname LDpred2
#'
snp_ldpred2_grid <- function(corr, df_beta, grid_param,
                             burn_in = 50,
                             num_iter = 100,
                             ncores = 1,
                             return_sampling_betas = FALSE) {

  assert_df_with_names(df_beta, c("beta", "beta_se", "n_eff"))
  assert_df_with_names(grid_param, c("p", "h2", "sparse"))
  assert_lengths(rows_along(corr), cols_along(corr), rows_along(df_beta))
  assert_pos(df_beta$beta_se, strict = TRUE)
  assert_pos(grid_param$h2, strict = TRUE)
  assert_cores(ncores)

  N <- df_beta$n_eff
  scale <- sqrt(N * df_beta$beta_se^2 + df_beta$beta^2)
  beta_hat <- df_beta$beta / scale

  if (!return_sampling_betas) {

    # LDpred2-grid models
    beta_gibbs <- ldpred2_gibbs(
      corr      = corr,
      beta_hat  = beta_hat,
      beta_init = rep(0, length(beta_hat)),
      order     = seq_along(beta_hat) - 1L,
      n_vec     = N,
      h2        = grid_param$h2,
      p         = grid_param$p,
      sparse    = grid_param$sparse,
      burn_in   = burn_in,
      num_iter  = num_iter,
      ncores    = ncores
    )

  } else {

    if (nrow(grid_param) != 1)
      stop2("Only one set of parameters is allowed when using 'return_sampling_betas'.")

    # All sampling betas for one LDpred2 model (useful for uncertainty assessment)
    beta_gibbs <- ldpred2_gibbs_one_sampling(
      corr      = corr,
      beta_hat  = beta_hat,
      beta_init = rep(0, length(beta_hat)),
      order     = seq_along(beta_hat) - 1L,
      n_vec     = N,
      h2        = grid_param$h2,
      p         = grid_param$p,
      sparse    = grid_param$sparse,
      burn_in   = burn_in,
      num_iter  = num_iter
    )

  }

  sweep(beta_gibbs, 1, scale, '*')
}

################################################################################

#' @param vec_p_init Vector of initial values for p. Default is `0.1`.
#' @param h2_init Heritability estimate for initialization.
#' @param sparse In LDpred2-auto, whether to also report a sparse solution by
#'   running LDpred2-grid with the estimates of p and h2 from LDpred2-auto, and
#'   sparsity enabled. Default is `FALSE`.
#' @param verbose Whether to print "p // h2" estimates at each iteration.
#' @param report_step Step to report sampling betas (after burn-in and before
#'   unscaling). Nothing is reported by default. If using `num_iter = 500` and
#'   `report_step = 50`, then 10 vectors of betas are reported.
#'
#' @return `snp_ldpred2_auto`: A list (over `vec_p_init`) of lists with
#'   - `$beta_est`: vector of effect sizes
#'   - `$beta_est_sparse` (only when `sparse = TRUE`): sparse vector of effect sizes
#'   - `$sample_beta`: Matrix of sampling betas (see parameter `report_step`)
#'   - `$postp_est`: vector of posterior probabilities of being causal
#'   - `$p_est`: estimate of p, the proportion of causal variants
#'   - `$h2_est`: estimate of the (SNP) heritability (also see [coef_to_liab])
#'   - `$path_p_est`: full path of p estimates (including burn-in);
#'     useful to check convergence of the iterative algorithm
#'   - `$path_h2_est`: full path of h2 estimates (including burn-in);
#'     useful to check convergence of the iterative algorithm
#'   - `$h2_init` and `$p_init`
#'
#' @import foreach
#'
#' @export
#'
#' @rdname LDpred2
#'
snp_ldpred2_auto <- function(corr, df_beta, h2_init,
                             vec_p_init = 0.1,
                             burn_in = 1000,
                             num_iter = 500,
                             sparse = FALSE,
                             verbose = FALSE,
                             report_step = num_iter + 1L,
                             ncores = 1) {

  assert_df_with_names(df_beta, c("beta", "beta_se", "n_eff"))
  assert_lengths(rows_along(corr), cols_along(corr), rows_along(df_beta))
  assert_pos(df_beta$beta_se, strict = TRUE)
  assert_pos(h2_init, strict = TRUE)

  N <- df_beta$n_eff
  scale <- sqrt(N * df_beta$beta_se^2 + df_beta$beta^2)
  beta_hat <- df_beta$beta / scale

  bigparallelr::register_parallel(ncores)

  foreach(p_init = vec_p_init,
          .export = c("ldpred2_gibbs_auto", "ldpred2_gibbs")) %dopar% {

    ldpred_auto <- ldpred2_gibbs_auto(
      corr      = corr,
      beta_hat  = beta_hat,
      beta_init = rep(0, length(beta_hat)),
      order     = seq_along(beta_hat) - 1L,
      n_vec     = N,
      p_init    = p_init,
      h2_init   = h2_init,
      burn_in   = burn_in,
      num_iter  = num_iter,
      verbose   = verbose,
      report_step = report_step
    )
    ldpred_auto$beta_est  <- drop(ldpred_auto$beta_est) * scale
    ldpred_auto$postp_est <- drop(ldpred_auto$postp_est)
    ldpred_auto$h2_init <- h2_init
    ldpred_auto$p_init  <- p_init

    if (sparse) {
      beta_gibbs <- ldpred2_gibbs(
        corr      = corr,
        beta_hat  = beta_hat,
        beta_init = rep(0, length(beta_hat)),
        order     = seq_along(beta_hat) - 1L,
        n_vec     = N,
        h2        = ldpred_auto$h2_est,
        p         = ldpred_auto$p_est,
        sparse    = TRUE,
        burn_in   = 50,
        num_iter  = 100,
        ncores    = 1
      )
      ldpred_auto$beta_est_sparse <- drop(beta_gibbs) * scale
    }

    ldpred_auto
  }
}

################################################################################
