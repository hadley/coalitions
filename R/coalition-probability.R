#' Does a coalition have a majority
#'
#' @param seats_tab A table containing information on how many seats each party
#' obtained.
#' @inheritParams calculate_prob
#' @param seats_majority The number of seats needed to obtain majority.
#' @importFrom rlang .data
#' @keywords internal
has_majority <- function(
  seats_tab,
  coalition,
  seats_majority = 300L) {

  seats_tab %>%
    filter(.data$party %in% coalition) %>%
    group_by(.data$sim) %>%
    summarize(majority = sum(.data$seats) >= seats_majority) %>%
    select(one_of("majority"))

}


#' Do coalitions have a majority
#' @inheritParams has_majority
#' @inheritParams paste_coalitions
#' @inheritParams calculate_probs
#' @param seats_tab A data frame containing number of seats obtained by a party.
#' Must have columns \code{party} and \code{seats}.
#' @importFrom purrr map
#' @importFrom dplyr bind_cols
#' @examples
#' library(coalitions)
#' library(dplyr)
#' library(purrr)
#' # get the latest survey for a sample of German federal election polls
#' surveys <- get_latest(surveys_sample)
#' # check for majorities of two coalitions
#' coals <- list(c("cdu", "fdp"),
#'               c("spd", "left", "greens"))
#' # only use 100 simulations for a fast runtime
#' surveys <- surveys %>% mutate(draws = map(survey, draw_from_posterior, nsim = 100),
#'                               seats = map2(draws, survey, get_seats),
#'                               majorities = map(seats, have_majority, coalitions = coals))
#' surveys$majorities
#' @export
have_majority <- function(
  seats_tab,
  coalitions = list(
    c("cdu"),
    c("cdu", "fdp"),
    c("cdu", "fdp", "greens"),
    c("spd"),
    c("spd", "left"),
    c("spd", "left", "greens")),
  seats_majority = 300L,
  collapse       = "_") {

  assert_data_frame(
    seats_tab,
    types       = c("character", "numeric"),
    any.missing = FALSE,
    min.rows    = 1,
    min.cols    = 2)
  check_subset(c("party", "seats"), names(seats_tab))
  assert_list(
    coalitions,
    types       = "character",
    any.missing = FALSE,
    min.len     = 1,
    unique      = TRUE)
  assert_number(seats_majority, finite = TRUE)

  coalitions <- coalitions %>% map(sort)

  majority_df <- map(
    coalitions,
    has_majority,
    seats_tab = seats_tab,
    seats_majority  = seats_majority) %>% bind_cols()
  colnames(majority_df) <- paste_coalitions(coalitions, collapse = collapse)

  majority_df

}

#' Transform list of coalitions to vector by combining party names
#'
#' @inheritParams calculate_probs
#' @inheritParams base::paste
#' @importFrom purrr map
#' @keywords internal
paste_coalitions <- function(coalitions, collapse="_") {

  coalitions %>%
    map(sort) %>%
    map(paste, collapse = collapse) %>%
    unlist()

}


#' Calculate coalition probability from majority table
#'
#' Given a table with simulations in the rows and coalitions in the columns,
#' this function returns the coalition probabilities for a specified coalition,
#' by default excluding superior coalitions first
#'
#' @param majority_df A data frame containing logical values indicating
#' if the coalitions (columns) have a majority (rows).
#' @param coalition The coalition of interest for which superior coalitions
#' will be obtained by \code{\link[coalitions]{get_superior}}.
#' @param exclude_superior Logical. If \code{TRUE}, superior coalitions will
#' be excluded, otherwise total coalition probabilities will be returned.
#' Usually it makes sense to exclude superior coalitions.
#' @param ... Further arguments passed to \code{\link[coalitions]{get_superior}}
#' @import dplyr checkmate
#' @examples
#'test_df <- data.frame(
#'  cdu            = c(rep(FALSE, 9), TRUE),
#'  cdu_fdp        = c(rep(FALSE, 8), TRUE, TRUE),
#'  cdu_fdp_greens = c(TRUE, TRUE, rep(FALSE, 6), TRUE, TRUE))
#' calculate_prob(test_df, "cdu_fdp_greens") # exclude_superior defaults to TRUE
#' calculate_prob(test_df, "cdu_fdp_greens", exclude_superior=FALSE)
#' @export
calculate_prob <- function(
  majority_df,
  coalition,
  exclude_superior = TRUE,
  ...) {

  assert_data_frame(majority_df, types = "logical")
  assert_string(coalition, min.chars = 1L)
  assert_subset(coalition, names(majority_df))
  assert_flag(exclude_superior)

  n_all <- nrow(majority_df)
  if (exclude_superior) {
    majority_df <- majority_df %>% filter_superior(coalition, ...)
  }

  majority_df %>% summarize_at(coalition, ~sum(.) / n_all * 100)

}

