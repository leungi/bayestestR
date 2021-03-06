#' @importFrom stats cor cor.test
#' @importFrom insight find_parameters
#' @keywords internal
.check_multicollinearity <- function(model, method = "equivalence_test", threshold = 0.7, ...) {
  valid_parameters <- insight::find_parameters(model, parameters = "^(?!(r_|sd_|prior_|cor_|lp__|b\\[))", flatten = TRUE)

  if (inherits(model, "stanfit")) {
    dat <- insight::get_parameters(model)[, valid_parameters]
  } else {
    dat <- as.data.frame(model, optional = FALSE)[, valid_parameters]
  }
  dat <- dat[, -1, drop = FALSE]

  if (ncol(dat) > 1) {
    parameter_correlation <- stats::cor(dat)
    parameter <- expand.grid(colnames(dat), colnames(dat), stringsAsFactors = FALSE)

    results <- cbind(
      parameter,
      corr = abs(as.vector(expand.grid(parameter_correlation)[[1]])),
      pvalue = apply(parameter, 1, function(r) stats::cor.test(dat[[r[1]]], dat[[r[2]]])$p.value)
    )

    # Filter
    results <- results[results$pvalue < 0.05 & results$Var1 != results$Var2, ]

    if (nrow(results) > 0) {

      # Remove duplicates
      results$where <- paste0(results$Var1, " and ", results$Var2)
      results$where2 <- paste0(results$Var2, " and ", results$Var1)
      to_remove <- c()
      for (i in 1:nrow(results)) {
        if (results$where2[i] %in% results$where[1:i]) {
          to_remove <- c(to_remove, i)
        }
      }
      results <- results[-to_remove, ]

      # Filter by first threshold
      threshold <- ifelse(threshold >= .9, .9, threshold)
      results <- results[results$corr > threshold & results$corr <= .9, ]
      if (nrow(results) > 0) {
        where <- paste0("between ", paste0(paste0(results$where, " (r = ", round(results$corr, 2), ")"), collapse = ", "), "")
        message("Possible multicollinearity ", where, ". This might lead to inappropriate results. See 'Details' in '?", method, "'.")
      }

      # Filter by second threshold
      results <- results[results$corr > .9, ]
      if (nrow(results) > 0) {
        where <- paste0("between ", paste0(paste0(results$where, " (r = ", round(results$corr, 2), ")"), collapse = ", "), "")
        warning("Probable multicollinearity ", where, ". This might lead to inappropriate results. See 'Details' in '?", method, "'.", call. = FALSE)
      }
    }
  }
}
