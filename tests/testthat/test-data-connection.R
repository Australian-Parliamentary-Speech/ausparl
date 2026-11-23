# Unit tests for the connection lifecycle. Sample DB only; no network.

local_db_disconnect <- function(env = parent.frame()) {
  withr::defer(db_disconnect(), envir = env)
}

test_that("T-4.6 C1: connect, lazy reconnect, disconnect", {
  local_db_disconnect()
  withr::local_envvar(AUSPARL_DB = NA)

  con <- db_connect(sample = TRUE)
  expect_true(DBI::dbIsValid(con))
  expect_identical(db_con(), con)

  expect_true(db_disconnect())
  expect_false(DBI::dbIsValid(con))
  expect_false(db_disconnect())

  # Lazy: reconnects to the last database used.
  con2 <- db_con()
  expect_true(DBI::dbIsValid(con2))
  expect_identical(db_info()$path, normalizePath(sample_db_path()))
})

test_that("T-4.6 C1: db_con() connects lazily through AUSPARL_DB", {
  local_db_disconnect()
  db_disconnect()
  old_last <- .ausparl$last_path
  withr::defer(.ausparl$last_path <- old_last)

  # No database used yet this session: falls back to AUSPARL_DB.
  .ausparl$last_path <- NULL
  withr::local_envvar(AUSPARL_DB = sample_db_path())
  expect_true(DBI::dbIsValid(db_con()))
  expect_identical(db_info()$path, normalizePath(sample_db_path()))

  # The last database used has since disappeared: falls back to AUSPARL_DB.
  db_disconnect()
  .ausparl$last_path <- tempfile(fileext = ".duckdb")
  expect_true(DBI::dbIsValid(db_con()))
  expect_identical(db_info()$path, normalizePath(sample_db_path()))
})

test_that("T-4.6 C1: a connection opened under on.exit() is closed on exit", {
  withr::local_envvar(AUSPARL_DB = NA)
  f <- function() {
    db_connect(sample = TRUE)
    on.exit(db_disconnect(), add = TRUE)
    db_con()
  }
  con <- f()
  expect_false(DBI::dbIsValid(con))
})

test_that("T-4.6 C1: connecting again closes the previous connection", {
  local_db_disconnect()
  first <- db_connect(sample = TRUE)
  second <- db_connect(sample = TRUE)
  expect_false(DBI::dbIsValid(first))
  expect_true(DBI::dbIsValid(second))
})

test_that("T-4.6 C2: the connection is read-only", {
  local_db_disconnect()
  db_connect(sample = TRUE)
  expect_error(DBI::dbExecute(db_con(), "CREATE TABLE scratch (x INT)"))
  expect_error(DBI::dbExecute(db_con(), "DELETE FROM sittings"))
})

test_that("T-4.6 C3: explicit arguments beat AUSPARL_DB", {
  local_db_disconnect()
  copy <- local_sample_copy(character())
  withr::local_envvar(AUSPARL_DB = copy)

  db_connect(sample = TRUE)
  expect_identical(db_info()$path, normalizePath(sample_db_path()))

  db_connect(path = sample_db_path())
  expect_identical(db_info()$path, normalizePath(sample_db_path()))

  db_connect()
  expect_identical(db_info()$path, normalizePath(copy))
})

test_that("T-4.6 C3: bad or missing inputs raise classed errors", {
  local_db_disconnect()
  withr::local_envvar(AUSPARL_DB = NA, R_USER_DATA_DIR = withr::local_tempdir())

  expect_error(db_connect(path = sample_db_path(), sample = TRUE),
    class = "ausparl_input_error"
  )
  expect_error(db_connect(sample = NA), class = "ausparl_input_error")
  expect_error(db_connect(path = c("a", "b")), class = "ausparl_input_error")
  expect_error(db_connect(), class = "ausparl_db_error")
  expect_error(db_connect(path = tempfile(fileext = ".duckdb")), class = "ausparl_not_found")

  withr::local_envvar(AUSPARL_DB = tempfile(fileext = ".duckdb"))
  expect_error(db_connect(), class = "ausparl_not_found")

  not_db <- withr::local_tempfile(fileext = ".duckdb")
  writeLines("not a database", not_db)
  err <- expect_error(db_connect(path = not_db), class = "ausparl_db_error")
  expect_s3_class(err, "ausparl_error")
  expect_null(.ausparl$con)
})

