# Tests for the quanteda hand-off (P1-P7): as_corpus().
# Sample DB only; no network. The function issues no SQL, so there is no SQL snapshot.

local_corpus_ap <- function(env = parent.frame()) {
  withr::local_envvar(AUSPARL_DB = NA, .local_envir = env)
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

skip_if_no_fts_corpus <- function() {
  testthat::skip_on_cran()
  ok <- tryCatch(
    {
      load_fts_extension(db_con())
      TRUE
    },
    error = function(e) FALSE
  )
  testthat::skip_if_not(ok, "the DuckDB fts extension cannot be loaded")
}

docvar_frame <- function(corp) {
  dv <- quanteda::docvars(corp)
  rownames(dv) <- NULL
  dv
}

plain_frame <- function(d, drop) {
  d <- as.data.frame(d)[, setdiff(names(d), drop), drop = FALSE]
  rownames(d) <- NULL
  d
}

test_that("T-4.7 P1: a corpus from get_speeches() is valid", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  speeches <- get_speeches(from = 2002, to = 2002, limit = 25)
  expect_gt(nrow(speeches), 0)

  corp <- as_corpus(speeches)

  expect_true(quanteda::is.corpus(corp))
  expect_identical(quanteda::ndoc(corp), nrow(speeches))
  expect_identical(quanteda::docnames(corp), speeches$action_id)
  expect_identical(unname(as.character(corp)), speeches$content)
})

test_that("T-4.7 P2: the other columns become docvars with names, values and types kept", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  speeches <- get_speeches(from = 2002, to = 2002, limit = 25)

  dv <- docvar_frame(as_corpus(speeches))

  expect_identical(dv, plain_frame(speeches, c("action_id", "content")))
  expect_s3_class(dv$date, "Date")
  expect_type(dv$is_speech, "logical")
  expect_type(dv$has_quote, "logical")
  expect_type(dv$parliament_id, "integer")
})

test_that("T-4.7 P3: lazy input gives the same corpus as tibble input", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  lazy <- get_speeches(from = 2002, to = 2002, collect = FALSE)
  # Sort both, since rows from DuckDB are not in a set order.
  sort_corpus <- function(corp) corp[order(quanteda::docnames(corp), method = "radix")]

  from_lazy <- sort_corpus(as_corpus(lazy))
  from_tibble <- sort_corpus(as_corpus(dplyr::collect(lazy)))

  expect_identical(quanteda::docnames(from_lazy), quanteda::docnames(from_tibble))
  expect_identical(as.character(from_lazy), as.character(from_tibble))
  expect_identical(docvar_frame(from_lazy), docvar_frame(from_tibble))
})

test_that("T-4.18 P3: lazy text input over the text ceiling is an input error", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  withr::local_options(ausparl.max_rows_text = 3)
  lazy <- get_speeches(from = 2002, to = 2002, collect = FALSE)

  expect_error(as_corpus(lazy), class = "ausparl_input_error")
})

test_that("T-4.7 P4: composes with search output; search columns become docvars", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  skip_if_no_fts_corpus()
  hits <- search_speeches_by_terms("government", limit = 10)
  skip_if(nrow(hits) == 0, "no search hits on the sample")

  corp <- as_corpus(hits)
  dv <- docvar_frame(corp)

  expect_identical(quanteda::docnames(corp), hits$action_id)
  expect_identical(unname(as.character(corp)), hits$content)
  expect_identical(dv, plain_frame(hits, c("action_id", "content")))
  expect_true(all(c("score", "n_hits") %in% names(dv)))
})

test_that("T-4.7 P4: composes with add_party() output; added columns become docvars", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  turns <- get_speeches(
    from = 2002, to = 2002, limit = 25, columns = c("action_id", "sitting_id", "content")
  )
  with_party <- add_party(turns)

  corp <- as_corpus(with_party)
  dv <- docvar_frame(corp)

  expect_identical(quanteda::docnames(corp), with_party$action_id)
  expect_true(all(c("party_id_at_time", "party_at_time", "party_abbrev_at_time") %in% names(dv)))
  expect_identical(dv, plain_frame(with_party, c("action_id", "content")))
})

