# Downloading the database. Each package release pins one database version and one Zenodo
# version record in DESCRIPTION; db_download() installs that file, checksum-verified, into the
# user data directory (db_connect() falls back to that copy) or into a directory the user names.

zenodo_api <- "https://zenodo.org/api/records/"
db_file_name <- "hansard.duckdb"

#' Download the Hansard database
#'
#' Downloads the full Hansard database that this version of ausparl was released with, from
#' its Zenodo version record. The file is about 9.5 GB. An interrupted download resumes where it
#' stopped when you call `db_download()` again with the same arguments. The file is installed
#' only once its MD5 checksum matches the one Zenodo lists.
#'
#' **Where it goes.** By default the database is installed in the ausparl user data directory
#' (`tools::R_user_dir("ausparl", "data")`; set the `R_USER_DATA_DIR` environment variable to
#' move it), and [db_connect()] with no arguments then opens it, unless you pass `path`,
#' `sample = TRUE` or set the `AUSPARL_DB` environment variable, which take precedence.
#'
#' With `dir`, the database is installed directly in that directory as `hansard.duckdb` (the
#' directory is created if needed), for example `db_download(dir = "dataset")` in a project
#' folder. [db_connect()] does not look there by itself: open that copy with
#' `db_connect(path = file.path(dir, "hansard.duckdb"))` or by setting `AUSPARL_DB` to it. A
#' verified copy of the same database version already in `dir` is reused; a copy of another
#' version is replaced.
#'
#' `db_connect()` never downloads anything itself. Each ausparl release pins exactly one
#' database version, so an older ausparl never fetches a newer database it cannot read. To use
#' a different database version, install the ausparl release that pins it.
#'
#' @param force If `TRUE`, download again even when a verified copy is already installed.
#' @param dir A directory to install the database in, as a single string. `NULL` (the default)
#'   uses the ausparl user data directory.
#' @return The path of the installed database file, invisibly.
#' @seealso [db_connect()], [db_info()]
#' @export
#' @examples
#' \dontrun{
#' # About 9.5 GB; run once per database version.
#' db_download()
#' db_connect()
#' db_info()
#' db_disconnect()
#'
#' # Or into a folder of your project, then open it by path.
#' path <- db_download(dir = "dataset")
#' db_connect(path = path)
#' }
db_download <- function(force = FALSE, dir = NULL) {
  call <- rlang::current_env()
  if (!is.null(dir) && (!rlang::is_string(dir) || !nzchar(dir))) {
    abort_input(c(
      "{.arg dir} must be a single directory path, or {.code NULL} for the user data
       directory.",
      "x" = "It is {.obj_type_friendly {dir}}."
    ), call = call)
  }
  if (!rlang::is_bool(force)) {
    abort_input("{.arg force} must be {.code TRUE} or {.code FALSE}.", call = call)
  }
  if (!is.null(dir) && file.exists(dir) && !dir.exists(dir)) {
    abort_input(c(
      "{.arg dir} must be a directory.",
      "x" = "{.file {dir}} is a file."
    ), call = call)
  }
  pin <- pinned_release()
  if (is.na(pin$record) || !nzchar(pin$record) || is.na(pin$data_version)) {
    abort_db(c(
      "No database release is pinned for this version of ausparl ({pin$version}), so there is
       nothing to download yet.",
      "i" = "Meanwhile, pass {.arg path} to {.fn db_connect}, or set the {.envvar AUSPARL_DB}
             environment variable to your {.file hansard.duckdb}."
    ), call = call)
  }

  installed <- if (is.null(dir)) {
    cached_db_path(pin$data_version)
  } else {
    dir_db_path(dir, pin$data_version)
  }
  if (!force && !is.null(installed)) {
    cli::cli_inform(c(
      "v" = "Database {.val {pin$data_version}} is already installed at {.file {installed}}.",
      "i" = "Use {.code force = TRUE} to download it again."
    ))
    return(invisible(installed))
  }

  file <- record_db_file(zenodo_record_json(pin$record, call = call), pin, call = call)
  cli::cli_inform(c(
    "i" = "ausparl {pin$version} uses database {.val {pin$data_version}} (Zenodo record
           {pin$record}).",
    "i" = "Downloading {.file {file$key}} ({format_size(file$size)}). If it is interrupted,
           run {.code db_download()} again with the same arguments to resume."
  ))

  target <- if (is.null(dir)) file.path(data_dir(), pin$data_version) else dir
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(target)) {
    abort_input(c(
      "Could not create the directory {.file {target}}.",
      "i" = "Check the path and that its parent directory is writable."
    ), call = call)
  }
  dest <- file.path(target, db_file_name)
  part <- paste0(dest, ".part")
  marker <- paste0(dest, ".verified")
  download_file(file$url, part, call = call)

  md5 <- unname(tools::md5sum(part))
  if (!identical(tolower(md5), file$md5)) {
    unlink(part)
    abort_db(c(
      "The downloaded file failed its checksum and was deleted.",
      "x" = "Expected MD5 {.val {file$md5}}, got {.val {md5}}.",
      "i" = "Run {.code db_download()} again to download it afresh."
    ), call = call)
  }
  unlink(marker)
  unlink(dest)
  if (!suppressWarnings(file.rename(part, dest))) {
    abort_db(c(
      "Could not move the verified download into place at {.file {dest}}.",
      "i" = "Check that the directory is writable, then run {.code db_download()} again."
    ), call = call)
  }
  # The marker holds the checksum and the database version it belongs to.
  writeLines(c(md5, pin$data_version), marker)
  cli::cli_inform(c(
    "v" = "Installed database {.val {pin$data_version}} at {.file {dest}}.",
    "i" = connect_hint(dir, dest)
  ))
  invisible(dest)
}