test_that("T-4.9 C4: an incompatible schema major is rejected and leaves no connection", {
  local_db_disconnect()
  v6 <- local_sample_copy("UPDATE schema_version SET schema_version = '6.0.0'")
  expect_error(db_connect(path = v6), class = "ausparl_db_error")
  expect_null(.ausparl$con)

  v8 <- local_sample_copy("UPDATE schema_version SET schema_version = '8.0.0'")
  expect_error(db_connect(path = v8), class = "ausparl_db_error")
  expect_null(.ausparl$con)

  no_sv <- local_sample_copy("DROP TABLE schema_version")
  expect_error(db_connect(path = no_sv), class = "ausparl_db_error")

  minor <- local_sample_copy("UPDATE schema_version SET schema_version = '7.1.0'")
  expect_no_error(db_connect(path = minor))
})

test_that("T-4.6 C5: db_info() reports the version under either builder column name", {
  local_db_disconnect()
  db_connect(sample = TRUE)
  info <- db_info()
  expect_s3_class(info, "tbl_df")
  expect_identical(nrow(info), 1L)
  expect_identical(info$schema_version, "7.0.0")
  expect_identical(info$builder_version, "0.0.0.9000")
  expect_identical(info$n_sittings, 8L)
  expect_identical(info$n_actions, 1488L)
  expect_identical(info$n_members, 303L)
  expect_type(info$fts_available, "logical")

  renamed <- local_sample_copy(
    "ALTER TABLE schema_version RENAME COLUMN ausparl_version TO pipeline_version"
  )
  db_connect(path = renamed)
  expect_identical(db_info()$builder_version, "0.0.0.9000")
})

test_that("T-4.1 C6: db_tbl() returns lazy tables for tables, views and FTS tables", {
  local_db_disconnect()
  db_connect(sample = TRUE)

  sittings <- db_tbl("sittings")
  expect_s3_class(sittings, "tbl_lazy")
  expect_identical(nrow(dplyr::collect(sittings)), 8L)

  speech <- db_tbl("v_speech") |> dplyr::count() |> dplyr::collect()
  expect_gt(speech$n, 0)

  docs <- db_tbl("fts_main_actions.docs") |> dplyr::count() |> dplyr::collect()
  expect_equal(docs$n, 1488)
})

test_that("T-4.6 C6: db_tbl() rejects unknown or malformed names", {
  local_db_disconnect()
  db_connect(sample = TRUE)
  expect_error(db_tbl("sitings"), class = "ausparl_not_found")
  expect_error(db_tbl("nope.sittings"), class = "ausparl_not_found")
  expect_error(db_tbl(c("a", "b")), class = "ausparl_input_error")
  expect_error(db_tbl("a.b.c"), class = "ausparl_input_error")
})

test_that("T-4.6 C7: install_fts() is never called under tests", {
  local_db_disconnect()
  called <- FALSE
  local_mocked_bindings(
    install_fts = function(con) called <<- TRUE,
    load_fts_extension = function(con) stop("not installed")
  )
  expect_false(may_install_fts())
  db_connect(sample = TRUE)
  expect_false(called)
  expect_false(.ausparl$fts)
})

test_that("T-4.6 C7: a failed install leaves the connection usable", {
  local_db_disconnect()
  local_mocked_bindings(
    may_install_fts = function() TRUE,
    install_fts = function(con) stop("offline"),
    load_fts_extension = function(con) stop("not installed")
  )
  expect_message(
    expect_message(db_connect(sample = TRUE), "Installing the DuckDB"),
    "Full-text search is unavailable"
  )
  expect_false(.ausparl$fts)
  expect_true(DBI::dbIsValid(db_con()))
  expect_identical(nrow(dplyr::collect(db_tbl("sittings"))), 8L)
})

