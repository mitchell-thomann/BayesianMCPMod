## BayesianMCPMod -----------------------------------------

#' @export
print.BayesianMCPMod <- function (

  x,
  ...

) {

  print(x$BayesianMCP)
  
  if (any(!is.na(attr(x, "MED")))) {
    
    i = 1
    while (is.null(x$Mod[[i]])) {
      i <- i + 1
    }
    dose_levels <- x$Mod[[i]]$linear$dose_levels[-1]
    rm(i)
    
    med_info <- attr(x, "MED")
    
    med_table      <- table(factor(med_info[, "med"], levels = dose_levels), useNA = "always")
    med_vec        <- as.vector(med_table)
    med_vec_names <- names(med_table)
    
    print_width <- max(nchar(med_vec), nchar(med_vec_names), na.rm = TRUE) + 2
    
    cat("MED Dose Frequencies\n")
    cat("  Selection Method:    ", attr(x, "MEDSelection"), "\n")
    cat("  Identification Rate: ", mean(med_info[, "med_reached"]), "\n")
    
    cat(" ", format(med_vec_names, width = print_width, justify = "right"), "\n")
    cat(" ", format(med_vec, width = print_width))
    
  }
  
  cat("\n")

}

## BayesianMCP --------------------------------------------

#' @export
print.BayesianMCP <- function(x, ...) {
  #cat("Bayesian Multiple Comparison Procedure\n\n")
  n_sim <- nrow(x)
  #cat("Effective Sample Size (ESS) per Dose Group:\n")
  #print(attr(x, "ess_avg"), row.names = FALSE)
  #cat("\n")
  cat("Bayesian Multiple Comparison Procedure\n")

  if (n_sim == 1L) {

    cat("Summary:\n")
    cat("  Sign:", x[1, "sign"], "\n")
    cat("  Critical Probability:", x[1, "crit_prob_adj"], "\n")
    cat("  Maximum Posterior Probability:", x[1, "max_post_prob"], "\n\n")
    
    attr(x, "critProbAdj") <- NULL
    attr(x, "successRate") <- NULL
    class(x)               <- NULL
    cat("Posterior Probabilities for Model Shapes:\n")
    model_probs <- x[1, grep("^post_probs\\.", colnames(x))]
    model_names <- gsub("post_probs\\.", "", names(model_probs))
    model_df <- data.frame(Model = model_names, Probability = unlist(model_probs))
    print(model_df, row.names = FALSE)
    
   # print.default(x, ...)

    if (any(!is.na(attr(x, "essAvg")))) {

      cat("Average Posterior ESS\n")
      print(attr(x, "essAvg"), ...)

    }

  } else {

    model_successes <- getModelSuccesses(x)

    cat("  Estimated Success Rate: ", attr(x, "successRate"), "\n")
    cat("  N Simulations:          ", n_sim)

    cat("\n")
    cat("Model Significance Frequencies\n")
    print(model_successes, ...)

  }

  invisible(x)
  
}


## ModelFits ----------------------------------------------

#' @title predict.modelFits
#' @description This function performs model predictions based on the provided
#' model and dose specifications
#'
#' @param object A modelFits object containing information about the fitted
#' model coefficients
#' @param doses A vector specifying the doses for which a prediction should be
#' done
#' @param ... Currently without function
#' @examples
#' posterior_list <- list(Ctrl = RBesT::mixnorm(comp1 = c(w = 1, m = 0, s = 1), sigma = 2),
#'                        DG_1 = RBesT::mixnorm(comp1 = c(w = 1, m = 3, s = 1.2), sigma = 2),
#'                        DG_2 = RBesT::mixnorm(comp1 = c(w = 1, m = 4, s = 1.5), sigma = 2) ,
#'                        DG_3 = RBesT::mixnorm(comp1 = c(w = 1, m = 6, s = 1.2), sigma = 2) ,
#'                        DG_4 = RBesT::mixnorm(comp1 = c(w = 1, m = 6.5, s = 1.1), sigma = 2))
#' models         <- c("emax", "exponential", "sigEmax", "linear")
#' dose_levels    <- c(0, 1, 2, 4, 8)
#' fit            <- getModelFits(models      = models,
#'                                posterior   = posterior_list,
#'                                dose_levels = dose_levels)
#'
#' predict(fit, doses = c(0, 1, 3, 4, 6, 8))
#'
#' @return a list with the model predictions for the specified models and doses
#'
#' @export
predict.modelFits <- function (

  object,
  doses = NULL,
  ...

) {
  
  model_fits  <- object
  
  model_names <- names(model_fits)

  predictions <- lapply(model_fits[model_names != "avgFit"],
                        predictModelFit, doses = doses)
  
  if ("avgFit" %in% model_names) {
    
    preds_avg_fit <- predictAvgFit(model_fits, doses = doses)
    
    predictions <- c(predictions, list(avgFit = preds_avg_fit))
    
  }
  
  attr(predictions, "doses") <- doses

  return (predictions)

}

