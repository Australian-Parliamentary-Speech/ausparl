# Connection lifecycle. The database is always opened read-only, and its schema major version
# must match the one this package was written against.

.ausparl <- new.env(parent = emptyenv())

supported_schema_major <- 7L
builder_version_columns <- c("ausparl_version", "pipeline_version")

#' Connect to the Hansard database
#'
#' Opens the package's single read-only connection to the Australian Hansard DuckDB database.
#' Any connection already open is closed first. The database file is never written to.
#'
#' The file is chosen as follows. An explicit `path` or `sample = TRUE` is used as given
#' (passing both is an error). With neither, the `AUSPARL_DB` environment variable is used.
#' Without that either, the copy installed by [db_download()] for the database version this
#' release of ausparl pins is used, and a message says which version was opened.
#' `db_connect()` never downloads anything itself.
#'
#' On connect the DuckDB full-text-search extension (`fts`) is loaded. If it is not installed
#' yet, it is installed once into `tools::R_user_dir("ausparl", "cache")`, which needs network
#' access. Installation never happens during tests or `R CMD check`, and is switched off with
#' `options(ausparl.auto_install_fts = FALSE)`. Without `fts` every other function works;
#' full-text search reports how to install it.
#'
#' DuckDB's memory use is capped by the `ausparl.memory_limit` option, default `"3GB"`. Accepted
#' values are a size with a unit, such as `"500MB"`, `"1.5GB"` or `"2GiB"`; anything else is an
#' error and the current connection stays open. The cap bounds query execution itself, not just
#' the results returned to R: a large query spills to disk rather than exceeding it, so expect
#' peak R process memory of roughly the cap plus twice the result. Spill files go to an
#' `ausparl-duckdb` directory under [tempdir()], never beside the database file, and are removed
#' when the R session ends. Change the option, then call `db_connect()` again to apply it.
#'
#' @param path Path to a `hansard.duckdb` file.
#' @param sample If `TRUE`, use the small sample database bundled with the package.
#' @return The DBI connection, invisibly.
#' @seealso [db_disconnect()], [db_info()], [db_download()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' db_info()
#' db_disconnect()
db_connect <- function(path = NULL, sample = FALSE) {
  call <- rlang::current_env()
  path <- resolve_db_path(path, sample, call = call)
  # Validated before the current connection is closed, so a bad option leaves it intact.
  memory_limit <- resolve_memory_limit(call = call)
  db_disconnect()

  # Extensions live in the ausparl user cache, so fts installs once per machine. shared_home =
  # FALSE keeps duckdb from using ~/.duckdb and silences its per-session storage notice.
  # memory_limit bounds query execution; temp_directory keeps spills out of the (read-only)
  # database directory and in the session temp directory.
  # Driver creation shares the tryCatch with dbConnect(): duckdb opens the file when the driver
  # is created, so a file that is not a DuckDB database fails there.
  con <- tryCatch(
    DBI::dbConnect(duckdb::duckdb(
      dbdir = path, read_only = TRUE, shared_home = FALSE,
      config = list(
        extension_directory = fts_extension_dir(),
        memory_limit = memory_limit,
        temp_directory = duckdb_temp_dir()
      )
    )),
    error = function(e) {
      # duckdb messages can contain braces, which cli would otherwise interpolate.
      abort_db(c(
        "Could not open the database at {.file {path}}.",
        "x" = gsub("([{}])", "\\1\\1", conditionMessage(e)),
        "i" = "Check that the file is a DuckDB database written by DuckDB >= 1.5.5."
      ), call = call)
    }
  )

  tryCatch(
    check_schema(con, path, call = call),
    error = function(e) {
      DBI::dbDisconnect(con, shutdown = TRUE)
      stop(e)
    }
  )

  .ausparl$con <- con
  .ausparl$path <- path
  .ausparl$last_path <- path
  .ausparl$fts <- load_fts(con)
  invisible(con)
}

#' Disconnect from the Hansard database
#'
#' Closes the package connection, if one is open. Safe to call at any time.
#'
#' @return `TRUE` if a connection was closed, `FALSE` otherwise, invisibly.
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' db_disconnect()
db_disconnect <- function() {
  con <- .ausparl$con
  .ausparl$con <- NULL
  .ausparl$path <- NULL
  .ausparl$fts <- NULL
  if (is.null(con) || !DBI::dbIsValid(con)) {
    return(invisible(FALSE))
  }
  DBI::dbDisconnect(con, shutdown = TRUE)
  invisible(TRUE)
}

