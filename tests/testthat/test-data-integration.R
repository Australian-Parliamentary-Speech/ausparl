# Module integration: data. Sample DB only; no network.

test_that("T-4.6 data integration: connect -> version check -> info -> query -> reconnect", {
  withr::local_envvar(AUSPARL_DB = NA)
  withr::defer(db_disconnect())

  # Under tests the fts guard must never install. LOAD is forced to fail so the guard is
  # actually consulted, even on a machine where fts is already installed.
  installs <- 0L
  local_mocked_bindings(
    install_fts = function(con) installs <<- installs + 1L,
    load_fts_extension = function(con) stop("not installed")
  )

  con <- db_connect(sample = TRUE)
  expect_true(DBI::dbIsValid(con))
  expect_error(DBI::dbExecute(con, "CREATE TABLE scratch (x INT)"))

  info <- db_info()
  expect_identical(info$schema_version, "7.0.0")
  expect_identical(info$n_sittings, 8L)

  speeches <- db_tbl("v_speech") |>
    dplyr::inner_join(db_tbl("sittings"), by = "sitting_id") |>
    dplyr::count(chamber.y) |>
    dplyr::collect()
  expect_setequal(speeches$chamber.y, c("house", "senate"))

  db_disconnect()
  expect_false(DBI::dbIsValid(con))
  expect_true(DBI::dbIsValid(db_con()))
  expect_identical(db_info()$path, normalizePath(sample_db_path()))
  expect_identical(installs, 0L)
})

test_that("T-4.9 data integration: a mismatched schema major is rejected end to end", {
  withr::defer(db_disconnect())
  path <- local_sample_copy("UPDATE schema_version SET schema_version = '5.2.0'")

  err <- expect_error(db_connect(path = path), class = "ausparl_db_error")
  expect_s3_class(err, "ausparl_error")
  expect_null(.ausparl$con)
})

test_that("T-4.12 data integration: download -> connect with no arguments -> query -> reuse", {
  dir <- withr::local_tempdir()
  withr::local_envvar(AUSPARL_DB = NA, R_USER_DATA_DIR = dir)
  withr::defer(db_disconnect())

  # The real pin, with a test record id in place of the published one. Only the network layer
  # (curl) is replaced; parsing, transfer handling, md5 check and install run for real.
  pin <- pinned_release()
  pin$record <- "123"
  sample <- sample_db_path()
  md5 <- unname(tools::md5sum(sample))
  record <- sprintf(
    '{"files": [{"key": "hansard.duckdb", "size": %s, "checksum": "md5:%s",
      "links": {"self": "https://zenodo.org/api/records/123/files/hansard.duckdb/content"}}]}',
    file.size(sample), md5
  )
  net <- new.env()
  net$api <- 0L
  net$transfer <- 0L
  local_mocked_bindings(pinned_release = function() pin)
  local_mocked_bindings(
    curl_fetch_memory = function(url, ...) {
      net$api <- net$api + 1L
      list(status_code = 200L, content = charToRaw(record))
    },
    multi_download = function(urls, destfiles, ...) {
      net$transfer <- net$transfer + 1L
      file.copy(sample, destfiles, overwrite = TRUE)
      data.frame(success = TRUE, status_code = 200, resumefrom = 0, error = NA_character_)
    },
    .package = "curl"
  )

  msgs <- testthat::capture_messages(path <- db_download())
  expect_true(any(grepl(pin$data_version, msgs, fixed = TRUE)))
  installed <- file.path(dir, "R", "ausparl", pin$data_version, "hansard.duckdb")
  expect_identical(path, installed)
  expect_identical(readLines(paste0(installed, ".verified")), c(md5, pin$data_version))

  msgs <- testthat::capture_messages(con <- db_connect())
  expect_true(any(grepl(pin$data_version, msgs, fixed = TRUE)))
  expect_error(DBI::dbExecute(con, "CREATE TABLE scratch (x INT)"))
  info <- db_info()
  expect_identical(info$path, normalizePath(installed))
  expect_identical(info$schema_version, "7.0.0")
  expect_gt(dplyr::collect(dplyr::count(db_tbl("sittings")))$n, 0)
  db_disconnect()

  suppressMessages(again <- db_download())
  expect_identical(again, installed)
  expect_identical(c(net$api, net$transfer), c(1L, 1L))
})

test_that("T-4.12 data integration: a release with no pinned record fetches nothing", {
  withr::local_envvar(AUSPARL_DB = NA, R_USER_DATA_DIR = withr::local_tempdir())
  withr::defer(db_disconnect())
  # The real pin with its record removed, so this holds whatever DESCRIPTION pins.
  pin <- pinned_release()
  pin$record <- NA_character_
  local_mocked_bindings(pinned_release = function() pin)
  touched <- FALSE
  local_mocked_bindings(
    curl_fetch_memory = function(...) touched <<- TRUE,
    multi_download = function(...) touched <<- TRUE,
    .package = "curl"
  )

  expect_error(db_download(), class = "ausparl_db_error")
  expect_false(touched)
  err <- expect_error(db_connect(), class = "ausparl_db_error")
  expect_match(conditionMessage(err), "db_download", fixed = TRUE)
})
