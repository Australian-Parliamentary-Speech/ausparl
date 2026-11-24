# Unit tests for db_download() and the downloaded-copy step of db_connect(). Nothing touches the
# network: the pin, the Zenodo record and the transfer are mocked, the user data directory is a
# temp directory, and AUSPARL_DB is unset.

test_pin <- list(version = "0.0.0.9000", data_version = "7.0.0-20261123", record = "123")

# Isolates a test from AUSPARL_DB and the real user data directory; returns the temp data dir.
local_download_env <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(AUSPARL_DB = NA, R_USER_DATA_DIR = dir, .local_envir = env)
  withr::defer(db_disconnect(), envir = env)
  dir
}

# A Zenodo API record listing one file.
fake_record <- function(key = "hansard.duckdb", md5 = "0123abcd", size = 10) {
  list(files = list(
    list(key = "README.md", size = 1, checksum = "md5:ffff", links = list(self = "x")),
    list(
      key = key, size = size, checksum = paste0("md5:", md5),
      links = list(self = paste0("https://zenodo.org/api/records/123/files/", key, "/content"))
    )
  ))
}

sample_md5 <- function() unname(tools::md5sum(sample_db_path()))

installed_path <- function(dir) file.path(dir, "R", "ausparl", "7.0.0-20261123", "hansard.duckdb")

# Mocks the pin, the record and a transfer that writes a copy of the sample DB.
local_download_mocks <- function(md5 = sample_md5(), env = parent.frame()) {
  calls <- new.env()
  calls$api <- 0L
  calls$transfer <- 0L
  local_mocked_bindings(
    pinned_release = function() test_pin,
    zenodo_record_json = function(record, call) {
      calls$api <- calls$api + 1L
      fake_record(md5 = toupper(md5), size = file.size(sample_db_path()))
    },
    download_file = function(url, destfile, call) {
      calls$transfer <- calls$transfer + 1L
      calls$url <- url
      calls$destfile <- destfile
      file.copy(sample_db_path(), destfile, overwrite = TRUE)
    },
    .env = env
  )
  calls
}

test_that("T-4.12 D1: no pinned record raises a db error without any network call", {
  local_download_env()
  touched <- FALSE
  for (record in list(NA_character_, "")) {
    pin <- test_pin
    pin$record <- record
    local_mocked_bindings(
      pinned_release = function() pin,
      zenodo_record_json = function(...) touched <<- TRUE,
      download_file = function(...) touched <<- TRUE
    )
    expect_error(db_download(), class = "ausparl_db_error")
  }
  expect_false(touched)
  expect_error(db_download(force = NA), class = "ausparl_input_error")
})

test_that("T-4.12 D2: a record and transfer install the file and its marker", {
  dir <- local_download_env()
  calls <- local_download_mocks()

  path <- suppressMessages(db_download())
  expect_identical(path, installed_path(dir))
  expect_true(file.exists(path))
  expect_identical(readLines(paste0(path, ".verified")), c(sample_md5(), "7.0.0-20261123"))
  expect_false(file.exists(paste0(path, ".part")))
  expect_identical(calls$destfile, paste0(path, ".part"))
  expect_identical(calls$url, "https://zenodo.org/api/records/123/files/hansard.duckdb/content")
  expect_identical(cached_db_path("7.0.0-20261123"), path)
})

test_that("T-4.12 D3: an existing partial file is resumed, not restarted", {
  dir <- local_download_env()
  local_mocked_bindings(
    pinned_release = function() test_pin,
    zenodo_record_json = function(record, call) {
      fake_record(md5 = sample_md5(), size = file.size(sample_db_path()))
    }
  )
  bytes <- readBin(sample_db_path(), "raw", file.size(sample_db_path()))
  part <- paste0(installed_path(dir), ".part")
  dir.create(dirname(part), recursive = TRUE)
  writeBin(bytes[1:1000], part)

  seen <- new.env()
  local_mocked_bindings(
    multi_download = function(urls, destfiles, resume, ...) {
      seen$args <- list(dest = destfiles, resume = resume, size = file.size(destfiles), ...)
      con <- file(destfiles, "ab")
      writeBin(bytes[-(1:1000)], con)
      close(con)
      data.frame(success = TRUE, status_code = 206, resumefrom = 1000, error = NA_character_)
    },
    .package = "curl"
  )
  path <- suppressMessages(db_download())
  expect_identical(seen$args$dest, part)
  expect_true(seen$args$resume)
  expect_identical(seen$args$size, 1000)
  expect_identical(seen$args$timeout, 0)
  expect_identical(unname(tools::md5sum(path)), sample_md5())
})

