#' @importFrom stats coef
#' @export
coef.praislm <- function(object, ...) object$coefficients

#' @importFrom stats residuals
#' @export
residuals.praislm <- function(object, ...) object$residuals

#' Extracting the autocorrelation parameter
#' 
#' The function `rho` returns the autocorrelation parameter
#' from either a \link{praislm} or a \link{twoStepsBenchmark} object.
#' If `include.rho` is `FALSE`, `rho` returns zero.
#' @usage
#' rho(object)
#' @param object a praislm or twoStepsBenchmark object.
#' @return
#' a double of length 1.
#' @examples
#' benchmark <- twoStepsBenchmark(turnover,construction,include.rho = TRUE); rho(benchmark)
#'
#' @export
rho <- function(object) UseMethod("rho")
#' @export
rho.praislm <- function(object) object$rho

#' @export
model.list.praislm <- function(object) object$model.list

#' Extracting the standard error
#' 
#' The function `se` returns the standard error the coefficients
#' from either a \link{praislm} or a \link{twoStepsBenchmark} object.
#' @usage
#' se(object)
#' @param object a praislm or twoStepsBenchmark object.
#' @return
#' a double, that is named the same way that the coefficients are.
#' If some coefficients are set by the user, they return `NA` as for
#' their standard error.
#' @export
se <- function(object) UseMethod("se")
#' @export
se.praislm <- function(object) object$se

#' @importFrom stats vcov
#' @export
vcov.praislm <- function(object, ...) {
  resc <- residuals(object)-mean(residuals(object))
  n <- length(resc)
  rho <- rho(object)
  epsilon <- c(
    resc[1L]*sqrt(1L-rho^2),
    resc[-1L]-rho*resc[-n]
  )
  epsilon_variance <- as.numeric(crossprod(epsilon)/(df.residual(object)))
  omega_inv <- diag(n)
  diag(omega_inv)[-c(1L,n)] <- 1+rho^2
  diag(omega_inv[1L:(n-1L),2L:n]) <- -rho
  diag(omega_inv[2L:n,1L:(n-1L)]) <- -rho
  
  m <- model.list(object)
  X <- m$X[,!(colnames(m$X) %in% names(m$set.coefficients))]
  if (m$include.differenciation) X <- diff(X)

  epsilon_variance*solve(crossprod(X,omega_inv)%*%X)
}

#' @export
print.praislm <- function(x, digits = max(3L, getOption("digits") - 3L),...) {
  cat("\nCall:\n", paste(deparse(x$call), sep = "\n", collapse = "\n"), 
      "\n\n", sep = "")
  cat("Coefficients:\n")
  print.default(format(coef(x), digits = digits), print.gap = 2L,quote = FALSE)
  cat("\n")
  invisible(x)
}

#' @importFrom stats fitted
#' @export
fitted.praislm <- function(object, ...) object$fitted.values

#' @export
summary.praislm <- function (object, ...) {
  serr <- se(object)
  tval <- coef(object)/serr
  TAB <- cbind(Estimate = coef(object), StdErr = serr, t.value = tval, 
               p.value = 2 * suppressWarnings(pt(-abs(tval), df = object$df)))
  rownames(TAB) <- names(object$coefficients)
  colnames(TAB) <- c("Estimate", "StdErr", "t.value", "p.value")
  mss <- sum(object$fitted.values.decorrelated^2)
  rss <- sum(object$residuals.decorrelated^2)
  r.squared <- mss/(mss + rss)
  n <- length(object$fitted.values.decorrelated)
  rdf <- object$df.residual
  adj.r.squared <- 1 - (1 - r.squared) * n/rdf
  rho <- object$rho
  
  pm <- rbind(residuals=do.call(c,Box.test(object$residuals, lag = 1, type = "Ljung-Box")[c("statistic","p.value")]),
              if (rho != 0) residuals.decorrelated=do.call(c,Box.test(object$residuals.decorrelated, lag = 1, type = "Ljung-Box")[c("statistic","p.value")]))
  colnames(pm) <- c("statistic","p.value")
  
  incdiff <- model.list(object)$include.differenciation
  
  res <- list(call = object$call, coefficients = TAB, r.squared = r.squared, 
              adj.r.squared = adj.r.squared, sigma = sqrt(sum((object$residuals)^2)/rdf), 
              df = object$df, residuals = object$residuals,
              rho=rho,pm=pm,incdiff=incdiff)
  class(res) <- "summary.praislm"
  res
}

