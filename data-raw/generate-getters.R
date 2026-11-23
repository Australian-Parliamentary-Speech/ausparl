# Generates R/query-tables.R: the single-table getters get_<table>(). The generated file is
# never edited by hand; change this script or data-raw/getter-spec.R and re-run it.
#
# Usage, from the package root:
#   Rscript data-raw/generate-getters.R                  # catalog from the bundled sample DB
#   Rscript data-raw/generate-getters.R "$AUSPARL_DB"    # catalog from another hansard.duckdb
#   make document
#
# Columns come from the database catalog (information_schema.columns); the display view,
# active_during columns, titles and examples come from data-raw/getter-spec.R. The database is
# opened read-only. Output is deterministic: the same catalog and spec give the same bytes.
# Never hand-edit R/query-tables.R; change this script or the spec and regenerate.

# Body-local names a filter column must never shadow, and the getters' common arguments.
reserved_names <- c(
  "active_during", "display", "columns", "collect", "limit", "call", "filters", "tbl"
)

# Free-text columns are never filter arguments: text is matched by search, not by equality.
is_filter_column <- function(x) x != "content" & !grepl("_raw$", x)

read_catalog <- function(db) {
  if (!file.exists(db)) stop("Database not found: ", db, call. = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db, read_only = TRUE, shared_home = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  columns <- DBI::dbGetQuery(con, "
    SELECT table_name, column_name, data_type, ordinal_position
    FROM information_schema.columns
    WHERE table_schema = 'main'
    ORDER BY table_name, ordinal_position
  ")
  schema <- DBI::dbGetQuery(con, "SELECT schema_version FROM schema_version LIMIT 1")
  list(columns = columns, schema_version = as.character(schema$schema_version))
}

table_columns <- function(catalog, table) {
  cols <- catalog$columns[catalog$columns$table_name == table, , drop = FALSE]
  if (!nrow(cols)) stop("Table or view not in the catalog: ", table, call. = FALSE)
  cols[order(cols$ordinal_position), c("column_name", "data_type")]
}

# Greedy word wrap that keeps spacing exactly as written (unlike strwrap()).
wrap <- function(text, first, rest = first, width = 100) {
  words <- strsplit(text, " ", fixed = TRUE)[[1]]
  lines <- character()
  line <- first
  fresh <- TRUE
  for (word in words) {
    candidate <- if (fresh) paste0(line, word) else paste(line, word)
    if (!fresh && nchar(candidate) > width) {
      lines <- c(lines, line)
      line <- paste0(rest, word)
    } else {
      line <- candidate
    }
    fresh <- FALSE
  }
  c(lines, line)
}

roxygen <- function(text) wrap(text, "#' ")
roxygen_param <- function(name, text) wrap(paste0("@param ", name, " ", text), "#' ", "#'   ")

check_spec <- function(table, spec, catalog, filters) {
  clash <- intersect(filters, reserved_names)
  if (length(clash)) {
    stop("Column(s) of ", table, " clash with getter arguments: ", toString(clash), call. = FALSE)
  }
  if (!is.null(spec$display)) {
    view_cols <- table_columns(catalog, spec$display)$column_name
    missing <- setdiff(filters, view_cols)
    if (length(missing)) {
      stop(spec$display, " lacks filter column(s) ", toString(missing), call. = FALSE)
    }
  }
  if (!is.null(spec$active_during)) {
    missing <- setdiff(spec$active_during, table_columns(catalog, table)$column_name)
    if (length(missing)) {
      stop(table, " lacks active_during column(s) ", toString(missing), call. = FALSE)
    }
  }
}

render_docs <- function(table, spec, cols, filters) {
  fn <- paste0("get_", table)
  source_text <- if (is.null(spec$display)) {
    sprintf("Reads the `%s` table: one row per %s.", table, spec$grain)
  } else {
    sprintf(
      "Reads the `%s` table, or the `%s` view with `display = TRUE`: one row per %s.",
      table, spec$display, spec$grain
    )
  }
  filter_text <- paste(
    "Every column except `content` and `*_raw` columns is a filter argument, spelt as in the",
    "database. Each takes `NULL` (no filter, the default), a vector of values to match,",
    "[in_range()] for an inclusive range, or [matches_pattern()] for a case-insensitive pattern.",
    "Filters combine with AND. Stored values are returned unchanged, and no other filter",
    "is applied."
  )
  params <- unlist(lapply(filters, function(col) {
    type <- cols$data_type[cols$column_name == col]
    text <- if (col == "chamber") {
      sprintf(
        "Filter on `chamber` (`%s`): `\"house\"` and/or `\"senate\"`, in any case.",
        type
      )
    } else {
      sprintf("Filter on column `%s` (`%s`).", col, type)
    }
    roxygen_param(col, text)
  }))
  params <- c(params, roxygen_param(
    "...", "Must be empty. It forces the arguments after it to be named."
  ))
  if (!is.null(spec$active_during)) {
    params <- c(params, roxygen_param("active_during", sprintf(paste(
      "Keep rows whose period overlaps this: a year, a date (`Date` or `\"YYYY-MM-DD\"`), or",
      "an [in_range()] of years or dates. The period runs from `%s` to `%s`; a missing",
      "`%s` means it is ongoing. `NULL` (the default) applies no date filter."
    ), spec$active_during[1], spec$active_during[2], spec$active_during[2])))
  }
  if (!is.null(spec$display)) {
    params <- c(params, roxygen_param("display", sprintf(paste(
      "If `TRUE`, read the `%s` view, which adds display columns to the table's own.",
      "Filters still apply."
    ), spec$display)))
  }
  params <- c(
    params,
    roxygen_param("columns", "Character vector of columns to return; `NULL` returns all."),
    roxygen_param(
      "collect",
      "If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for further dplyr work."
    ),
    roxygen_param("limit", "Maximum number of rows to return, or `NULL` for no limit.")
  )
  returns <- sprintf(paste(
    "A tibble with one row per %s and every column of `%s`%s (zero rows if nothing",
    "matches), or a lazy table if `collect = FALSE`."
  ), spec$grain, table, if (is.null(spec$display)) "" else sprintf(" (or of `%s`)", spec$display))

  c(
    paste0("#' ", spec$title),
    "#'",
    roxygen(paste(source_text, spec$purpose)),
    "#'",
    roxygen(filter_text),
    "#'",
    roxygen(paste(
      "Generated from the database catalog by `data-raw/generate-getters.R`; for tables without",
      "a getter use [db_tbl()]."
    )),
    "#'",
    params,
    wrap(paste("@return", returns), "#' ", "#'   "),
    "#' @seealso [in_range()], [matches_pattern()], [db_tbl()]",
    "#' @export",
    "#' @examples",
    "#' db_connect(sample = TRUE)",
    paste0("#' ", fn, "(", spec$example, ")"),
    "#' db_disconnect()"
  )
}

render_body <- function(table, spec, filters) {
  fn <- paste0("get_", table)
  formals <- c(
    paste0(filters, " = NULL"),
    "...",
    if (!is.null(spec$active_during)) "active_during = NULL",
    if (!is.null(spec$display)) "display = FALSE",
    "columns = NULL",
    "collect = TRUE",
    "limit = NULL"
  )
  formals <- c(paste0("  ", formals, c(rep(",", length(formals) - 1), "")), ") {")

  check_args <- c(
    "filters",
    "...length()",
    if (!is.null(spec$active_during)) "active_during = active_during",
    if (!is.null(spec$display)) "display = display",
    "collect = collect",
    "limit = limit",
    "call = call"
  )
  source_line <- if (is.null(spec$display)) {
    sprintf("  tbl <- db_tbl(\"%s\")", table)
  } else {
    sprintf("  tbl <- db_tbl(if (display) \"%s\" else \"%s\")", spec$display, table)
  }

  check_call <- paste0("  check_getter_args(", paste(check_args, collapse = ", "), ")")
  if (nchar(check_call) > 100) {
    check_call <- c(
      "  check_getter_args(",
      paste0("    ", check_args, c(rep(",", length(check_args) - 1), "")),
      "  )"
    )
  }

  c(
    paste0(fn, " <- function("),
    formals,
    "  call <- rlang::current_env()",
    "  filters <- list(",
    paste0("    ", filters, " = ", filters, c(rep(",", length(filters) - 1), "")),
    "  )",
    check_call,
    source_line,
    if ("chamber" %in% filters) "  filters$chamber <- normalise_chamber(chamber, call = call)",
    "  tbl <- filter_args(tbl, filters, call = call)",
    if (!is.null(spec$active_during)) {
      sprintf(
        "  tbl <- filter_active_during(tbl, active_during, \"%s\", \"%s\", call = call)",
        spec$active_during[1], spec$active_during[2]
      )
    },
    "  tbl <- select_columns(tbl, columns, call = call)",
    "  collect_result(tbl, collect = collect, limit = limit, call = call)",
    "}"
  )
}

render_getter <- function(table, spec, catalog) {
  cols <- table_columns(catalog, table)
  filters <- cols$column_name[is_filter_column(cols$column_name)]
  check_spec(table, spec, catalog, filters)
  c(render_docs(table, spec, cols, filters), render_body(table, spec, filters))
}

# Entry validation shared by every getter. Emitted verbatim into the generated file.
helper_lines <- c(
  "# Entry validation shared by the getters above: runs before any query is built.",
  "check_getter_args <- function(filters, n_dots, active_during = NULL, display = FALSE,",
  "                              collect = TRUE, limit = NULL, call = rlang::caller_env()) {",
  "  if (n_dots > 0) {",
  "    abort_input(c(",
  "      \"{n_dots} argument{?s} did not match a filter column.\",",
  "      \"i\" = \"Name filter arguments exactly as the database column; the help page lists",
  "             them.\"",
  "    ), call = call)",
  "  }",
  "  for (name in names(filters)) {",
  "    value <- filters[[name]]",
  "    if (!is.null(value) && !inherits(value, c(\"ausparl_range\", \"ausparl_like\"))) {",
  "      check_filter_value(value, name, call)",
  "    }",
  "  }",
  "  if (inherits(active_during, \"ausparl_range\")) {",
  "    date_bounds(active_during$from, active_during$to, call = call)",
  "  } else if (!is.null(active_during)) {",
  "    date_bounds(active_during, active_during, call = call)",
  "  }",
  "  if (!rlang::is_bool(display)) {",
  "    abort_input(c(",
  "      \"{.arg display} must be {.code TRUE} or {.code FALSE}.\",",
  "      \"x\" = \"It is {.obj_type_friendly {display}}.\"",
  "    ), call = call)",
  "  }",
  "  if (!rlang::is_bool(collect)) {",
  "    abort_input(\"{.arg collect} must be {.code TRUE} or {.code FALSE}.\", call = call)",
  "  }",
  "  check_limit(limit, call)",
  "  invisible()",
  "}"
)

# Returns the full text of R/query-tables.R as one string.
generate_getters <- function(root = ".", db = NULL) {
  if (is.null(db)) db <- file.path(root, "inst", "extdata", "ausparl-sample.duckdb")
  spec_env <- new.env()
  sys.source(file.path(root, "data-raw", "getter-spec.R"), envir = spec_env)
  spec <- spec_env$getter_spec
  catalog <- read_catalog(db)

  header <- c(
    "# Generated by data-raw/generate-getters.R -- do not edit by hand.",
    sprintf(
      "# Catalog: schema %s. Regenerate with `Rscript data-raw/generate-getters.R`, then",
      catalog$schema_version
    ),
    "# `make document`."
  )
  getters <- lapply(names(spec), function(table) {
    c("", render_getter(table, spec[[table]], catalog))
  })
  lines <- c(header, unlist(getters), "", helper_lines)
  paste0(paste(lines, collapse = "\n"), "\n")
}

write_getters <- function(root = ".", db = NULL) {
  text <- generate_getters(root, db)
  path <- file.path(root, "R", "query-tables.R")
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(text), con)
  message("Wrote ", path, ". Now run `make document`.")
  invisible(path)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  write_getters(db = if (length(args)) args[[1]] else NULL)
}
