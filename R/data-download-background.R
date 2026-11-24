# Running db_download() in the background, and the lock that keeps two downloads from writing the
# same partial file. The background download runs the same db_download() call in another R
# process: an RStudio background job when RStudio is available, otherwise a detached Rscript.

# ---- target directory -------------------------------------------------------------------------

make_target_dir <- function(target, call) {
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(target)) {
    abort_input(c(
      "Could not create the directory {.file {target}}.",
      "i" = "Check the path and that its parent directory is writable."
    ), call = call)
  }
  invisible(target)
}

# ---- lock ---------------------------------------------------------------------------------------

# The lock file sits next to the partial download, as `<dest>.lock`. It holds the process id, the
# computer's name, the start time and the expected size of the file.
lock_path <- function(dest) paste0(dest, ".lock")

acquire_download_lock <- function(dest, size) {
  writeLines(
    c(
      Sys.getpid(), Sys.info()[["nodename"]], format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      format(size, scientific = FALSE)
    ),
    lock_path(dest)
  )
}

release_download_lock <- function(dest) {
  unlink(lock_path(dest))
}

read_download_lock <- function(lock) {
  x <- tryCatch(readLines(lock, warn = FALSE), error = function(e) character())
  x <- c(x, rep(NA_character_, 4))[1:4]
  list(
    pid = suppressWarnings(as.integer(x[1])), host = x[2], started = x[3],
    size = suppressWarnings(as.numeric(x[4]))
  )
}

# A lock is stale when the process that made it, on this computer, has gone. That can only be
# checked on Unix-alikes: tools::pskill() with signal 0 tests for the process without touching
# it there, while on Windows it would terminate it. Elsewhere the lock is taken as live.
lock_is_stale <- function(info) {
  same_host <- identical(info$host, Sys.info()[["nodename"]])
  if (!same_host || is.na(info$pid) || .Platform$OS.type != "unix") {
    return(FALSE)
  }
  !process_alive(info$pid)
}

process_alive <- function(pid) {
  isTRUE(suppressWarnings(tools::pskill(pid, signal = 0L)))
}

# Errors if another download into `dest` is running, saying how far it has got. A stale lock is
# removed.
check_download_lock <- function(dest, call) {
  lock <- lock_path(dest)
  if (!file.exists(lock)) {
    return(invisible())
  }
  info <- read_download_lock(lock)
  if (lock_is_stale(info)) {
    unlink(lock)
    return(invisible())
  }
  part <- paste0(dest, ".part")
  done <- if (file.exists(part)) file.size(part) else 0
  progress <- if (is.na(info$size)) {
    "{format_size(done)} downloaded so far."
  } else {
    "{format_size(done)} of {format_size(info$size)} downloaded so far."
  }
  started <- if (is.na(info$started)) "" else paste0(", started ", info$started)
  where <- if (is.na(info$host)) "" else paste0(" on ", info$host)
  abort_db(c(
    "A download of the database into {.file {dirname(dest)}} is already running (process
     {info$pid}{where}{started}).",
    "i" = progress,
    "i" = "Wait for it to finish: it installs the database at {.file {dest}}.",
    "i" = "If no download is running, delete {.file {lock}} and try again."
  ), call = call)
}

# ---- background download --------------------------------------------------------------------

start_background_download <- function(force, dir, pin, dest, call) {
  dir <- if (is.null(dir)) NULL else normalizePath(dir, mustWork = FALSE)
  name <- paste("ausparl: download database", pin$data_version)
  next_step <- "When it has finished, connect with {.code {connect_call(dir, dest)}}."

  if (rstudio_jobs_available()) {
    script <- write_background_script(force, dir, progress = TRUE)
    run_rstudio_job(script, name)
    cli::cli_inform(c(
      "v" = "Downloading database {.val {pin$data_version}} in an RStudio background job.",
      "i" = "Follow it in the {.strong Background Jobs} pane; you can keep working meanwhile.",
      "i" = next_step
    ))
  } else {
    script <- write_background_script(force, dir, progress = FALSE)
    log <- file.path(dirname(script), "download.log")
    run_detached(script, log)
    cli::cli_inform(c(
      "v" = "Downloading database {.val {pin$data_version}} in a separate R process; you can
             keep working meanwhile.",
      "i" = "Its messages go to {.file {log}}. Run {.code db_download()} again to see how much
             has been downloaded.",
      "i" = next_step
    ))
  }
  invisible(dest)
}

connect_call <- function(dir, dest) {
  if (is.null(dir)) "db_connect()" else paste0("db_connect(path = ", deparse(dest), ")")
}

# The script runs db_download() in a fresh R process with this session's library paths, so it
# finds the same ausparl, and this session's R_USER_DATA_DIR, so it installs in the same place.
write_background_script <- function(force, dir, progress) {
  folder <- tools::R_user_dir("ausparl", "cache")
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  script <- file.path(folder, "download.R")
  data_dir_env <- Sys.getenv("R_USER_DATA_DIR")
  args <- c(
    paste0("force = ", deparse(force)),
    if (!is.null(dir)) paste0("dir = ", deparse(dir))
  )
  writeLines(c(
    paste0(
      "# Written by ausparl::db_download(background = TRUE) on ",
      format(Sys.time(), "%Y-%m-%d %H:%M:%S"), ". Safe to delete."
    ),
    paste0(".libPaths(", deparse1(.libPaths()), ")"),
    if (nzchar(data_dir_env)) paste0("Sys.setenv(R_USER_DATA_DIR = ", deparse(data_dir_env), ")"),
    paste0("options(ausparl.download_progress = ", deparse(progress), ")"),
    paste0("ausparl::db_download(", paste(args, collapse = ", "), ")")
  ), script)
  script
}

rstudio_jobs_available <- function() {
  requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable() &&
    rstudioapi::hasFun("jobRunScript")
}

run_rstudio_job <- function(script, name) {
  rstudioapi::jobRunScript(
    path = script, name = name, workingDir = dirname(script),
    importEnv = FALSE, exportEnv = ""
  )
}

# A detached Rscript keeps running after this R session ends. (callr's background processes do
# not: their script lives in this session's temp directory, which is removed on exit.)
run_detached <- function(script, log) {
  exe <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  rscript <- file.path(R.home("bin"), exe)
  system2(
    rscript, c("--no-save", "--no-restore", shQuote(script)),
    stdout = log, stderr = log, wait = FALSE
  )
}

# Interactive sessions show curl's progress bar. A background job is not interactive, so the
# background script sets this option to show it there too.
show_download_progress <- function() {
  isTRUE(getOption("ausparl.download_progress", interactive()))
}