test_that("T-4.14 D4: an MD5 mismatch raises a db error and leaves nothing installed", {
  dir <- local_download_env()
  local_download_mocks(md5 = "0000")
  expect_error(suppressMessages(db_download()), class = "ausparl_db_error")
  expect_false(file.exists(installed_path(dir)))
  expect_false(file.exists(paste0(installed_path(dir), ".part")))
  expect_false(file.exists(paste0(installed_path(dir), ".verified")))
  expect_null(cached_db_path("7.0.0-20261123"))
})

test_that("T-4.14 D4: an unreadable download is kept, not deleted, and nothing is installed", {
  dir <- local_download_env()
  local_download_mocks()
  local_mocked_bindings(file_md5 = function(path) NA_character_)
  err <- expect_error(suppressMessages(db_download()), class = "ausparl_db_error")
  expect_match(conditionMessage(err), "Could not read")
  expect_true(file.exists(paste0(installed_path(dir), ".part")))
  expect_false(file.exists(installed_path(dir)))
  expect_false(file.exists(paste0(installed_path(dir), ".verified")))
})

test_that("file_md5() is NA for a missing file and the MD5 otherwise", {
  expect_identical(file_md5(tempfile()), NA_character_)
  expect_identical(file_md5(sample_db_path()), unname(tools::md5sum(sample_db_path())))
})

test_that("T-4.12 D5: a verified copy is reused; force = TRUE downloads again", {
  dir <- local_download_env()
  calls <- local_download_mocks()

  suppressMessages(db_download())
  expect_identical(calls$transfer, 1L)
  expect_message(path <- db_download(), "already installed")
  expect_identical(path, installed_path(dir))
  expect_identical(calls$transfer, 1L)
  expect_identical(calls$api, 1L)

  suppressMessages(db_download(force = TRUE))
  expect_identical(calls$transfer, 2L)
  expect_true(file.exists(paste0(path, ".verified")))

  # Without its marker an installed file does not count.
  unlink(paste0(path, ".verified"))
  expect_null(cached_db_path("7.0.0-20261123"))
  expect_null(cached_db_path(NA_character_))
})

test_that("T-4.12 D6: a record with no .duckdb file raises not found", {
  local_download_env()
  local_mocked_bindings(
    pinned_release = function() test_pin,
    zenodo_record_json = function(record, call) fake_record(key = "hansard.zip"),
    download_file = function(...) stop("no transfer expected")
  )
  expect_error(db_download(), class = "ausparl_not_found")

  # A .duckdb file without an MD5 cannot be verified.
  record <- fake_record()
  record$files[[2]]$checksum <- "sha256:abcd"
  local_mocked_bindings(zenodo_record_json = function(record_id, call) record)
  expect_error(db_download(), class = "ausparl_db_error")
})

test_that("T-4.12 D7: the download message names the package and data versions and record", {
  local_download_env()
  local_download_mocks()
  msgs <- paste(capture_messages(db_download()), collapse = "")
  expect_match(msgs, "7.0.0-20261123", fixed = TRUE)
  expect_match(msgs, "0.0.0.9000", fixed = TRUE)
  expect_match(msgs, "record 123", fixed = TRUE)
})

test_that("T-4.9 D8: the pinned data version's schema major is the supported one", {
  pin <- pinned_release()
  expect_match(pin$data_version, "^[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]{8}$")
  expect_identical(as.integer(sub("\\..*$", "", pin$data_version)), supported_schema_major)
  expect_identical(pin$version, as.character(utils::packageVersion("ausparl")))
})

