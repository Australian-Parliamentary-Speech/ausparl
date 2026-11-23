# Shared query plumbing: the one argument and filter convention every query function follows.
# Filter constructors, argument validation, filter compilation and the collect step used by every
# query function. Values reach SQL only through dbplyr's DBI escaping; nothing is pasted by hand.

# Size-guard defaults, calibrated on the full database so that a result at the threshold is about
# 1 GB in R.
max_rows_default <- 2e6
max_rows_text_default <- 8e5

chambers <- c("house", "senate")

#' Filter by an inclusive range
#'
#' Builds a range filter for any filter argument of an ausparl function: the column must lie
#' between `from` and `to`, inclusive. Either end may be left open (`NULL`), but not both.
#'
#' Both ends must be of the same kind: numbers (for example years or parliament numbers), or
#' dates given as `Date` objects or `"YYYY-MM-DD"` strings.
#'
#' @param from Lower bound, or `NULL` for no lower bound.
#' @param to Upper bound, or `NULL` for no upper bound.
#' @return An `ausparl_range` object, to pass as a filter argument.
#' @seealso [matches_pattern()]
#' @export
#' @examples
#' in_range(1990, 1996)
#' in_range(from = "2020-01-01")
#' in_range(as.Date("1901-05-09"), as.Date("1901-12-31"))
in_range <- function(from = NULL, to = NULL) {
  from <- range_bound(from, "from")
  to <- range_bound(to, "to")
  if (is.null(from) && is.null(to)) {
    abort_input(c(
      "{.fn in_range} needs at least one bound.",
      "i" = "Supply {.arg from}, {.arg to}, or both."
    ))
  }
  if (!is.null(from) && !is.null(to)) {
    if (!identical(bound_kind(from), bound_kind(to))) {
      abort_input(c(
        "{.arg from} and {.arg to} must be of the same kind.",
        "x" = "{.arg from} is a {bound_kind(from)} and {.arg to} is a {bound_kind(to)}.",
        "i" = "Use two numbers, or two dates ({.cls Date} or {.val YYYY-MM-DD})."
      ))
    }
    if (from > to) {
      abort_input(c(
        "{.arg from} must not be after {.arg to}.",
        "x" = "{.arg from} is {.val {format(from)}} and {.arg to} is {.val {format(to)}}.",
        "i" = "Swap the two bounds."
      ))
    }
  }
  structure(list(from = from, to = to), class = "ausparl_range")
}

#' Filter by a case-insensitive pattern
#'
#' Builds a pattern filter for any filter argument of an ausparl function that holds text.
#' The column is matched with SQL `ILIKE`, ignoring case: `%` matches any run of characters and
#' `_` any single character.
#'
#' @param pattern A single, non-empty string, such as `"%deakin%"`.
#' @return An `ausparl_like` object, to pass as a filter argument.
#' @seealso [in_range()]
#' @export
#' @examples
#' matches_pattern("%deakin%")
matches_pattern <- function(pattern) {
  if (!rlang::is_string(pattern) || !nzchar(pattern)) {
    abort_input(c(
      "{.arg pattern} must be a single, non-empty string.",
      "x" = "It is {.obj_type_friendly {pattern}}.",
      "i" = "For example {.code matches_pattern(\"%deakin%\")}."
    ))
  }
  structure(list(pattern = pattern), class = "ausparl_like")
}

# ---- internals: validation ----------------------------------------------------------------------

range_bound <- function(x, arg, call = rlang::caller_env()) {
  if (is.null(x)) {
    return(NULL)
  }
  if (length(x) == 1 && !is.na(x)) {
    if (inherits(x, "Date")) {
      return(x)
    }
    if (is.numeric(x) && is.finite(x)) {
      return(x)
    }
    if (is.character(x)) {
      date <- parse_date_string(x)
      if (!is.na(date)) {
        return(date)
      }
    }
  }
  abort_input(c(
    "{.arg {arg}} must be a single number, {.cls Date}, or {.val YYYY-MM-DD} string.",
    "x" = "It is {.obj_type_friendly {x}}."
  ), call = call)
}

bound_kind <- function(x) {
  if (inherits(x, "Date")) "date" else "number"
}

parse_date_string <- function(x) {
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) {
    return(as.Date(NA))
  }
  as.Date(x, format = "%Y-%m-%d")
}

is_year <- function(x) {
  is.numeric(x) && length(x) == 1 && !is.na(x) && x == trunc(x) && x >= 1 && x <= 9999
}

