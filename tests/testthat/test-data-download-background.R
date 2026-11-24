# Unit tests for db_download(background = TRUE) and the download lock. Nothing touches the
# network or starts a process: the pin, the record, the transfer and the two launchers are mocked.
# The helpers follow test-data-download.R's, repeated here so this file stands alone.

bg_pin <- list(version = "0.0.0.9000", data_version = "7.0.0-20261123", record = "123")

local_bg_env <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(
    AUSPARL_DB = NA, R_USER_DATA_DIR = dir, R_USER_CACHE_DIR = file.path(dir, "cache"),
    .local_envir = env
  )
  withr::defer(db_disconnect(), envir = env)
  dir
}

bg_dest <- function(dir) file.path(dir, "R", "ausparl", "7.0.0-20261123", "hansard.duckdb")

# Mocks the pin and both launchers, and fails if the record or the transfer is touched.
local_bg_mocks <- function(rstudio, env = parent.frame()) {
  calls <- new.env()
  local_mocked_bindings(
    pinned_release = function() bg_pin,
    zenodo_record_json = function(record, call) stop("the record must not be fetched"),
    download_file = function(url, destfile, call) stop("nothing must be downloaded"),
    rstudio_jobs_available = function() rstudio,
    run_rstudio_job = function(script, name) {
      calls$job <- list(script = script, name = name)
    },
    run_detached = function(script, log) {
      calls$detached <- list(script = script, log = log)
    },
    .env = env
  )
  calls
}

test_that("background must be TRUE or FALSE", {
  local_bg_env()
  local_bg_mocks(rstudio = TRUE)
  expect_error(db_download(background = NA), class = "ausparl_input_error")
  expect_error(db_download(background = "yes"), class = "ausparl_input_error")
})

test_that("in RStudio, background = TRUE starts a job and returns at once", {
  dir <- local_bg_env()
  calls <- local_bg_mocks(rstudio = TRUE)
  expect_message(path <- db_download(background = TRUE), "Background Jobs")
  expect_identical(path, bg_dest(dir))
  expect_null(calls$detached)
  expect_match(calls$job$name, "7.0.0-20261123")

  script <- readLines(calls$job$script)
  expect_true(any(grepl("^\\.libPaths\\(", script)))
  expect_true(any(grepl("R_USER_DATA_DIR", script, fixed = TRUE)))
  expect_true(any(grepl("options(ausparl.download_progress = TRUE)", script, fixed = TRUE)))
  expect_identical(utils::tail(script, 1), "ausparl::db_download(force = FALSE)")
  # The target directory is created up front, so a bad path fails here, not in the job.
  expect_true(dir.exists(dirname(bg_dest(dir))))
})

test_that("outside RStudio, background = TRUE starts a detached process with a log", {
  local_bg_env()
  calls <- local_bg_mocks(rstudio = FALSE)
  expect_message(db_download(background = TRUE), "download.log")
  expect_null(calls$job)
  expect_identical(basename(calls$detached$log), "download.log")
  script <- readLines(calls$detached$script)
  expect_true(any(grepl("options(ausparl.download_progress = FALSE)", script, fixed = TRUE)))
})

test_that("dir and force reach the background script, with dir made absolute", {
  local_bg_env()
  calls <- local_bg_mocks(rstudio = TRUE)
  project <- withr::local_tempdir()
  withr::local_dir(project)
  expect_message(path <- db_download(dir = "dataset", force = TRUE, background = TRUE))
  call_line <- utils::tail(readLines(calls$job$script), 1)
  expected <- normalizePath(file.path(project, "dataset"), mustWork = FALSE)
  expect_identical(
    call_line,
    paste0("ausparl::db_download(force = TRUE, dir = ", deparse(expected), ")")
  )
  expect_message(db_download(dir = "dataset", background = TRUE), "db_connect\\(path = ")
})

test_that("an installed copy is reported and no background download starts", {
  dir <- local_bg_env()
  calls <- local_bg_mocks(rstudio = TRUE)
  dest <- bg_dest(dir)
  dir.create(dirname(dest), recursive = TRUE)
  file.copy(sample_db_path(), dest)
  writeLines(c(unname(tools::md5sum(dest)), "7.0.0-20261123"), paste0(dest, ".verified"))
  expect_message(path <- db_download(background = TRUE), "already installed")
  expect_identical(path, dest)
  expect_null(calls$job)
})