#' The current database connection
#'
#' Returns the package connection, opening one if needed: the last database used in this
#' session if there was one, otherwise the database [db_connect()] finds with no arguments
#' (`AUSPARL_DB`, then the copy installed by [db_download()]). Every query function calls
#' this, so you rarely need it directly.
#'
#' @return A DBI connection.
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' DBI::dbListTables(db_con())
#' db_disconnect()
db_con <- function() {
  con <- .ausparl$con
  if (!is.null(con) && DBI::dbIsValid(con)) {
    return(con)
  }
  last <- .ausparl$last_path
  if (!is.null(last) && file.exists(last)) {
    db_connect(path = last)
  } else {
    db_connect()
  }
  .ausparl$con
}

#' A lazy table for any table or view
#'
#' Escape hatch to any table or view in the database, as a lazy `dplyr` table. Nothing is read
#' until you `collect()` it.
#'
#' @param name Table or view name, e.g. `"actions"`, `"v_speech"`, or `"schema.table"` such as
#'   `"fts_main_actions.docs"`.
#' @param con A DBI connection; defaults to the package connection.
#' @return A lazy `tbl`.
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' db_tbl("sittings")
#' db_disconnect()
db_tbl <- function(name, con = db_con()) {
  if (!rlang::is_string(name) || !nzchar(name)) {
    abort_input("{.arg name} must be a single table or view name, not {.obj_type_friendly {name}}.")
  }
  parts <- strsplit(name, ".", fixed = TRUE)[[1]]
  if (length(parts) > 2) {
    abort_input("{.arg name} must be {.val table} or {.val schema.table}, not {.val {name}}.")
  }
  schema <- if (length(parts) == 2) parts[1] else "main"
  table <- parts[length(parts)]

  known <- db_objects(con)
  if (!any(known$schema_name == schema & known$name == table)) {
    candidates <- ifelse(known$schema_name == "main", known$name,
      paste0(known$schema_name, ".", known$name)
    )
    close <- candidates[agrepl(name, candidates, max.distance = 0.2)]
    abort_not_found(c(
      "No table or view named {.val {name}}.",
      "i" = if (length(close)) "Did you mean {.or {.val {close}}}?",
      "i" = "List them with {.code DBI::dbListTables(db_con())}."
    ))
  }
  if (schema == "main") {
    dplyr::tbl(con, table)
  } else {
    dplyr::tbl(con, DBI::Id(schema = schema, table = table))
  }
}

#' Database version and size
#'
#' Reports which database the connection points at: schema version, build time, the version
#' of the pipeline that built it, whether full-text search is available, and basic row counts.
#' Use it to check versions and to record the exact build you used.
#'
#' @param con A DBI connection; defaults to the package connection.
#' @return A one-row tibble.
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' db_info()
#' db_disconnect()
db_info <- function(con = db_con()) {
  sv <- DBI::dbGetQuery(con, "SELECT * FROM schema_version LIMIT 1")
  builder_col <- intersect(builder_version_columns, names(sv))[1]
  count <- function(tbl) {
    DBI::dbGetQuery(con, paste("SELECT count(*) AS n FROM", tbl))$n
  }
  tibble::tibble(
    schema_version = as.character(sv$schema_version),
    built_at = sv$built_at,
    builder_version = if (is.na(builder_col)) NA_character_ else as.character(sv[[builder_col]]),
    path = DBI::dbGetInfo(con)$dbname,
    fts_available = fts_loaded(con),
    n_sittings = as.integer(count("sittings")),
    n_actions = as.integer(count("actions")),
    n_members = as.integer(count("members"))
  )
}

# ---- internals ---------------------------------------------------------------------------------

resolve_db_path <- function(path, sample, call) {
  if (!rlang::is_bool(sample)) {
    abort_input("{.arg sample} must be {.code TRUE} or {.code FALSE}.", call = call)
  }
  if (!is.null(path) && sample) {
    abort_input(
      "Supply either {.arg path} or {.code sample = TRUE}, not both.",
      call = call
    )
  }
  if (!is.null(path)) {
    if (!rlang::is_string(path) || !nzchar(path)) {
      abort_input("{.arg path} must be a single file path.", call = call)
    }
  } else if (sample) {
    path <- system.file("extdata", "ausparl-sample.duckdb", package = "ausparl")
  } else if (nzchar(Sys.getenv("AUSPARL_DB"))) {
    path <- Sys.getenv("AUSPARL_DB")
  } else {
    data_version <- pinned_release()$data_version
    path <- cached_db_path(data_version)
    if (is.null(path)) {
      abort_db(c(
        "No database to connect to.",
        "i" = "Pass {.arg path}, set the {.envvar AUSPARL_DB} environment variable to your
               {.file hansard.duckdb}, download the database once with {.code db_download()},
               or use {.code db_connect(sample = TRUE)}."
      ), call = call)
    }
    cli::cli_inform("Opening the downloaded database {.val {data_version}}.")
  }
  if (!file.exists(path)) {
    abort_not_found(c(
      "Database file {.file {path}} does not exist.",
      "i" = "Check the path, or {.envvar AUSPARL_DB} if you set it."
    ), call = call)
  }
  normalizePath(path)
}