#' Calculate coalition probabilities for multiple coalitions
#'
#' @inherit calculate_prob
#' @param coalitions A list of coalitions for which coalition probabilities should
#' be calculated. Each list entry must be a vector of party names. Those names
#' need to correspond to the names in \code{majority_df}.
#' @importFrom dplyr bind_cols
#' @importFrom purrr map
#' @importFrom tidyr gather
#' @seealso \code{\link[coalitions]{calculate_prob}}
#' @examples
#' test_df <- data.frame(
#'  cdu            = c(rep(FALSE, 9), TRUE),
#'  cdu_fdp        = c(rep(FALSE, 8), TRUE, TRUE),
#'  cdu_fdp_greens = c(TRUE, TRUE, rep(FALSE, 6), TRUE, TRUE))
#' calculate_probs(test_df, list("cdu", "cdu_fdp", "cdu_fdp_greens"))
#' calculate_probs(test_df, list("cdu", "cdu_fdp", "cdu_fdp_greens"), exclude_superior=FALSE)
#' @export
calculate_probs <- function(
  majority_df,
  coalitions,
  exclude_superior = TRUE,
  ...) {

  assert_data_frame(majority_df, types = "logical")
  assert_list(coalitions, types = "character", any.missing = FALSE, min.len = 1,
    unique = TRUE)
  assert_flag(exclude_superior)

  coalitions <- coalitions %>% paste_coalitions()
  coalitions %>% map(
      .f               = calculate_prob,
      majority_df      = majority_df,
      exclude_superior = exclude_superior, ...) %>%
    bind_cols() %>%
    gather("coalition", "probability", one_of(coalitions))

}


#' Remove rows from table for which superior coalitions are possible
#'
#' @inherit calculate_prob
#' @seealso \code{\link[coalitions]{get_superior}}
#' @keywords internal
filter_superior <- function(majority_df, coalition, ...) {

    superior       <- get_superior(coalition, ...)
    superior_names <- intersect(superior, names(majority_df))

    if (length(superior_names) > 0) {
      majority_df %>% filter_at(superior_names, all_vars(!.))
    } else {
      majority_df
    }

}


#' Extract superior coalitions from coalition string or vector
#'
#' @inheritParams stringr::str_split
#' @param collapse string that will be used to concatenate multiple elements
#' obtained by splitting \code{string} to one string.
#' @importFrom magrittr "%>%"
#' @importFrom purrr flatten map map_chr
#' @importFrom utils combn
#' @importFrom stringr str_split
#' @seealso stringr str_split
#' @keywords internal
get_superior <- function(
  string,
  pattern  = "_",
  collapse = "_") {

  party_list <- str_split(string, pattern = pattern) %>% unlist()
  seq_len(length(party_list) -1) %>%
    map(combn, x = party_list, simplify = FALSE) %>%
    flatten() %>%
    map_chr(paste, collapse = collapse)

}

#' Wrapper for calculation of coalition probabilities from survey
#'
#' @inheritParams draw_from_posterior
#' @inheritParams get_seats
#' @inheritParams has_majority
#' @inherit calculate_probs
#' @param x A table containing one row per survey and survey information in
#' long format in a separate column named \code{survey}.
#' @importFrom purrr map map2
#' @importFrom lubridate now
#' @importFrom rlang .data
#' @examples
#' library(coalitions)
#' library(dplyr)
#' # get the latest survey for a sample of German federal election polls
#' surveys <- get_latest(surveys_sample)
#' # calculate probabilities for two coalitions
#' probs <- get_probabilities(surveys,
#'                            coalitions = list(c("cdu", "fdp"),
#'                                              c("spd", "left", "greens")),
#'                            nsim = 100) # ensure fast runtime with only 100 simulations
#' probs %>% tidyr::unnest("probabilities")
#' @export
get_probabilities <- function(
  x,
  coalitions = list(
    c("cdu"),
    c("cdu", "fdp"),
    c("cdu", "fdp", "greens"),
    c("spd"),
    c("spd", "left"),
    c("spd", "left", "greens")),
  nsim           = 1e5,
  distrib.fun    = sls,
  seats_majority = 300L,
  seed           = as.numeric(now()),
  correction     = NULL) {

  x %>%
    mutate(
      draws    = map(.data$survey, draw_from_posterior,
        nsim = nsim, seed = seed, correction = correction),
      seats    = map2(.data$draws, .data$survey, get_seats, distrib.fun = distrib.fun),
      majority = map(
        .data$seats,
        have_majority,
        coalitions     = coalitions,
        seats_majority = seats_majority),
      probabilities = map(.data$majority, calculate_probs, coalitions = coalitions)) %>%
    select(-one_of("draws", "seats", "majority", "survey", "start", "end", "respondents"))

}