# A year expands to 1 January (`from`) or 31 December (`to`); a date or date string is used as
# given. Returns list(from, to) of Dates, each possibly NULL.
date_bounds <- function(from = NULL, to = NULL, call = rlang::caller_env()) {
  as_bound <- function(x, arg, month_day) {
    if (is.null(x)) {
      return(NULL)
    }
    if (is_year(x)) {
      return(as.Date(sprintf("%04d-%s", as.integer(x), month_day)))
    }
    if (length(x) == 1 && inherits(x, "Date") && !is.na(x)) {
      return(x)
    }
    if (rlang::is_string(x) && !is.na(parse_date_string(x))) {
      return(parse_date_string(x))
    }
    abort_input(c(
      "{.arg {arg}} must be a year, a {.cls Date}, or a {.val YYYY-MM-DD} string.",
      "x" = "It is {.obj_type_friendly {x}}.",
      "i" = "For example {.code {arg} = 1990} or {.code {arg} = \"1990-07-01\"}."
    ), call = call)
  }
  from <- as_bound(from, "from", "01-01")
  to <- as_bound(to, "to", "12-31")
  if (!is.null(from) && !is.null(to) && from > to) {
    abort_input(c(
      "{.arg from} must not be after {.arg to}.",
      "x" = "{.arg from} is {.val {format(from)}} and {.arg to} is {.val {format(to)}}.",
      "i" = "Swap the two values."
    ), call = call)
  }
  list(from = from, to = to)
}

# Lowercases a chamber argument and checks it against the stored values.
normalise_chamber <- function(x, call = rlang::caller_env()) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || length(x) == 0 || anyNA(x)) {
    abort_input(c(
      "{.arg chamber} must be {.or {.val {chambers}}}.",
      "x" = "It is {.obj_type_friendly {x}}."
    ), call = call)
  }
  lower <- tolower(x)
  bad <- x[!lower %in% chambers]
  if (length(bad)) {
    abort_input(c(
      "{.arg chamber} must be {.or {.val {chambers}}} (any case).",
      "x" = "Unknown chamber{?s}: {.val {bad}}."
    ), call = call)
  }
  lower
}

select_columns <- function(tbl, columns, call = rlang::caller_env()) {
  if (is.null(columns)) {
    return(tbl)
  }
  valid <- colnames(tbl)
  if (!is.character(columns) || length(columns) == 0 || anyNA(columns)) {
    abort_input(c(
      "{.arg columns} must be a character vector of column names.",
      "x" = "It is {.obj_type_friendly {columns}}.",
      "i" = "Valid columns: {.field {valid}}."
    ), call = call)
  }
  unknown <- setdiff(columns, valid)
  if (length(unknown)) {
    abort_input(c(
      "{.arg columns} names {cli::qty(unknown)}{?a column/columns} that do{?es/} not exist:
       {.val {unknown}}.",
      "i" = "Valid columns: {.field {valid}}."
    ), call = call)
  }
  dplyr::select(tbl, dplyr::all_of(unique(columns)))
}

check_filter_value <- function(value, name, call) {
  ok <- is.atomic(value) && length(value) > 0 && !anyNA(value)
  if (!ok) {
    abort_input(c(
      "{.arg {name}} must be a vector of values without {.val NA}, {.fn in_range}, or
       {.fn matches_pattern}.",
      "x" = "It is {.obj_type_friendly {value}}{if (anyNA(value)) ' containing NA' else ''}.",
      "i" = "Use {.code NULL} for no filter."
    ), call = call)
  }
  if (is.factor(value)) as.character(value) else value
}

check_column <- function(tbl, name, call) {
  if (!name %in% colnames(tbl)) {
    abort_input(
      "{.arg {name}} does not apply here: the table has no column {.field {name}}.",
      call = call
    )
  }
}

# ---- internals: filter compilation --------------------------------------------------------------

# `args` is a named list of filter arguments whose names are the database column spellings.
# Names come only from the calling function's own formals, never from user strings.
filter_args <- function(tbl, args, call = rlang::caller_env()) {
  for (name in names(args)) {
    value <- args[[name]]
    if (is.null(value)) {
      next
    }
    check_column(tbl, name, call)
    col <- rlang::sym(name)
    if (inherits(value, "ausparl_range")) {
      if (!is.null(value$from)) {
        tbl <- dplyr::filter(tbl, !!col >= !!value$from)
      }
      if (!is.null(value$to)) {
        tbl <- dplyr::filter(tbl, !!col <= !!value$to)
      }
    } else if (inherits(value, "ausparl_like")) {
      tbl <- dplyr::filter(tbl, !!rlang::call2("%ILIKE%", col, value$pattern))
    } else {
      value <- check_filter_value(value, name, call)
      tbl <- if (length(value) == 1) {
        dplyr::filter(tbl, !!col == !!value)
      } else {
        dplyr::filter(tbl, !!col %in% !!value)
      }
    }
  }
  tbl
}