check_schema <- function(con, path, call) {
  if (!DBI::dbExistsTable(con, "schema_version")) {
    abort_db(c(
      "{.file {path}} has no {.field schema_version} table, so it is not an ausparl Hansard
       database.",
      "i" = "Download the database with {.fn db_download}, or point {.envvar AUSPARL_DB} or
             {.arg path} at a {.file hansard.duckdb} file."
    ), call = call)
  }
  version <- DBI::dbGetQuery(con, "SELECT schema_version FROM schema_version LIMIT 1")
  version <- as.character(version$schema_version)
  major <- suppressWarnings(as.integer(sub("\\..*$", "", version)))
  if (length(major) != 1 || is.na(major) || major != supported_schema_major) {
    abort_db(c(
      "Database schema {.val {version}} is not supported.",
      "i" = "This version of ausparl reads schema {supported_schema_major}.x.",
      "i" = "Install the ausparl release that matches the database, or use a matching
             database."
    ), call = call)
  }
  invisible(version)
}

memory_limit_pattern <- "^\\s*[0-9]+(\\.[0-9]+)?\\s*(KB|MB|GB|TB|KiB|MiB|GiB|TiB)\\s*$"

resolve_memory_limit <- function(call) {
  limit <- getOption("ausparl.memory_limit", "3GB")
  if (!rlang::is_string(limit) || !grepl(memory_limit_pattern, limit, ignore.case = TRUE)) {
    abort_input(c(
      "Option {.code ausparl.memory_limit} must be a single size such as {.val 3GB},
       not {.obj_type_friendly {limit}}.",
      "i" = "Set it with, e.g., {.code options(ausparl.memory_limit = \"1.5GB\")}, or unset it
             with {.code options(ausparl.memory_limit = NULL)} for the 3GB default."
    ), call = call)
  }
  trimws(limit)
}

duckdb_temp_dir <- function() {
  file.path(tempdir(), "ausparl-duckdb")
}

fts_extension_dir <- function() {
  tools::R_user_dir("ausparl", "cache")
}

fts_loaded <- function(con) {
  res <- DBI::dbGetQuery(
    con, "SELECT loaded FROM duckdb_extensions() WHERE extension_name = 'fts'"
  )
  isTRUE(res$loaded[1])
}

# Installation is never attempted under tests or R CMD check, or when the user opts out.
may_install_fts <- function() {
  in_check <- identical(Sys.getenv("TESTTHAT"), "true") ||
    nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_"))
  !in_check && isTRUE(getOption("ausparl.auto_install_fts", TRUE))
}

install_fts <- function(con) {
  dir.create(fts_extension_dir(), recursive = TRUE, showWarnings = FALSE)
  DBI::dbExecute(con, "INSTALL fts")
}

load_fts_extension <- function(con) {
  DBI::dbExecute(con, "LOAD fts")
}

load_fts <- function(con) {
  try_load <- function() {
    tryCatch(
      {
        load_fts_extension(con)
        TRUE
      },
      error = function(e) FALSE
    )
  }
  if (try_load()) {
    return(TRUE)
  }
  if (!may_install_fts()) {
    return(FALSE)
  }
  cli::cli_inform("Installing the DuckDB {.pkg fts} extension (one-time, needs network).")
  installed <- tryCatch(
    {
      install_fts(con)
      TRUE
    },
    error = function(e) FALSE
  )
  if (installed && try_load()) {
    return(TRUE)
  }
  cli::cli_inform(c(
    "!" = "Full-text search is unavailable: the {.pkg fts} extension could not be installed.",
    "i" = "Connect once with network access, or run {.code DBI::dbExecute(db_con(), \"INSTALL
           fts\")}. Other functions work without it."
  ))
  FALSE
}

db_objects <- function(con) {
  DBI::dbGetQuery(con, "
    SELECT schema_name, table_name AS name FROM duckdb_tables()
    UNION ALL
    SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal
  ")
}

.onUnload <- function(libpath) {
  db_disconnect()
}