test_that("T-4.6 C7: a successful install is followed by a successful load", {
  local_db_disconnect()
  loads <- 0L
  local_mocked_bindings(
    may_install_fts = function() TRUE,
    install_fts = function(con) TRUE,
    load_fts_extension = function(con) {
      loads <<- loads + 1L
      if (loads == 1L) stop("not installed")
      TRUE
    }
  )
  expect_message(db_connect(sample = TRUE), "Installing the DuckDB")
  expect_identical(loads, 2L)
  expect_true(.ausparl$fts)
})

test_that("T-4.6 C7: auto-install respects the opt-out option and check environments", {
  withr::local_envvar(TESTTHAT = "false", `_R_CHECK_PACKAGE_NAME_` = "")
  withr::local_options(ausparl.auto_install_fts = NULL)
  expect_true(may_install_fts())
  withr::local_options(ausparl.auto_install_fts = FALSE)
  expect_false(may_install_fts())
  withr::local_options(ausparl.auto_install_fts = TRUE)
  withr::local_envvar(`_R_CHECK_PACKAGE_NAME_` = "ausparl")
  expect_false(may_install_fts())
})

test_that("T-4.6 C8: every error class inherits ausparl_error", {
  f <- list(abort_input, abort_ambiguous, abort_not_found, abort_db)
  classes <- c(
    "ausparl_input_error", "ausparl_ambiguous_input", "ausparl_not_found", "ausparl_db_error"
  )
  for (i in seq_along(f)) {
    err <- expect_error(f[[i]]("boom"), class = classes[i])
    expect_s3_class(err, "ausparl_error")
  }
})

# ---- resource limits: memory cap and session temp directory -----------------------------------

current_setting <- function(name) {
  DBI::dbGetQuery(db_con(), paste0("SELECT current_setting('", name, "') AS v"))$v
}

# What DuckDB reports for `limit`, read off a scratch in-memory connection.
reported_memory_limit <- function(limit) {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, paste0("SET memory_limit = '", limit, "'"))
  DBI::dbGetQuery(con, "SELECT current_setting('memory_limit') AS v")$v
}

test_that("T-4.6 M1: the default connection caps DuckDB memory at 3GB", {
  local_db_disconnect()
  withr::local_options(ausparl.memory_limit = NULL)
  db_connect(sample = TRUE)
  expect_identical(current_setting("memory_limit"), reported_memory_limit("3GB"))
})

test_that("T-4.6 M2: ausparl.memory_limit changes the cap on reconnect", {
  local_db_disconnect()
  withr::local_options(ausparl.memory_limit = "1GB")
  db_connect(sample = TRUE)
  expect_identical(current_setting("memory_limit"), reported_memory_limit("1GB"))

  withr::local_options(ausparl.memory_limit = " 1.5 gb ")
  db_connect(sample = TRUE)
  expect_identical(current_setting("memory_limit"), reported_memory_limit("1.5GB"))
})

test_that("T-4.6 M3: DuckDB spills under tempdir(), never beside the database", {
  local_db_disconnect()
  db_connect(sample = TRUE)
  # The directory is created lazily on first spill, so normalise its (existing) parent.
  temp_dir <- current_setting("temp_directory")
  expect_identical(basename(temp_dir), "ausparl-duckdb")
  expect_identical(normalizePath(dirname(temp_dir)), normalizePath(tempdir()))
  db_dir <- normalizePath(dirname(sample_db_path()))
  expect_false(identical(normalizePath(dirname(temp_dir)), db_dir))
})

test_that("T-4.6 M4: an invalid ausparl.memory_limit is an input error and keeps the connection", {
  local_db_disconnect()
  con <- db_connect(sample = TRUE)
  for (bad in list("lots", -1, c("1GB", "2GB"), "", NA_character_, "3", "GB")) {
    withr::with_options(
      list(ausparl.memory_limit = bad),
      expect_error(db_connect(sample = TRUE), class = "ausparl_input_error")
    )
  }
  expect_true(DBI::dbIsValid(con))
  expect_identical(db_con(), con)
})