# ---- internals ---------------------------------------------------------------------------------

# The release pin from DESCRIPTION. Fields that are absent come back as NA.
pinned_release <- function() {
  fields <- c("Version", "Config/ausparl/data_version", "Config/ausparl/zenodo_record")
  desc <- utils::packageDescription("ausparl", fields = fields)
  value <- function(field) {
    x <- trimws(as.character(desc[[field]]))
    if (length(x) != 1 || is.na(x) || !nzchar(x)) NA_character_ else x
  }
  list(
    version = value("Version"),
    data_version = value("Config/ausparl/data_version"),
    record = value("Config/ausparl/zenodo_record")
  )
}

data_dir <- function() {
  tools::R_user_dir("ausparl", "data")
}

# The installed copy of `data_version`, or NULL. A copy counts only once its verified marker
# exists; it is not hashed again.
cached_db_path <- function(data_version = pinned_release()$data_version) {
  if (is.na(data_version)) {
    return(NULL)
  }
  path <- file.path(data_dir(), data_version, db_file_name)
  if (file.exists(path) && file.exists(paste0(path, ".verified"))) path else NULL
}

# How to open a newly installed copy, as a cli message: db_connect() finds one in the user data
# directory itself; a copy in `dir` is opened by path.
connect_hint <- function(dir, dest) {
  if (is.null(dir)) {
    return("Connect with {.code db_connect()}.")
  }
  # Formatted here and its braces doubled, so cli_inform() prints it as it is.
  hint <- cli::format_inline("Connect with {.code db_connect(path = {.str {dest}})}.")
  gsub("([{}])", "\\1\\1", hint)
}

# The verified copy of `data_version` installed directly in `dir`, or NULL. Its marker must name
# that version on its second line, so a copy of another version is not reused.
dir_db_path <- function(dir, data_version) {
  path <- file.path(dir, db_file_name)
  marker <- paste0(path, ".verified")
  if (!file.exists(path) || !file.exists(marker)) {
    return(NULL)
  }
  if (!identical(readLines(marker, warn = FALSE)[2], data_version)) {
    cli::cli_inform(c(
      "i" = "{.file {path}} is not database {.val {data_version}}; it will be replaced."
    ))
    return(NULL)
  }
  path
}

# The parsed Zenodo API record.
zenodo_record_json <- function(record, call = rlang::caller_env()) {
  url <- paste0(zenodo_api, record)
  fail <- function(detail) {
    abort_db(c(
      "Could not read Zenodo record {record}.",
      "x" = detail,
      "i" = "Check your network connection and try again later."
    ), call = call)
  }
  res <- tryCatch(curl::curl_fetch_memory(url), error = function(e) fail(conditionMessage(e)))
  if (res$status_code != 200) {
    fail(paste0("HTTP status ", res$status_code, " from ", url, "."))
  }
  tryCatch(
    jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE),
    error = function(e) fail("The response is not valid JSON.")
  )
}

# The .duckdb file listed in the record: its name, download URL, size and lower-case MD5.
record_db_file <- function(json, pin, call) {
  files <- json$files
  keys <- vapply(files, function(f) as.character(if_null(f$key, "")), character(1))
  hit <- which(grepl("\\.duckdb$", keys))
  if (length(hit) == 0) {
    abort_not_found(c(
      "Zenodo record {pin$record} has no {.file .duckdb} file.",
      "i" = "This ausparl release ({pin$version}) pins a record without the database. Install
             a newer ausparl release, or pass {.arg path} to {.fn db_connect}."
    ), call = call)
  }
  f <- files[[hit[1]]]
  checksum <- as.character(if_null(f$checksum, ""))
  if (!startsWith(checksum, "md5:")) {
    abort_db(c(
      "Zenodo record {pin$record} lists no MD5 checksum for {.file {keys[hit[1]]}}.",
      "i" = "The download cannot be verified. Pass {.arg path} to {.fn db_connect} instead."
    ), call = call)
  }
  url <- if_null(
    f$links$self,
    paste0(zenodo_api, pin$record, "/files/", keys[hit[1]], "/content")
  )
  list(
    key = keys[hit[1]],
    url = url,
    size = as.numeric(if_null(f$size, NA)),
    md5 = tolower(sub("^md5:", "", checksum))
  )
}

# Downloads `url` into `destfile`, resuming a partial file. A failed transfer keeps the partial
# file so the next call resumes it.
download_file <- function(url, destfile, call = rlang::caller_env()) {
  fail <- function(detail) {
    abort_db(c(
      "The database download did not finish.",
      "x" = detail,
      "i" = "Run {.code db_download()} again with the same arguments to resume it."
    ), call = call)
  }
  # timeout = 0 is libcurl's "no limit": a 9.5 GB transfer must not be cut off.
  res <- tryCatch(
    curl::multi_download(
      url, destfile,
      resume = TRUE, timeout = 0, progress = interactive(), failonerror = TRUE
    ),
    error = function(e) fail(conditionMessage(e))
  )
  status <- res$status_code[1]
  # 416: the partial file is already complete, so there is nothing left to fetch.
  complete <- isTRUE(status == 416) && isTRUE(res$resumefrom[1] > 0)
  if (!complete && !(isTRUE(res$success[1]) && isTRUE(status %in% c(200, 206)))) {
    error <- res$error[1]
    fail(if (is.na(error)) paste0("HTTP status ", status, ".") else error)
  }
  invisible(destfile)
}

format_size <- function(bytes) {
  if (is.na(bytes)) {
    return("size unknown")
  }
  format(structure(bytes, class = "object_size"), units = "auto", standard = "SI")
}

if_null <- function(x, y) if (is.null(x)) y else x