# Keeps rows whose [start, end] period overlaps `value` (a year, date, date string or
# in_range()). A NULL end means the period is ongoing.
filter_active_during <- function(tbl, value, start, end, call = rlang::caller_env()) {
  if (is.null(value)) {
    return(tbl)
  }
  bounds <- if (inherits(value, "ausparl_range")) {
    date_bounds(value$from, value$to, call = call)
  } else {
    date_bounds(value, value, call = call)
  }
  check_column(tbl, start, call)
  check_column(tbl, end, call)
  start <- rlang::sym(start)
  end <- rlang::sym(end)
  if (!is.null(bounds$to)) {
    tbl <- dplyr::filter(tbl, !!start <= !!bounds$to)
  }
  if (!is.null(bounds$from)) {
    tbl <- dplyr::filter(tbl, is.na(!!end) | !!end >= !!bounds$from)
  }
  tbl
}

# ---- internals: collection ----------------------------------------------------------------------

check_limit <- function(limit, call) {
  whole <- function(x) {
    is.numeric(x) && length(x) == 1 && is.finite(x) && x >= 1 && x == trunc(x)
  }
  ok <- is.null(limit) || whole(limit)
  if (!ok) {
    abort_input(c(
      "{.arg limit} must be {.code NULL} or a single positive whole number.",
      "x" = "It is {.obj_type_friendly {limit}}."
    ), call = call)
  }
}

# The guard threshold: the text option when `content` is in the result, else the plain one.
size_threshold <- function(columns, call) {
  text <- "content" %in% columns
  opt <- if (text) "ausparl.max_rows_text" else "ausparl.max_rows"
  value <- getOption(opt, if (text) max_rows_text_default else max_rows_default)
  if (!is.numeric(value) || length(value) != 1 || is.na(value) || value < 1) {
    abort_input(c(
      "Option {.code {opt}} must be a single positive number, or {.code Inf} to switch the
       size check off.",
      "x" = "It is {.obj_type_friendly {value}}."
    ), call = call)
  }
  list(option = opt, value = value)
}

# Counts at most `n` rows of the query inside DuckDB; no result rows reach R.
probe_query <- function(tbl, n) {
  dplyr::count(utils::head(tbl, n))
}

probe_rows <- function(tbl, n) {
  dplyr::pull(dplyr::collect(probe_query(tbl, n)), 1)
}

run_query <- function(f, call) {
  tryCatch(f(), error = function(e) {
    abort_db(c(
      "The query failed in DuckDB.",
      "x" = gsub("([{}])", "\\1\\1", conditionMessage(e)),
      "i" = "Check the filter values, or report this if the arguments look right."
    ), call = call)
  })
}

collect_result <- function(tbl, collect = TRUE, limit = NULL, call = rlang::caller_env()) {
  if (!rlang::is_bool(collect)) {
    abort_input("{.arg collect} must be {.code TRUE} or {.code FALSE}.", call = call)
  }
  check_limit(limit, call)
  if (!is.null(limit)) {
    tbl <- utils::head(tbl, as.integer(limit))
  }
  if (!collect) {
    return(tbl)
  }

  threshold <- size_threshold(colnames(tbl), call)
  ceiling_rows <- threshold$value
  if (is.finite(ceiling_rows) && (is.null(limit) || limit > ceiling_rows)) {
    probe_n <- as.integer(min(ceiling_rows + 1, .Machine$integer.max))
    n <- run_query(function() probe_rows(tbl, probe_n), call)
    if (n > ceiling_rows) {
      abort_too_many_rows(ceiling_rows, threshold$option, call)
    }
  }
  run_query(function() tibble::as_tibble(dplyr::collect(tbl)), call)
}

abort_too_many_rows <- function(ceiling_rows, opt, call) {
  abort_input(c(
    "The result has more than {format(ceiling_rows, big.mark = \",\", scientific = FALSE)} rows,
      the ceiling set by option {.code {opt}}.",
    "i" = "Narrow it with filter arguments, or set {.arg limit}.",
    "i" = "Choose {.arg columns} without {.field content}; results without it may have up to
           {.code getOption(\"ausparl.max_rows\")} rows.",
    "i" = "Use {.code collect = FALSE} to keep the query lazy in DuckDB.",
    "i" = "Or raise the ceiling with {.code options({opt} = ...)}; {.code Inf} switches it off."
  ), call = call)
}

.onLoad <- function(libname, pkgname) {
  defaults <- list(
    ausparl.max_rows = max_rows_default,
    ausparl.max_rows_text = max_rows_text_default
  )
  unset <- !names(defaults) %in% names(options())
  if (any(unset)) options(defaults[unset])
  invisible()
}