test_that("T-4.6 D9: db_connect() falls back to the verified copy after explicit and AUSPARL_DB", {
  dir <- local_download_env()
  local_download_mocks()

  # Nothing installed: the error names db_download().
  err <- expect_error(db_connect(), class = "ausparl_db_error")
  expect_match(conditionMessage(err), "db_download()", fixed = TRUE)

  path <- suppressMessages(db_download())
  expect_message(db_connect(), "7.0.0-20261123")
  expect_identical(db_info()$path, normalizePath(path))
  expect_identical(db_info()$schema_version, "7.0.0")

  # Explicit arguments, then AUSPARL_DB, come before the downloaded copy.
  copy <- local_sample_copy(character())
  withr::local_envvar(AUSPARL_DB = copy)
  expect_no_message(db_connect())
  expect_identical(db_info()$path, normalizePath(copy))
  db_connect(sample = TRUE)
  expect_identical(db_info()$path, normalizePath(sample_db_path()))
})

test_that("T-4.12 D6: the Zenodo record is fetched and parsed, and failures are db errors", {
  response <- function(status, body) {
    list(status_code = status, content = charToRaw(body))
  }
  local_mocked_bindings(
    curl_fetch_memory = function(url, ...) {
      expect_identical(url, "https://zenodo.org/api/records/123")
      response(200, '{"files": [{"key": "hansard.duckdb"}]}')
    },
    .package = "curl"
  )
  expect_identical(zenodo_record_json("123")$files[[1]]$key, "hansard.duckdb")

  local_mocked_bindings(
    curl_fetch_memory = function(url, ...) response(404, "{}"), .package = "curl"
  )
  expect_error(zenodo_record_json("123"), class = "ausparl_db_error")
  local_mocked_bindings(
    curl_fetch_memory = function(url, ...) response(200, "<html>"), .package = "curl"
  )
  expect_error(zenodo_record_json("123"), class = "ausparl_db_error")
  local_mocked_bindings(
    curl_fetch_memory = function(url, ...) stop("Could not resolve host"), .package = "curl"
  )
  expect_error(zenodo_record_json("123"), class = "ausparl_db_error")
})

test_that("T-4.12 D3: a failed transfer is a db error and keeps the partial file", {
  part <- withr::local_tempfile()
  writeBin(as.raw(1:10), part)
  result <- function(success, status, resumefrom = 10, error = NA_character_) {
    data.frame(success = success, status_code = status, resumefrom = resumefrom, error = error)
  }

  local_mocked_bindings(
    multi_download = function(...) result(FALSE, 0, error = "Timeout was reached"),
    .package = "curl"
  )
  expect_error(download_file("u", part), class = "ausparl_db_error")
  expect_true(file.exists(part))

  local_mocked_bindings(multi_download = function(...) result(TRUE, 500), .package = "curl")
  expect_error(download_file("u", part), class = "ausparl_db_error")

  local_mocked_bindings(multi_download = function(...) stop("bad handle"), .package = "curl")
  expect_error(download_file("u", part), class = "ausparl_db_error")
  expect_true(file.exists(part))

  # 416 on a resumed file: it was already complete.
  local_mocked_bindings(multi_download = function(...) result(FALSE, 416), .package = "curl")
  expect_identical(download_file("u", part), part)
  local_mocked_bindings(
    multi_download = function(...) result(FALSE, 416, resumefrom = 0), .package = "curl"
  )
  expect_error(download_file("u", part), class = "ausparl_db_error")
})

test_that("T-4.14 D4: a file that cannot be moved into place is a db error", {
  dir <- local_download_env()
  local_download_mocks()
  # A non-empty directory where the database belongs blocks the rename.
  dir.create(installed_path(dir), recursive = TRUE)
  writeLines("x", file.path(installed_path(dir), "blocker"))
  expect_error(suppressMessages(db_download()), class = "ausparl_db_error")
  expect_false(file.exists(paste0(installed_path(dir), ".verified")))
})

test_that("T-4.12 D2: record file details fall back sensibly", {
  record <- fake_record()
  record$files[[2]]$links <- NULL
  record$files[[2]]$size <- NULL
  file <- record_db_file(record, test_pin, call = NULL)
  expect_identical(file$url, "https://zenodo.org/api/records/123/files/hansard.duckdb/content")
  expect_identical(format_size(file$size), "size unknown")
  expect_match(format_size(9.5e9), "GB")
})

