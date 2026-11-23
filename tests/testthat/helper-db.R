# Shared test helpers. Tests use only the bundled sample DB: no network, no full database.

sample_db_path <- function() {
  path <- system.file("extdata", "ausparl-sample.duckdb", package = "ausparl")
  if (!nzchar(path)) stop("bundled sample DB not found")
  path
}

# A raw read-only DBI connection to the sample, independent of db_connect().
local_sample_con <- function(env = parent.frame()) {
  con <- DBI::dbConnect(
    duckdb::duckdb(), dbdir = sample_db_path(), read_only = TRUE, shared_home = FALSE
  )
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  con
}

# A writable temp copy of the sample, edited with `sql`, for version tests.
local_sample_copy <- function(sql, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  file.copy(sample_db_path(), path)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  for (s in sql) DBI::dbExecute(con, s)
  DBI::dbDisconnect(con, shutdown = TRUE)
  path
}

skip_if_no_full_db <- function() {
  testthat::skip_on_cran()
  path <- Sys.getenv("AUSPARL_DB")
  testthat::skip_if(!nzchar(path) || !file.exists(path), "AUSPARL_DB not set to a full database")
  path
}

# Grain check: `key` (column names) identifies at most one row of `lazy_tbl`. Both counts run
# inside DuckDB; only two numbers reach R.
expect_unique_key <- function(lazy_tbl, key) {
  act <- testthat::quasi_label(rlang::enquo(lazy_tbl), arg = "lazy_tbl")
  n_rows <- dplyr::pull(dplyr::collect(dplyr::count(lazy_tbl)))
  n_keys <- lazy_tbl |>
    dplyr::distinct(dplyr::across(dplyr::all_of(key))) |>
    dplyr::count() |>
    dplyr::collect() |>
    dplyr::pull()
  testthat::expect(
    n_rows == n_keys,
    sprintf(
      "%s has %s rows but %s distinct values of key (%s).",
      act$lab, n_rows, n_keys, paste(key, collapse = ", ")
    )
  )
  invisible(act$val)
}
