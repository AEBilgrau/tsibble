#' Prepare to aggregate over time and update index
#'
#' In spirit of `group_by()`, `index_by()` prepares for a new index of the same
#' size but with a less granular period of time. It captures the expression only,
#' and will be evaluated within the next function call. The following operation
#' is applied to each group of the index, created via `index_by()`. Use 
#' `ungroup()` to remove the `index_by()`.
#'
#' @param .data A `tbl_ts`.
#' @param ... 
#' * A single name-value pair of expression: a new index on LHS and the current 
#' index on RHS 
#' * An existing variable to be used as index
#' The index functions that can be used, but not limited:
#' * [lubridate::year]: yearly aggregation
#' * [yearquarter]: quarterly aggregation
#' * [yearmonth]: monthly aggregation
#' * [yearweek]: weekly aggregation
#' * [as.Date] or [lubridate::as_date]: daily aggregation
#' * [lubridate::ceiling_date], [lubridate::floor_date], or [lubridate::round_date]: 
#' sub-daily aggregation
#' * other index functions from other packages
#'
#' @details
#' * A `index_by()`-ed tsibble is indicated by `@` followed by a promise in the 
#' "Groups" when displaying on the screen.
#' * Time index will not be collapsed by `summarise.tbl_ts`.
#' * The scoped variants of `summarise()` only operate on the non-key and 
#' non-index variables.
#'
#' @rdname index-by
#' @export
#' @examples
#' # Monthly counts across sensors ----
#' monthly_ped <- pedestrian %>% 
#'   group_by(Sensor) %>% 
#'   index_by(Year_Month = yearmonth(Date_Time)) %>%
#'   summarise(
#'     Max_Count = max(Count),
#'     Min_Count = min(Count)
#'   )
#' monthly_ped
#' index(monthly_ped)
#' 
#' # Using existing variable ----
#' pedestrian %>% 
#'   group_by(Sensor) %>% 
#'   index_by(Date) %>%
#'   summarise(
#'     Max_Count = max(Count),
#'     Min_Count = min(Count)
#'   )
#'
#' # Annual trips by Region and State ----
#' tourism %>% 
#'   index_by(Year = lubridate::year(Quarter)) %>% 
#'   group_by(Region | State) %>% 
#'   summarise(Total = sum(Trips))
index_by <- function(.data, ...) {
  UseMethod("index_by")
}

#' @export
index_by.tbl_ts <- function(.data, ...) {
  exprs <- enexprs(..., .named = TRUE)
  if (is_false(has_length(exprs, 1))) {
    abort("`index_by()` only accepts one expression")
  }
  build_tsibble(
    .data, key = key(.data), index = !! index(.data), index2 = exprs,
    groups = groups(.data), regular = is_regular(.data), validate = FALSE,
    ordered = is_ordered(.data), interval = interval(.data)
  )
}

index_rename <- function(.data, ...) {
  quos <- enquos(...)
  idx <- index(.data)
  rhs <- purrr::map_chr(quos, quo_get_expr)
  lhs <- names(rhs)
  idx_chr <- quo_text2(idx)
  idx_pos <- match(idx_chr, rhs)
  new_idx_chr <- lhs[idx_pos]
  idx2 <- index2(.data)
  if (is.na(idx_pos)) {
    new_idx_chr <- idx_chr
  }
  cn <- names(.data)
  dat_idx_pos <- match(idx_chr, cn)
  names(.data)[dat_idx_pos] <- new_idx_chr
  if (!is_empty(idx2)) {
    idx2_chr <- names(idx2)
    idx2_pos <- match(idx2_chr, rhs)
    new_idx2_chr <- lhs[idx2_pos]
    first_expr <- idx2[[1]]
    if (is_symbol(first_expr)) {
      first_expr <- sym(new_idx2_chr)
    }
    idx2 <- exprs(!! new_idx2_chr := !! first_expr)
    dat_idx2_pos <- match(idx2_chr, cn)
    names(.data)[dat_idx2_pos] <- new_idx2_chr
  }
  build_tsibble(
    .data, key = key(.data), index = !! sym(new_idx_chr), index2 = idx2, 
    groups = groups(.data), regular = is_regular(.data), 
    validate = FALSE, ordered = is_ordered(.data), interval = interval(.data)
  )
}

# update from call to symbol in RHS
index2_update <- function(.data) {
  idx2 <- index2(.data)
  if (is_empty(idx2)) {
    return(.data)
  } else {
    idx2_chr <- names(idx2)
    idx2_sym <- sym(idx2_chr)
    attr(.data, "index2") <- exprs(!! idx2_chr := !! idx2_sym)
    .data
  }
}