#' Seat Distribution by Sainte-Lague/Schepers
#'
#' Calculates number of seats for the respective parties that have received more
#' than 5\% of votes (according to the method of Sainte-Lague/Schepers,
#' see https://www.wahlrecht.de/verfahren/rangmasszahlen.html).
#'
#' @param votes A numeric vector giving the redistributes votes
#' @param parties A character vector indicating the names of parties with
#' respective \code{votes}.
#' @param n_seats The total number of seats that can be assigned to the different
#' parties.
#' @return A numeric vector giving the number of seats each party obtained.
#' @import dplyr
#' @importFrom tidyr gather
#' @seealso \code{\link{dHondt}}
#' @examples
#' library(coalitions)
#' library(dplyr)
#' # get the latest survey for a sample of German federal election polls
#' surveys <- get_latest(surveys_sample) %>% tidyr::unnest("survey")
#' # calculate the seat distribution based on Sainte-Lague/Schepers for a parliament with 300 seats
#' sls(surveys$votes, surveys$party, n_seats = 300)
#' @export
sls <- function(
  votes,
  parties,
  n_seats   = 598L) {

  # attention: .div_mat is an internal object. see data_raw/internals.R
  divisor.mat <- sum(votes) / t(.div_mat[seq_along(votes), ] * votes)
  colnames(divisor.mat) <- parties
  m.mat <- tidyr::gather(as.data.frame(divisor.mat), key="name", value="seats",
    everything())
  m.mat     <- m.mat[rank(m.mat$seats, ties.method = "random") <= n_seats, ]
  rle.seats <- rle(m.mat$name)

  if (sum(rle.seats$length) != n_seats)
    stop(paste("Number of seats distributed not equal to", n_seats))

  rle.seats$length

}