#' @export
print.modelFits <- function (

  x,
  n_digits = 1,
  ...

) {

  dose_levels <- x[[1]]$dose_levels
  dose_names  <- names(attr(x, "posterior"))

  predictions <- t(sapply(x, function (y) y$pred_values))
  colnames(predictions) <- dose_names

  out_table <- data.frame(predictions,
                          mEff = sapply(x, function (y) y$max_effect),
                          gAIC = sapply(x, function (y) y$gAIC),
                          w    = sapply(x, function (y) y$model_weight))

  if (!is.null(x[[1]]$significant)) {

    model_sig      <- TRUE
    out_table$Sign <- sapply(x, function (y) y$significant)

  } else {
    
    model_sig <- FALSE
    
  }
  
  out_table <- apply(as.matrix(out_table), 2, round, digits = n_digits)

  model_names <- names(x) |>
    gsub("exponential", "exponential", x = _) |>
    gsub("quadratic",   "quadratic  ", x = _) |>
    gsub("linear",      "linear     ", x = _) |>
    gsub("logistic",    "logistic   ", x = _) |>
    gsub("emax",        "emax       ", x = _) |>
    gsub("avgFit",      "avgFit     ", x = _) |>
    gsub("sigEmax",     "sigEmax    ", x = _)

  cat("Model Coefficients\n")
  for (i in seq_along(model_names)) {
    
    if (model_names[i] != "avgFit     ") {
      
      coeff_values <- x[[i]]$coeff
      coeff_names  <- names(coeff_values)
      
      cat(model_names[i],
          paste(coeff_names, round(coeff_values, n_digits),
                sep      = " = ",
                collapse = ", "), "\n",
          sep = " ")
      
    }

  }
  
  cat("\n")
  cat("Dose Levels\n",
      paste(dose_names, round(dose_levels, n_digits),
            sep      = " = ",
            collapse = ", "), "\n")
  cat("\n")
  cat("Predictions, Maximum Effect, gAIC")
  
  if (model_sig) {
    
    cat(", Model Weights & Significance\n")
    
  } else {
    
    cat(" & Model Weights\n")
    
  }
  
  print(out_table, ...)

}

## plot.ModelFits()
## see file R/plot.R

## postList -----------------------------------------------

#' @export
summary.postList <- function (

  object,
  ...

) {

  summary_list        <- lapply(object, summary, ...)
  names(summary_list) <- names(object)
  summary_tab         <- do.call(rbind, summary_list)

  return (summary_tab)

}

#' @export
print.postList <- function (

  x,
  ...

) {

  getMaxDiff <- function (

    medians

  ) {

    diffs <- medians - medians[1]

    max_diff       <- max(diffs)
    max_diff_level <- which.max(diffs) - 1

    out <- c(max_diff, max_diff_level)
    names(out) <- c("max_diff", "DG")

    return (out)

  }

  summary_tab <- summary.postList(x)

  names(x) <- rownames(summary_tab)
  class(x) <- NULL

  list_out <- list(summary_tab, getMaxDiff(summary_tab[, 4]), x)
  names(list_out) <- c("Summary of Posterior Distributions",
                       "Maximum Difference to Control and Dose Group",
                       "Posterior Distributions")

  print(list_out, ...)

}

