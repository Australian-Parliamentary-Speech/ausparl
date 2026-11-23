# Provenance. Values reach SQL only through dbplyr escaping; collection is guarded.
# result_provenance() looks up the `provenance` rows of the sittings in a result. It does not change
# data, and it does not invent identifiers.

#' Source files behind a result
#'
#' Looks up the `provenance` rows, one per source file, for the sittings in `x`: the file
#' `path`, its `sha256` checksum, the parser generation and when it was parsed. Use it to trace
#' a result back to the exact files it was built from.
#'
#' `x` is either a character vector of `sitting_id`s, or any result with a `sitting_id`
#' column, such as the output of [get_speeches()] or [search_speeches_by_terms()]. A
#' result may be a data frame (or tibble) or a lazy table on the package connection, such as
#' one returned with `collect = FALSE`; a lazy table is matched inside DuckDB, without reading
#' it into R. Each distinct sitting is looked up once, and `NA` sitting ids in a result are
#' ignored.
#'
#' A sitting with no `provenance` row gives no row; it is not an error. Stored values are
#' returned unchanged.
#'
#' @param x A character vector of `sitting_id`s, or a data frame or lazy table with a character
#'   `sitting_id` column.
#' @param columns Character vector of `provenance` columns to return; `NULL` returns all.
#' @param collect If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for further
#'   dplyr work.
#' @param limit Maximum number of rows to return, or `NULL` for no limit.
#' @return A tibble with one row per source file and the columns of `provenance` (`path`,
#'   `sha256`, `schema_generation`, `parsed_at`, `input_row_count`, `output_action_count`,
#'   `sitting_id`, `source`); zero rows if no sitting matches. A lazy table if
#'   `collect = FALSE`.
#' @seealso [get_provenance()] to filter `provenance` by any column
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' result_provenance("house_2002-10-15")
#' speeches <- get_speeches(from = 2002, to = 2002, include_text = FALSE)
#' result_provenance(speeches)
#' db_disconnect()
result_provenance <- function(x, columns = NULL, collect = TRUE, limit = NULL) {
  call <- rlang::current_env()
  sittings <- provenance_sittings(x, call)
  tbl <- db_tbl("provenance")
  tbl <- if (inherits(sittings, "tbl_lazy")) {
    dplyr::semi_join(tbl, sittings, by = "sitting_id")
  } else {
    dplyr::filter(tbl, !!rlang::sym("sitting_id") %in% !!sittings)
  }
  tbl <- select_columns(tbl, columns, call = call)
  collect_result(tbl, collect = collect, limit = limit, call = call)
}

# ---- internals: provenance ----------------------------------------------------------------------

provenance_hint <- "Pass sitting ids such as {.val house_1996-05-02}, or a result with a
                    {.field sitting_id} column, such as the output of {.fn get_speeches}."

# Returns the distinct sitting ids to look up: a character vector, or a lazy one-column table
# on the package connection. Raises ausparl_input_error for anything else.
provenance_sittings <- function(x, call) {
  if (inherits(x, "tbl_lazy")) {
    if (!identical(dbplyr::remote_con(x), db_con())) {
      abort_input(c(
        "{.arg x} is a lazy table on another database connection.",
        "i" = "Use a lazy table on the package connection {.code db_con()}, or
               {.code collect()} it first."
      ), call = call)
    }
    check_has_sitting_id(colnames(x), call)
    ids <- dplyr::select(x, "sitting_id")
    proto <- run_query(function() dplyr::collect(utils::head(ids, 0)), call = call)
    check_sitting_id_type(proto$sitting_id, call)
    return(dplyr::distinct(ids))
  }
  if (is.data.frame(x)) {
    check_has_sitting_id(names(x), call)
    ids <- x[["sitting_id"]]
    check_sitting_id_type(ids, call)
    return(unique(ids[!is.na(ids)]))
  }
  if (is.character(x)) {
    if (anyNA(x)) {
      abort_input(c(
        "{.arg x} must not contain {.val NA}.",
        "i" = "Drop the missing sitting ids first."
      ), call = call)
    }
    return(unique(x))
  }
  abort_input(c(
    "{.arg x} must be a character vector of sitting ids, a data frame or a lazy table.",
    "x" = "It is {.obj_type_friendly {x}}.",
    "i" = provenance_hint
  ), call = call)
}

check_has_sitting_id <- function(cols, call) {
  if (!"sitting_id" %in% cols) {
    abort_input(c(
      "{.arg x} has no {.field sitting_id} column.",
      "i" = provenance_hint
    ), call = call)
  }
}

check_sitting_id_type <- function(sitting_id, call) {
  if (!is.character(sitting_id)) {
    abort_input(c(
      "{.field sitting_id} in {.arg x} must be character, not
       {.obj_type_friendly {sitting_id}}.",
      "i" = "Sitting ids look like {.val house_1996-05-02}."
    ), call = call)
  }
}
