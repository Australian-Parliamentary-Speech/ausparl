# Tests for full-text term search (R1-R12): search_speeches_by_terms().
# Sample DB only; no network. Tests that run a search need the fts extension, so they skip on
# CRAN and when it cannot be loaded; the missing-index, missing-extension and input checks
# do not need it.

local_search_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

skip_if_no_fts <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(fts_loaded(db_con()), "the DuckDB fts extension cannot be loaded")
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

by_action <- function(d) {
  d <- as.data.frame(d)
  d <- d[order(d$action_id, method = "radix"), , drop = FALSE]
  rownames(d) <- NULL
  d
}

quote_str <- function(x) as.character(DBI::dbQuoteString(db_con(), x))

# The B1 default and presiding-officer rule, written by hand over v_speech.
b1_where <- "(v.is_speech OR v.is_question OR v.is_answer) AND NOT v.is_interjection
             AND (v.resolution IS NULL OR v.resolution <> 'sentinel')"

# The two-stage reference SQL (BM25 candidates, then a regex check), generalised to several
# patterns and restricted to the B1 turns of v_speech. `fts_query = NULL` gives the regex-only
# scan; `patterns = NULL` the FTS candidates alone.
reference_sql <- function(fts_query, patterns, conjunctive = TRUE, where = b1_where,
                          years = NULL) {
  op <- if (conjunctive) " AND " else " OR "
  year_where <- "TRUE"
  if (!is.null(years)) year_where <- sprintf("year BETWEEN %d AND %d", years[1], years[2])
  candidates <- if (is.null(fts_query)) {
    "SELECT action_id, NULL::DOUBLE AS score FROM actions"
  } else {
    sprintf("
      SELECT action_id, score FROM (
        SELECT action_id,
               fts_main_actions.match_bm25(action_id, %s, conjunctive := %d) AS score
        FROM actions WHERE %s
      ) t WHERE score IS NOT NULL", quote_str(fts_query), as.integer(conjunctive), year_where)
  }
  if (is.null(patterns)) {
    n_hits <- "NULL::INTEGER"
    verify <- "TRUE"
  } else {
    p <- vapply(patterns, quote_str, character(1))
    n_hits <- paste0(
      "(", paste0("len(regexp_extract_all(a.content, ", p, ", 0, 'i'))", collapse = " + "), ")"
    )
    verify <- paste0("(", paste0("regexp_matches(a.content, ", p, ", 'i')", collapse = op), ")")
  }
  paste0("
    WITH candidates AS (", candidates, ")
    SELECT a.action_id, s.date, c.score, CAST(", n_hits, " AS INTEGER) AS n_hits
    FROM candidates c
    JOIN actions a USING (action_id)
    JOIN sittings s ON s.sitting_id = a.sitting_id
    JOIN v_speech v ON v.action_id = a.action_id
    WHERE ", where, " AND ", verify)
}

expect_search_equal <- function(got, sql) {
  direct <- DBI::dbGetQuery(db_con(), sql)
  expect_gt(nrow(got), 0)
  expect_equal(by_action(got[c("action_id", "date", "score", "n_hits")]), by_action(direct))
}

search <- function(...) search_speeches_by_terms(..., include_text = FALSE)

# ---- R1 known term against the reference SQL ----------------------------------------------------

test_that("T-4.3 R1: a known term returns a known turn; rows and n_hits equal the reference SQL", {
  local_search_ap()
  skip_if_no_fts()
  got <- search("immigration")
  expect_s3_class(got, "tbl_df")
  expect_true("house_1990-09-17_R149" %in% got$action_id)
  expect_search_equal(got, reference_sql("immigration", "\\bimmigration\\b"))

  # The year range restricts recall; the dates restrict the rows.
  expect_search_equal(
    search("immigration", from = 1996, to = "2002-10-15"),
    reference_sql(
      "immigration", "\\bimmigration\\b",
      where = paste(b1_where, "AND s.date BETWEEN DATE '1996-01-01' AND DATE '2002-10-15'"),
      years = c(1996, 2002)
    )
  )
  expect_search_equal(
    search("foreign affairs"),
    reference_sql("foreign affairs", "\\bforeign\\s+affairs\\b")
  )
})

# ---- R2 exact matching --------------------------------------------------------------------------

test_that("R2: patterns are case-insensitive, bounded, whitespace-tolerant and literal", {
  expect_identical(term_pattern("immigration"), "\\bimmigration\\b")
  expect_identical(term_pattern(" same-sex   marriage "), "\\bsame-sex\\s+marriage\\b")
  expect_identical(term_pattern("LGBTIQ+"), "\\bLGBTIQ\\+")
  expect_identical(term_pattern("C++"), "\\bC\\+\\+")
  expect_identical(term_pattern("(a.b)"), "\\(a\\.b\\)")
  expect_identical(term_pattern("[x]|{y}^$*?\\"), "\\[x\\]\\|\\{y\\}\\^\\$\\*\\?\\\\")

  # Evaluated by DuckDB's RE2, as the search does.
  con <- local_sample_con()
  matches <- function(term, text) {
    DBI::dbGetQuery(con, "SELECT regexp_matches(?, ?, 'i') AS m", params = list(
      text, term_pattern(term)
    ))$m
  }
  cases <- list(
    list("immigration", "On IMMIGRATION, policy.", TRUE),
    list("immigration", "immigrations", FALSE),
    list("immigration", "preimmigration", FALSE),
    list("LGBTIQ+", "lgbtiq+ people", TRUE),
    list("LGBTIQ+", "LGBTIQ people", FALSE),
    list("LGBTIQ+", "xLGBTIQ+", FALSE),
    list("C++", "written in c++.", TRUE),
    list("C++", "a C+ grade", FALSE),
    list("C++", "ABC++", FALSE),
    list("same-sex marriage", "Same-Sex\n   Marriage", TRUE),
    list("same-sex marriage", "same-sex marriages", FALSE),
    list("same-sex marriage", "same sex marriage", FALSE)
  )
  for (case in cases) {
    expect_identical(matches(case[[1]], case[[2]]), case[[3]], info = paste(case[[1]], case[[2]]))
  }
})

test_that("R2: search verifies matches exactly on the sample", {
  local_search_ap()
  skip_if_no_fts()
  expect_identical(search("IMMIGRATION")$action_id, search("immigration")$action_id)
  # Stemmed recall finds "immigration" for "immigrations"; exact verification drops it.
  expect_gt(nrow(search("immigrations", exact = FALSE)), 0)
  expect_identical(nrow(search("immigrations")), 0L)
  # No turn in the sample contains LGBTIQ+ or C++.
  direct <- DBI::dbGetQuery(db_con(), "
    SELECT count(*) AS n FROM actions WHERE regexp_matches(content, '\\bLGBTIQ\\+|\\bC\\+\\+', 'i')
  ")$n
  expect_identical(as.integer(direct), 0L)
  expect_identical(nrow(search("LGBTIQ+")), 0L)
  expect_identical(nrow(suppressMessages(search("C++"))), 0L)
})

# ---- R3 conjunctive -----------------------------------------------------------------------------

test_that("R3: conjunctive TRUE and FALSE each equal direct SQL", {
  local_search_ap()
  skip_if_no_fts()
  terms <- c("government", "minister")
  patterns <- c("\\bgovernment\\b", "\\bminister\\b")
  all <- search(terms)
  any <- search(terms, conjunctive = FALSE)
  expect_search_equal(all, reference_sql("government minister", patterns))
  expect_search_equal(any, reference_sql("government minister", patterns, conjunctive = FALSE))
  expect_lt(nrow(all), nrow(any))
  expect_true(all(all$action_id %in% any$action_id))
  expect_setequal(
    any$action_id,
    union(search("government")$action_id, search("minister")$action_id)
  )
})

# ---- R4 stopwords in a phrase -------------------------------------------------------------------

test_that("R4: a phrase containing a stopword returns matches", {
  local_search_ap()
  skip_if_no_fts()
  # Passed whole, the stopword "for" is not in the index and recall finds nothing.
  raw <- DBI::dbGetQuery(db_con(), "
    SELECT count(*) AS n FROM (
      SELECT fts_main_actions.match_bm25(action_id, 'Minister for Foreign Affairs',
                                         conjunctive := 1) AS score FROM actions
    ) WHERE score IS NOT NULL
  ")$n
  expect_identical(as.integer(raw), 0L)

  got <- search("Minister for Foreign Affairs")
  expect_true("house_2002-10-15_R2" %in% got$action_id)
  expect_search_equal(
    got,
    reference_sql("minister foreign affairs", "\\bMinister\\s+for\\s+Foreign\\s+Affairs\\b")
  )
})

# ---- R5 token fallback --------------------------------------------------------------------------

test_that("R5: an all-stopword or digit-only term falls back to a regex scan", {
  local_search_ap()
  skip_if_no_fts()
  count_messages <- function(expr) {
    n <- 0L
    value <- withCallingHandlers(expr, message = function(m) {
      n <<- n + 1L
      invokeRestart("muffleMessage")
    })
    list(value = value, n = n)
  }

  stop <- count_messages(search("of the"))
  expect_identical(stop$n, 1L)
  expect_true(all(is.na(stop$value$score)))
  expect_identical(class(stop$value$score), "numeric")
  expect_search_equal(stop$value, reference_sql(NULL, "\\bof\\s+the\\b"))

  digits <- count_messages(search(c("1996", "government")))
  expect_identical(digits$n, 1L)
  expect_true(all(is.na(digits$value$score)))
  expect_search_equal(
    digits$value, reference_sql(NULL, c("\\b1996\\b", "\\bgovernment\\b"))
  )

  either <- count_messages(search(c("1996", "immigration"), conjunctive = FALSE))
  expect_identical(either$n, 1L)
  expect_search_equal(
    either$value,
    reference_sql(NULL, c("\\b1996\\b", "\\bimmigration\\b"), conjunctive = FALSE)
  )

  # exact = FALSE keeps n_hits NA; the rows still come from the regex scan.
  loose <- count_messages(search("1996", exact = FALSE))
  expect_identical(loose$n, 1L)
  expect_true(all(is.na(loose$value$n_hits)))
  expect_identical(
    sort(loose$value$action_id),
    sort(search("1996") |> suppressMessages() |> dplyr::pull("action_id"))
  )
})

# ---- R6 exact = FALSE ---------------------------------------------------------------------------

test_that("R6: exact = FALSE returns the FTS candidate set with n_hits NA", {
  local_search_ap()
  skip_if_no_fts()
  got <- search("tariff", exact = FALSE)
  expect_true(all(is.na(got$n_hits)))
  expect_identical(class(got$n_hits), "integer")
  expect_search_equal(got, reference_sql("tariff", NULL))
  expect_search_equal(
    search(c("tariff", "immigration"), exact = FALSE, conjunctive = FALSE),
    reference_sql("tariff immigration", NULL, conjunctive = FALSE)
  )
  expect_true(all(search("tariff")$action_id %in% got$action_id))
})

# ---- R7 B1 and filters --------------------------------------------------------------------------

test_that("T-4.17 R7: B1 excludes interjections by default; filters act as in get_speeches()", {
  local_search_ap()
  skip_if_no_fts()
  all_types <- c("speech", "question", "answer", "interjection")
  default <- search("government", include_presiding = TRUE)
  expect_identical(sum(default$is_interjection), 0L)
  with_inj <- search("government", type = all_types, include_presiding = TRUE)
  expect_gt(sum(with_inj$is_interjection), 0)
  only <- search("government", type = "interjection")
  expect_gt(nrow(only), 0)
  expect_true(all(only$is_interjection))

  # Each filter keeps exactly the matches that get_speeches() keeps under it.
  base <- search("government", type = all_types, include_presiding = TRUE)$action_id
  filters <- list(
    list(member = "ZD4"),
    list(party = "ALP"),
    list(parliament_id = in_range(38, 40)),
    list(chamber = "Senate"),
    list(chamber_venue = 1),
    list(from = 1996, to = "2002-10-15"),
    list(type = "answer"),
    list(include_presiding = FALSE),
    list(party = 4, chamber = "house", from = 2002)
  )
  for (f in filters) {
    args <- utils::modifyList(list(type = all_types, include_presiding = TRUE), f)
    got <- do.call(search, c(list("government"), args))$action_id
    speeches <- do.call(get_speeches, c(args, include_text = FALSE))$action_id
    expect_setequal(got, intersect(base, speeches))
  }
  expect_error(search("government", party = "LIB"), class = "ausparl_ambiguous_input")
  expect_error(search("government", member = "no-such-phid"), class = "ausparl_not_found")
})

# ---- R8 / R9 fts checks -------------------------------------------------------------------------

test_that("R8: a database without the index raises ausparl_db_error and builds nothing", {
  path <- local_sample_copy("DROP SCHEMA fts_main_actions CASCADE")
  db_connect(path = path)
  withr::defer(db_disconnect())

  statements <- character()
  record <- function(original) {
    force(original)
    function(conn, statement, ...) {
      statements <<- c(statements, as.character(statement))
      original(conn, statement, ...)
    }
  }
  testthat::local_mocked_bindings(
    dbGetQuery = record(DBI::dbGetQuery), dbExecute = record(DBI::dbExecute),
    dbSendQuery = record(DBI::dbSendQuery), .package = "DBI"
  )
  testthat::local_mocked_bindings(speech_query = function(...) stop("query built"))
  expect_error(search_speeches_by_terms("immigration"), class = "ausparl_db_error")
  expect_error(
    search_speeches_by_terms("the", exact = FALSE, include_text = FALSE),
    class = "ausparl_db_error"
  )
  # Only the catalog check ran: no index-building or other statement.
  expect_gt(length(statements), 0)
  expect_true(all(grepl("FROM duckdb_tables()", statements, fixed = TRUE)))
  building <- "fts_index|CREATE|PRAGMA|INSERT|DROP|INSTALL|LOAD"
  expect_false(any(grepl(building, statements, ignore.case = TRUE)))
  # Input errors still come first.
  expect_error(search_speeches_by_terms(""), class = "ausparl_input_error")
  expect_error(search_speeches_by_terms("x", chamber = "lords"), class = "ausparl_input_error")

  n <- DBI::dbGetQuery(db_con(), "
    SELECT count(*) AS n FROM duckdb_tables() WHERE schema_name = 'fts_main_actions'
  ")$n
  expect_identical(as.integer(n), 0L)
})

test_that("R9: an fts extension that cannot be loaded raises ausparl_db_error", {
  local_search_ap()
  testthat::local_mocked_bindings(
    fts_loaded = function(con) FALSE,
    load_fts_extension = function(con) stop("extension not installed"),
    speech_query = function(...) stop("query built")
  )
  expect_error(search_speeches_by_terms("immigration"), class = "ausparl_db_error")
  err <- rlang::catch_cnd(search_speeches_by_terms("immigration"), classes = "ausparl_error")
  expect_s3_class(err, "ausparl_db_error")

  # A load that runs but leaves the extension unloaded is the same failure.
  testthat::local_mocked_bindings(load_fts_extension = function(con) 0L)
  expect_error(search_speeches_by_terms("immigration"), class = "ausparl_db_error")
})

test_that("R9: an extension not yet loaded is loaded on demand", {
  local_search_ap()
  skip_if_no_fts()
  loads <- 0L
  checks <- 0L
  testthat::local_mocked_bindings(
    fts_loaded = function(con) {
      checks <<- checks + 1L
      checks > 1L
    },
    load_fts_extension = function(con) {
      loads <<- loads + 1L
      0L
    }
  )
  expect_gt(nrow(search("immigration")), 0)
  expect_identical(loads, 1L)
})

# ---- R10 input validation -----------------------------------------------------------------------

test_that("R10: invalid terms and arguments raise ausparl_input_error", {
  local_search_ap()
  testthat::local_mocked_bindings(speech_query = function(...) stop("query built"))
  bad_terms <- list(
    "", "   ", NA_character_, c("tax", NA), c("tax", ""), character(), 1, TRUE, NULL,
    list("tax"), factor("tax")
  )
  for (bad in bad_terms) {
    expect_error(search_speeches_by_terms(bad), class = "ausparl_input_error")
  }
  bad_args <- list(
    list(exact = NA), list(conjunctive = "yes"), list(include_text = 1),
    list(include_presiding = NA), list(from = "1996"), list(from = 1997, to = 1996),
    list(chamber = "lords"), list(type = "speeches"), list(member = 123),
    list(party = NA), list(parliament_id = NA), list(chamber_venue = list(1)),
    list(collect = NA), list(limit = 0)
  )
  for (args in bad_args) {
    expect_error(
      do.call(search_speeches_by_terms, c(list("tax"), args)),
      class = "ausparl_input_error"
    )
  }
})

test_that("R10: columns are validated", {
  local_search_ap()
  skip_if_no_fts()
  expect_error(search("tax", columns = "nope"), class = "ausparl_input_error")
  got <- search("immigration", columns = c("n_hits", "action_id"))
  expect_identical(names(got), c("n_hits", "action_id"))
})

# ---- R11 grain, size guard, order, aggregation --------------------------------------------------

test_that("T-4.18 R11: unique action_id, text threshold, score order and lazy aggregation", {
  local_search_ap()
  skip_if_no_fts()
  all_types <- c("speech", "question", "answer", "interjection")
  expect_unique_key(
    search(c("government", "minister"),
      conjunctive = FALSE, type = all_types,
      include_presiding = TRUE, collect = FALSE
    ),
    "action_id"
  )
  expect_unique_key(suppressMessages(search("the", collect = FALSE)), "action_id")

  # Collected rows come highest score first; limit keeps the top rows.
  got <- search("government")
  expect_false(is.unsorted(rev(got$score)))
  expect_identical(search("government", limit = 5)$action_id, got$action_id[1:5])
  expect_identical(search("government", columns = "action_id")$action_id, got$action_id)

  # include_text toggles content; the text ceiling applies only with content.
  with_text <- search_speeches_by_terms("government")
  expect_identical(names(with_text), c(speech_cols, "content", "score", "n_hits"))
  expect_identical(names(got), c(speech_cols, "score", "n_hits"))
  expect_identical(with_text$action_id, got$action_id)
  withr::with_options(list(ausparl.max_rows_text = 10, ausparl.max_rows = 1e6), {
    expect_error(search_speeches_by_terms("government"), class = "ausparl_input_error")
    expect_identical(nrow(search("government")), nrow(got))
  })

  # Aggregation recipes run inside DuckDB on the lazy result.
  hits <- search("government", collect = FALSE)
  expect_s3_class(hits, "tbl_lazy")
  total <- hits |>
    dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(.data$n_hits, na.rm = TRUE)) |>
    dplyr::collect()
  expect_equal(total$n_turns, nrow(got))
  expect_equal(total$n_occurrences, sum(got$n_hits))
  by_year <- hits |>
    dplyr::group_by(year = year(.data$date)) |>
    dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(.data$n_hits, na.rm = TRUE)) |>
    dplyr::collect()
  expect_equal(sum(by_year$n_turns), nrow(got))
  expect_equal(
    by_year$n_turns[by_year$year == 2002],
    sum(format(got$date, "%Y") == "2002")
  )
  who <- hits |>
    dplyr::group_by(.data$PHID) |>
    dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(.data$n_hits, na.rm = TRUE)) |>
    dplyr::left_join(db_tbl("members"), by = "PHID") |>
    dplyr::collect()
  expect_equal(sum(who$n_occurrences), sum(got$n_hits))
  expect_true("DisplayName" %in% names(who))
})

# ---- R12 empty results and SQL snapshot ---------------------------------------------------------

test_that("T-4.20 R12: an empty result is a typed zero-row tibble", {
  local_search_ap()
  skip_if_no_fts()
  typed <- col_classes(search_speeches_by_terms("immigration", limit = 1))
  empties <- list(
    search_speeches_by_terms("immigration", from = 1800, to = 1800),
    search_speeches_by_terms("zzzznotaword"),
    search_speeches_by_terms("immigration", exact = FALSE, chamber = "senate", from = 2024),
    suppressMessages(search_speeches_by_terms("1066"))
  )
  for (empty in empties) {
    expect_s3_class(empty, "tbl_df")
    expect_identical(nrow(empty), 0L)
    expect_identical(col_classes(empty), typed)
  }
  expect_identical(typed[["score"]], "numeric")
  expect_identical(typed[["n_hits"]], "integer")
  expect_identical(typed[["date"]], "Date")
})

test_that("T-4.4 R12: rendered SQL for one representative call", {
  local_search_ap()
  skip_if_no_fts()
  expect_snapshot(dbplyr::sql_render(search_speeches_by_terms(
    c("Foreign Affairs", "LGBTIQ+"),
    party = "ALP", from = 1996, to = 2002, chamber = "House",
    include_text = FALSE, collect = FALSE
  )))
})