# ---- lock -------------------------------------------------------------------------------------

write_lock <- function(dest, pid, host = Sys.info()[["nodename"]], size = 100) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(pid, host, "2026-11-24 10:00:00", size), paste0(dest, ".lock"))
}

test_that("a live lock stops a second download and reports progress", {
  dir <- local_bg_env()
  calls <- local_bg_mocks(rstudio = TRUE)
  dest <- bg_dest(dir)
  write_lock(dest, Sys.getpid())
  writeBin(raw(40), paste0(dest, ".part"))
  err <- expect_error(db_download(), class = "ausparl_db_error")
  expect_match(conditionMessage(err), "already running")
  expect_match(conditionMessage(err), "40 B of 100 B")
  expect_error(db_download(background = TRUE), class = "ausparl_db_error")
  expect_null(calls$job)
  expect_true(file.exists(paste0(dest, ".lock")))
})

test_that("a lock from another computer is never taken as stale", {
  dir <- local_bg_env()
  local_bg_mocks(rstudio = TRUE)
  dest <- bg_dest(dir)
  write_lock(dest, 1L, host = "another-computer")
  err <- expect_error(db_download(), class = "ausparl_db_error")
  expect_match(conditionMessage(err), "another-computer")
  expect_match(conditionMessage(err), "delete")
})

test_that("a stale lock on this computer is removed", {
  skip_on_os("windows")
  dir <- local_bg_env()
  calls <- local_bg_mocks(rstudio = TRUE)
  local_mocked_bindings(process_alive = function(pid) FALSE)
  dest <- bg_dest(dir)
  write_lock(dest, 999999L)
  expect_message(db_download(background = TRUE), "Background Jobs")
  expect_false(file.exists(paste0(dest, ".lock")))
  expect_false(is.null(calls$job))
})

test_that("a foreground download holds the lock while it runs and releases it after", {
  dir <- local_bg_env()
  dest <- bg_dest(dir)
  seen <- new.env()
  local_mocked_bindings(
    pinned_release = function() bg_pin,
    zenodo_record_json = function(record, call) {
      list(files = list(list(
        key = "hansard.duckdb", size = file.size(sample_db_path()),
        checksum = paste0("md5:", unname(tools::md5sum(sample_db_path()))),
        links = list(self = "https://example.org/hansard.duckdb")
      )))
    },
    download_file = function(url, destfile, call) {
      seen$lock <- read_download_lock(paste0(dest, ".lock"))
      file.copy(sample_db_path(), destfile, overwrite = TRUE)
    }
  )
  suppressMessages(db_download())
  expect_identical(seen$lock$pid, Sys.getpid())
  expect_identical(seen$lock$size, as.numeric(file.size(sample_db_path())))
  expect_false(file.exists(paste0(dest, ".lock")))
})

test_that("the lock is released when the download fails", {
  dir <- local_bg_env()
  dest <- bg_dest(dir)
  local_mocked_bindings(
    pinned_release = function() bg_pin,
    zenodo_record_json = function(record, call) {
      list(files = list(list(
        key = "hansard.duckdb", size = 10, checksum = "md5:0000",
        links = list(self = "https://example.org/hansard.duckdb")
      )))
    },
    download_file = function(url, destfile, call) writeBin(raw(10), destfile)
  )
  expect_error(suppressMessages(db_download()), class = "ausparl_db_error")
  expect_false(file.exists(paste0(dest, ".lock")))
})

test_that("process_alive() recognises this process", {
  skip_on_os("windows")
  expect_true(process_alive(Sys.getpid()))
})

test_that("download progress follows the option, defaulting to interactive()", {
  withr::local_options(ausparl.download_progress = TRUE)
  expect_true(show_download_progress())
  withr::local_options(ausparl.download_progress = FALSE)
  expect_false(show_download_progress())
  withr::local_options(ausparl.download_progress = NULL)
  expect_identical(show_download_progress(), interactive())
})