# ---- dir: install into a directory the user names ---------------------------------------------

test_that("T-4.12 D12: dir installs hansard.duckdb and its marker directly in that directory", {
  data <- local_download_env()
  calls <- local_download_mocks()
  target <- file.path(withr::local_tempdir(), "dataset", "nested")

  msgs <- paste(capture_messages(path <- db_download(dir = target)), collapse = "")
  expect_identical(path, file.path(target, "hansard.duckdb"))
  expect_true(file.exists(path))
  expect_identical(unname(tools::md5sum(path)), sample_md5())
  expect_identical(readLines(paste0(path, ".verified")), c(sample_md5(), "7.0.0-20261123"))
  expect_false(file.exists(paste0(path, ".part")))
  expect_identical(calls$destfile, paste0(path, ".part"))
  expect_match(msgs, "db_connect(path = ", fixed = TRUE)
  # A path with braces is printed as it is.
  expect_match(
    cli::format_message(connect_hint("d", "/a{b}/hansard.duckdb")), "/a{b}/hansard.duckdb",
    fixed = TRUE
  )
  # Nothing goes to the user data directory, and db_connect() does not look in dir.
  expect_false(file.exists(installed_path(data)))
  expect_null(cached_db_path("7.0.0-20261123"))
  expect_error(db_connect(), class = "ausparl_db_error")
  db_connect(path = path)
  expect_identical(db_info()$schema_version, "7.0.0")
})

test_that("T-4.12 D13: a verified same-version copy in dir is reused; force downloads again", {
  local_download_env()
  calls <- local_download_mocks()
  target <- withr::local_tempdir()

  path <- suppressMessages(db_download(dir = target))
  expect_message(again <- db_download(dir = target), "already installed")
  expect_identical(again, path)
  expect_identical(calls$transfer, 1L)
  expect_identical(calls$api, 1L)

  suppressMessages(db_download(force = TRUE, dir = target))
  expect_identical(calls$transfer, 2L)

  # Without its marker the file does not count.
  unlink(paste0(path, ".verified"))
  suppressMessages(db_download(dir = target))
  expect_identical(calls$transfer, 3L)
})

test_that("T-4.12 D14: a copy of another database version in dir is replaced", {
  local_download_env()
  calls <- local_download_mocks()
  target <- withr::local_tempdir()
  path <- file.path(target, "hansard.duckdb")
  writeLines("old", path)
  writeLines(c("ffff", "7.0.0-20260101"), paste0(path, ".verified"))

  msgs <- capture_messages(db_download(dir = target))
  expect_match(msgs[1], "will be replaced", fixed = TRUE)
  expect_identical(calls$transfer, 1L)
  expect_identical(unname(tools::md5sum(path)), sample_md5())
  expect_identical(readLines(paste0(path, ".verified"))[2], "7.0.0-20261123")

  # A marker that names no version (one line) is not trusted either.
  writeLines(sample_md5(), paste0(path, ".verified"))
  suppressMessages(db_download(dir = target))
  expect_identical(calls$transfer, 2L)
})

test_that("T-4.12 D15: a bad dir is an input error, before any network call", {
  local_download_env()
  touched <- FALSE
  local_mocked_bindings(
    pinned_release = function() test_pin,
    zenodo_record_json = function(...) touched <<- TRUE,
    download_file = function(...) touched <<- TRUE
  )
  for (bad in list(1, c("a", "b"), "", NA_character_, TRUE)) {
    expect_error(db_download(dir = bad), class = "ausparl_input_error")
  }
  file <- withr::local_tempfile(lines = "x")
  expect_error(db_download(dir = file), class = "ausparl_input_error")
  expect_false(touched)
})

test_that("T-4.12 D16: a dir that cannot be created is an input error", {
  local_download_env()
  local_download_mocks()
  parent <- withr::local_tempfile(lines = "a file, not a directory")
  expect_error(
    suppressMessages(db_download(dir = file.path(parent, "dataset"))),
    class = "ausparl_input_error"
  )
})