test_that("T-4.7 P5: a result without content is an input error", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  no_text <- get_speeches(from = 2002, to = 2002, limit = 5, include_text = FALSE)

  expect_error(as_corpus(no_text), class = "ausparl_input_error")
  expect_error(
    as_corpus(no_text, text_field = "other"),
    class = "ausparl_input_error"
  )
  expect_error(
    as_corpus(no_text, text_field = "chamber_venue"),
    class = "ausparl_input_error"
  )
})

test_that("T-4.7 P5: duplicate, NA or missing docids are input errors", {
  skip_if_not_installed("quanteda")
  d <- data.frame(action_id = c("a", "b", "c"), content = c("x", "y", "z"))

  dup <- d
  dup$action_id[3] <- "a"
  expect_error(as_corpus(dup), class = "ausparl_input_error")

  na_id <- d
  na_id$action_id[2] <- NA
  expect_error(as_corpus(na_id), class = "ausparl_input_error")

  expect_error(as_corpus(d, docid_field = "nope"), class = "ausparl_input_error")

  listy <- tibble::tibble(action_id = list(1, 2, 3), content = c("x", "y", "z"))
  expect_error(as_corpus(listy), class = "ausparl_input_error")
})

test_that("T-4.7 P5: a wrong x or field argument is an input error", {
  skip_if_not_installed("quanteda")
  expect_error(as_corpus("some text"), class = "ausparl_input_error")
  expect_error(as_corpus(list(content = "x", action_id = "a")), class = "ausparl_input_error")
  expect_error(as_corpus(NULL), class = "ausparl_input_error")

  d <- data.frame(action_id = "a", content = "x")
  expect_error(as_corpus(d, text_field = c("a", "b")), class = "ausparl_input_error")
  expect_error(as_corpus(d, text_field = ""), class = "ausparl_input_error")
  expect_error(as_corpus(d, docid_field = 1), class = "ausparl_input_error")
  expect_error(
    as_corpus(d, text_field = "content", docid_field = "content"),
    class = "ausparl_input_error"
  )
})

test_that("T-4.7 P6: a custom text_field and docid_field are honoured", {
  skip_if_not_installed("quanteda")
  d <- tibble::tibble(
    doc = c("d1", "d2"),
    body = c("first text", "second text"),
    content = c("not this", "nor this"),
    when = as.Date(c("2000-01-01", "2001-02-03")),
    flag = c(TRUE, NA)
  )

  corp <- as_corpus(d, text_field = "body", docid_field = "doc")
  dv <- docvar_frame(corp)

  expect_identical(quanteda::docnames(corp), d$doc)
  expect_identical(unname(as.character(corp)), d$body)
  expect_identical(dv, plain_frame(d, c("doc", "body")))
})

test_that("T-4.7 P6: text is not edited; NA text is passed to quanteda unchanged", {
  skip_if_not_installed("quanteda")
  d <- tibble::tibble(
    action_id = c("a", "b", "c"),
    content = c("  Spaced  <b>markup</b>\n", NA, "Ünïcödé — text")
  )
  expected <- suppressWarnings(
    quanteda::corpus(as.data.frame(d), docid_field = "action_id", text_field = "content")
  )

  corp <- suppressWarnings(as_corpus(d))

  expect_identical(corp, expected)
  expect_identical(unname(as.character(corp))[c(1, 3)], d$content[c(1, 3)])
})

test_that("T-4.20 P1: a zero-row result gives an empty corpus", {
  skip_if_not_installed("quanteda")
  local_corpus_ap()
  none <- get_speeches(from = 2002, to = 2002, limit = 1)[0, ]

  corp <- as_corpus(none)

  expect_identical(quanteda::ndoc(corp), 0L)
  expect_identical(names(quanteda::docvars(corp)), setdiff(names(none), c("action_id", "content")))
})