#' @export
print.summary.praislm <- function (x, digits=max(3, getOption("digits") - 3),
                                   signif.stars = getOption("show.signif.stars"),
                                   call = TRUE,...) {
  if (call) {
    cat("\nCall:\n")
    print(x$call)
    cat("\n\n")
  }
  
  if (x$incdiff) {
    cat("The model includes a differenciation.","\n\n")
  }
  
  if (x$rho != 0) {
    cat("Autocorrelation parameter (rho): ", formatC(x$rho,digits=digits),"\n\n")
  }
  
  cat("Residuals:\n")
  print(summary(x$residuals, digits = digits)[-4])
  cat("\n")
  printCoefmat(x$coefficients, P.values = TRUE, has.Pvalue = TRUE,digits=digits,signif.stars=signif.stars)
  cat("\nResidual standard error: ", formatC(x$sigma, digits = digits), 
      " on ", formatC(x$df), " degrees of freedom\n", sep = "")
  cat("Multiple R-squared: ", formatC(x$r.squared, digits = digits), 
      ",\tAdjusted R-squared: ", formatC(x$adj.r.squared, digits = digits), 
      "\n", sep = "")
  
  cat("\nPortmanteau:\n")
  pm <- x$pm
  if (x$rho==0) {
    rownames(pm) <- "u"
    mes <- "Where Y=X*C+u"
  } else {
    rownames(pm) <- c("u","epsilon")
    mes <- c("Where Y=X*C+u","Where u=rho*lag(u)+epsilon")
  }

  pm <- formatC(pm,digits=digits)
  if (signif.stars) {
    Signif <- symnum(x$pm[,"p.value"], corr = FALSE, na = FALSE, 
                     cutpoints = c(0, 0.001, 0.01, 0.05, 0.1, 1), 
                     symbols = c("***", "**", "*", ".", " "))
    pm <- cbind(pm, format(Signif))
  }
  pm <- cbind(pm,"||",format(mes))
  print.default(pm, quote = FALSE, right = TRUE,...)
}

#' Extracting the regression of a twoStepsBenchmark
#' 
#' prais is a function which extracts the regression, a praislm object,
#' of a twoStepsBenchmark.
#' 
#' @aliases praislm
#' @param x a twoStepsBenchmark
#' @return
#' prais returns an object of class "`praislm`".
#' 
#' The functions that can be used on that class are almost the same than
#' for the class `twoStepsBenchmark`.
#' `summary`, `coefficients`, `residuals` will return the same values.
#' However, as for `fitted.values`, the accessor returns the fitted values
#' of the regression, not the high-frequency, eventually integrated, time-serie
#' contained in a twoStepsBenchmark.
#' 
#' An object of class "`praislm`" is a list containing the following components :
#'   \item{coefficients}{a named vector of coefficients.}
#'   \item{residuals}{the residuals, that is response minus fitted values.}
#'   \item{fitted.values}{a time-serie, the fitted mean values}
#'   \item{se}{a named vector of standard errors.}
#'   \item{df.residuals}{the residual degrees of freedom.}
#'   \item{rho}{the autocorrelation coefficients of the residuals. It
#'   is equal to zero if twoStepsBenchmark was called with `include.rho=FALSE`}
#'   \item{residuals.decorrelated}{the residuals of the model after having been
#'   transformed by rho in a least square model.}
#'   \item{fitted.values.decorrelated}{the fitted values of the model after having been
#'   transformed by rho in a least square model.}
#' @examples
#' benchmark <- twoStepsBenchmark(turnover,construction); prais(benchmark)
#' @export
prais <- function(x) UseMethod("prais")
#' @export
prais <- function(x) x$regression

#' @importFrom stats as.ts
#' @export
as.ts.twoStepsBenchmark <- function(x, ...) x$benchmarked.serie

#' @importFrom stats coef
#' @export
coef.twoStepsBenchmark <- function(object, ...) coef(prais(object))

#' @importFrom stats residuals
#' @export
residuals.twoStepsBenchmark <- function(object, ...) residuals(prais(object))

#' @importFrom stats vcov
#' @export
vcov.twoStepsBenchmark <- function(object, ...) vcov(prais(object))

#' @importFrom stats fitted
#' @export
fitted.twoStepsBenchmark <- function(object, ...) object$fitted.values

#' Extracting all the arguments submitted to generate an object
#' 
#' The function `model.list` returns the arguments submitted
#' to the function \link{praislm} or a \link{twoStepsBenchmark}.
#' 
#' These are returned as they are after evaluation, model.list doesn't
#' return a call.
#'   
#' @usage
#' model.list(object)
#' @param object a praislm or twoStepsBenchmark object.
#' @return
#' a list containing every evaluated arguments
#' @examples
#' benchmark <- twoStepsBenchmark(turnover,construction); model.list(benchmark)
#'
#' @export
model.list <- function(object) UseMethod("model.list")
#' @export
model.list.twoStepsBenchmark <- function(object) object$model.list

#' Extracting the smoothed part of a twoStepsBenchmark
#' 
#' The function `smoothed.part` returns the smoothed part of a
#' \link{twoStepsBenchmark}. It derives from the residuals of the
#' aggregated regression, with some differences :
#'    * it is eventually integrated if `include.differenciation=TRUE`.
#'    * it is extrapolated to match the domain window.
#'    * it is smoothed with an additive Denton benchmark.
#'   
#' @usage
#' smoothed.part(object)
#' @param object a twoStepsBenchmark object.
#' @return
#' a time-serie
#' @examples
#' benchmark <- twoStepsBenchmark(turnover,construction); smoothed.part(benchmark)
#'
#' @export
smoothed.part <- function(object) UseMethod("smoothed.part")
#' @export
smoothed.part.twoStepsBenchmark <- function(object) object$smoothed.part

#' @export
se.twoStepsBenchmark <- function(object) se(prais(object))

#' @export
rho.twoStepsBenchmark <- function(object) rho(prais(object))

#' @export
print.twoStepsBenchmark <- function(x,...) {
  print(prais(x),...)
  print(as.ts(x))
  invisible(x)
}

#' @export
summary.twoStepsBenchmark <- function(object, ...) {
  summary.praislm(prais(object),...)
}