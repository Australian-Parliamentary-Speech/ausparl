# Checks on the precomputed main vignette. None of them touches a
# database: VG1 parses the source, VG3 reads the generated file, VG4 renders it with no DB.
# They need the source tree's vignettes/ directory, so they skip in an installed package or
# R CMD check, where it is absent or holds no .orig.

vignette_dir <- function() {
  dir <- testthat::test_path("..", "..", "vignettes")
  testthat::skip_if_not(dir.exists(dir), "vignettes/ directory not available")
  dir
}

vignette_file <- function(name) {
  path <- file.path(vignette_dir(), name)
  testthat::skip_if_not(file.exists(path), paste("vignettes/", name, "not available"))
  path
}

# The code of every ```{r} chunk in an R Markdown file, as one character vector.
rmd_chunk_code <- function(path) {
  lines <- readLines(path, warn = FALSE)
  starts <- grep("^```\\{r", lines)
  ends <- grep("^```\\s*$", lines)
  code <- lapply(starts, function(s) {
    e <- min(ends[ends > s])
    if (e - s > 1) lines[(s + 1):(e - 1)] else character()
  })
  unlist(code)
}

# DuckDB SQL functions the vignette uses inside dbplyr verbs; dbplyr passes them through to
# the database, so they are not R functions.
sql_only_functions <- "year"

# The parse data of every ```{r} chunk in the vignette source.
vignette_parse_data <- function() {
  code <- rmd_chunk_code(vignette_file("ausparl.Rmd.orig"))
  utils::getParseData(parse(text = code, keep.source = TRUE))
}

# The names of every function the vignette source calls, found by parsing the chunks.
vignette_calls <- function() {
  parsed <- vignette_parse_data()
  unique(parsed$text[parsed$token == "SYMBOL_FUNCTION_CALL"])
}

test_that("T-4.10 VG1: the source covers the eight sections of the vignette outline in order", {
  lines <- readLines(vignette_file("ausparl.Rmd.orig"), warn = FALSE)
  headings <- grep("^## [0-9]+\\. ", lines, value = TRUE)
  expect_identical(as.integer(sub("^## ([0-9]+)\\..*", "\\1", headings)), 1:8)

  calls <- vignette_calls()
  required <- c(
    "db_connect", "db_info", "find_member", "member_profile", "get_speeches",
    "search_speeches_by_terms", "add_party", "add_role", "add_government_status",
    "member_activity", "as_corpus"
  )
  expect_true(all(required %in% calls), info = setdiff(required, calls))

  # Nothing it calls is an ausparl function that is not exported (an internal helper, or a
  # deferred one such as a download function).
  internal <- setdiff(
    ls(asNamespace("ausparl"), all.names = TRUE),
    getNamespaceExports("ausparl")
  )
  expect_identical(intersect(calls, internal), character())
})

test_that("T-4.10 VG1: the source calls only exported ausparl functions and base, dplyr, ggplot2", {
  testthat::skip_if_not_installed("ggplot2")
  parsed <- vignette_parse_data()

  pkgs <- unique(parsed$text[parsed$token == "SYMBOL_PACKAGE"])
  expect_length(pkgs, 0)

  allowed <- c(
    getNamespaceExports("ausparl"),
    ls(baseenv(), all.names = TRUE),
    getNamespaceExports("stats"),
    getNamespaceExports("utils"),
    getNamespaceExports("dplyr"),
    getNamespaceExports("ggplot2"),
    sql_only_functions
  )
  expect_identical(setdiff(vignette_calls(), allowed), character())
})

test_that("T-4.10 VG3: the generated vignette has no live code and no database path", {
  path <- vignette_file("ausparl.Rmd")
  lines <- readLines(path, warn = FALSE)

  expect_false(any(grepl("^\\s*```\\s*\\{", lines)))
  expect_false(any(grepl("`r ", lines, fixed = TRUE)))
  expect_false(any(grepl("(^|[^A-Za-z0-9_])(/Users/|/home/|[A-Za-z]:\\\\)", lines)))

  # The only database path is the placeholder in step 1.
  db_paths <- unlist(regmatches(lines, gregexpr("[^\" ]*\\.duckdb", lines)))
  expect_setequal(db_paths[grepl("/", db_paths)], "/path/to/hansard.duckdb")

  # Every figure it refers to is committed next to it.
  figs <- unlist(regmatches(lines, gregexpr("(?<=src=\")[^\"]+\\.png", lines, perl = TRUE)))
  expect_gt(length(figs), 0)
  expect_true(all(!grepl("/", figs, fixed = TRUE)))
  expect_true(all(file.exists(file.path(vignette_dir(), figs))))
})

test_that("T-4.10 VG4: the generated vignette renders without a database", {
  skip_on_cran()
  skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  src <- vignette_file("ausparl.Rmd")

  dir <- withr::local_tempdir()
  figs <- list.files(vignette_dir(), pattern = "\\.png$", full.names = TRUE)
  file.copy(c(src, figs), dir)
  withr::local_envvar(AUSPARL_DB = NA)

  out <- rmarkdown::render(
    file.path(dir, "ausparl.Rmd"),
    output_dir = dir, quiet = TRUE, envir = new.env()
  )
  expect_true(file.exists(out))
  html <- readLines(out, warn = FALSE)
  expect_true(any(grepl("Hand off to text analysis", html, fixed = TRUE)))
})
