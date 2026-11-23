# Unit tests for the shared query plumbing (Q1-Q12). Sample DB only; no network.

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

# Asserts a lazy query returns the same rows as direct SQL, in any order.
expect_same_rows <- function(lazy, sql) {
  sort_rows <- function(d) {
    d <- as.data.frame(d)
    d <- d[do.call(order, unname(as.list(d))), , drop = FALSE]
    rownames(d) <- NULL
    d
  }
  got <- dplyr::collect(lazy)
  expect_equal(sort_rows(got), sort_rows(DBI::dbGetQuery(db_con(), sql)))
  invisible(got)
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

# ---- Q1 in_range() ------------------------------------------------------------------------------

test_that("T-4.2 Q1: in_range() accepts closed, open-ended, numeric and date bounds", {
  r <- in_range(1990, 1996)
  expect_s3_class(r, "ausparl_range")
  expect_identical(r$from, 1990)
  expect_identical(r$to, 1996)

  expect_null(in_range(from = 5)$to)
  expect_null(in_range(to = 5)$from)

  d <- in_range(as.Date("1901-05-09"), "1901-12-31")
  expect_identical(d$from, as.Date("1901-05-09"))
  expect_identical(d$to, as.Date("1901-12-31"))
  expect_identical(in_range(from = "2020-01-01")$from, as.Date("2020-01-01"))
  expect_identical(in_range(3, 3)$to, 3)
})

test_that("T-4.2 Q1: in_range() rejects no bounds, mixed kinds, reversed and bad bounds", {
  expect_error(in_range(), class = "ausparl_input_error")
  expect_error(in_range(1990, "2000-01-01"), class = "ausparl_input_error")
  expect_error(in_range(as.Date("2000-01-01"), 2001), class = "ausparl_input_error")
  expect_error(in_range(2000, 1990), class = "ausparl_input_error")
  expect_error(in_range("2000-01-02", "2000-01-01"), class = "ausparl_input_error")
  expect_error(in_range("01/02/2000"), class = "ausparl_input_error")
  expect_error(in_range("2000-02-30"), class = "ausparl_input_error")
  expect_error(in_range(c(1, 2)), class = "ausparl_input_error")
  expect_error(in_range(NA), class = "ausparl_input_error")
  expect_error(in_range(to = Inf), class = "ausparl_input_error")
  expect_error(in_range(TRUE), class = "ausparl_input_error")
})

# ---- Q2 matches_pattern() -----------------------------------------------------------------------

test_that("T-4.2 Q2: matches_pattern() matches members.DisplayName case-insensitively", {
  local_sample_ap()
  members <- db_tbl("members")
  lower <- filter_args(members, list(DisplayName = matches_pattern("%deakin%")))
  upper <- filter_args(members, list(DisplayName = matches_pattern("%DEAKIN%")))
  got <- expect_same_rows(lower,
    "SELECT * FROM members WHERE lower(DisplayName) LIKE '%deakin%'"
  )
  expect_gt(nrow(got), 0)
  expect_equal(dplyr::collect(upper), got)
})

test_that("T-4.2 Q2: matches_pattern() rejects a non-string or empty pattern", {
  expect_s3_class(matches_pattern("%x%"), "ausparl_like")
  expect_error(matches_pattern(""), class = "ausparl_input_error")
  expect_error(matches_pattern(1), class = "ausparl_input_error")
  expect_error(matches_pattern(c("a", "b")), class = "ausparl_input_error")
  expect_error(matches_pattern(NA_character_), class = "ausparl_input_error")
})

# ---- Q3 filter_args() ---------------------------------------------------------------------------

test_that("T-4.2 Q3: filter_args() NULL, scalar, vector and range equal direct SQL", {
  local_sample_ap()
  members <- db_tbl("members")

  expect_same_rows(filter_args(members, list(PHID = NULL)), "SELECT * FROM members")
  one <- expect_same_rows(
    filter_args(members, list(PHID = "009MD")),
    "SELECT * FROM members WHERE PHID = '009MD'"
  )
  expect_identical(nrow(one), 1L)
  several <- expect_same_rows(
    filter_args(members, list(StateAbbrev = c("Vic", "Tas"), Gender = "Female")),
    "SELECT * FROM members WHERE StateAbbrev IN ('Vic', 'Tas') AND Gender = 'Female'"
  )
  expect_gt(nrow(several), 0)
  dob <- expect_same_rows(
    filter_args(members, list(DateOfBirth = in_range("1940-01-01", "1960-12-31"))),
    "SELECT * FROM members WHERE DateOfBirth BETWEEN DATE '1940-01-01' AND DATE '1960-12-31'"
  )
  expect_gt(nrow(dob), 0)
  expect_same_rows(
    filter_args(members, list(DateOfBirth = in_range(from = as.Date("1970-01-01")))),
    "SELECT * FROM members WHERE DateOfBirth >= DATE '1970-01-01'"
  )
  parl <- expect_same_rows(
    filter_args(db_tbl("sittings"), list(parliament_id = in_range(to = 40))),
    "SELECT * FROM sittings WHERE parliament_id <= 40"
  )
  expect_gt(nrow(parl), 0)
  expect_same_rows(
    filter_args(db_tbl("sittings"), list(chamber = factor("house"))),
    "SELECT * FROM sittings WHERE chamber = 'house'"
  )
})

test_that("T-4.2 Q3: filter_args() rejects NA, empty, non-atomic values and unknown columns", {
  local_sample_ap()
  members <- db_tbl("members")
  expect_error(filter_args(members, list(PHID = NA)), class = "ausparl_input_error")
  expect_error(filter_args(members, list(PHID = c("009MD", NA))), class = "ausparl_input_error")
  expect_error(filter_args(members, list(PHID = character())), class = "ausparl_input_error")
  expect_error(filter_args(members, list(PHID = list("009MD"))), class = "ausparl_input_error")
  expect_error(filter_args(members, list(nope = "x")), class = "ausparl_input_error")
})

# ---- Q4 SQL safety ------------------------------------------------------------------------------

test_that("T-4.2 Q4: hostile values are escaped literals and match nothing", {
  local_sample_ap()
  members <- db_tbl("members")
  hostile <- c("O'Brien", "x'; DROP TABLE members; --", "\"; DROP TABLE members")
  for (value in hostile) {
    q <- filter_args(members, list(DisplayName = value))
    expect_identical(nrow(dplyr::collect(q)), 0L)
    expect_identical(nrow(dplyr::collect(filter_args(members, list(PHID = c("a", value))))), 0L)
    expect_identical(
      nrow(dplyr::collect(filter_args(members, list(DisplayName = matches_pattern(value))))), 0L
    )
  }
  sql <- dbplyr::sql_render(filter_args(members, list(DisplayName = "x'; DROP TABLE members; --")))
  expect_match(sql, "'x''; DROP TABLE members; --'", fixed = TRUE)
  expect_identical(nrow(dplyr::collect(members)), 303L)
})

# ---- Q5 filter_active_during() ------------------------------------------------------------------

test_that("T-4.2 Q5: filter_active_during() on parl_service equals direct SQL", {
  local_sample_ap()
  ps <- db_tbl("parl_service")
  overlap_sql <- function(from, to) {
    sprintf(
      "SELECT * FROM parl_service WHERE DateStart <= DATE '%s'
       AND (DateEnd IS NULL OR DateEnd >= DATE '%s')", to, from
    )
  }

  day <- expect_same_rows(
    filter_active_during(ps, "1990-06-01", "DateStart", "DateEnd"),
    overlap_sql("1990-06-01", "1990-06-01")
  )
  expect_gt(nrow(day), 0)
  expect_same_rows(
    filter_active_during(ps, as.Date("1990-06-01"), "DateStart", "DateEnd"),
    overlap_sql("1990-06-01", "1990-06-01")
  )
  span <- expect_same_rows(
    filter_active_during(ps, in_range("1990-01-01", "1995-12-31"), "DateStart", "DateEnd"),
    overlap_sql("1990-01-01", "1995-12-31")
  )
  expect_gt(nrow(span), nrow(day))
  expect_same_rows(
    filter_active_during(ps, in_range(1990, 1995), "DateStart", "DateEnd"),
    overlap_sql("1990-01-01", "1995-12-31")
  )
  expect_same_rows(
    filter_active_during(ps, 1990, "DateStart", "DateEnd"),
    overlap_sql("1990-01-01", "1990-12-31")
  )
  expect_same_rows(
    filter_active_during(ps, in_range(to = "1910-01-01"), "DateStart", "DateEnd"),
    "SELECT * FROM parl_service WHERE DateStart <= DATE '1910-01-01'"
  )

  # Ongoing service (NULL end) is active today.
  ongoing <- expect_same_rows(
    filter_active_during(ps, in_range(from = "2025-06-01"), "DateStart", "DateEnd"),
    "SELECT * FROM parl_service WHERE DateEnd IS NULL OR DateEnd >= DATE '2025-06-01'"
  )
  expect_true(any(is.na(ongoing$DateEnd)))
  expect_identical(filter_active_during(ps, NULL, "DateStart", "DateEnd"), ps)
})

test_that("T-4.2 Q5: filter_active_during() rejects bad values", {
  local_sample_ap()
  ps <- db_tbl("parl_service")
  expect_error(filter_active_during(ps, "June 1990", "DateStart", "DateEnd"),
    class = "ausparl_input_error"
  )
  expect_error(filter_active_during(ps, 1990, "DateStart", "nope"),
    class = "ausparl_input_error"
  )
})

# ---- Q6 date_bounds() ---------------------------------------------------------------------------

test_that("T-4.2 Q6: date_bounds() expands years and accepts dates", {
  expect_identical(
    date_bounds(1990, 1995),
    list(from = as.Date("1990-01-01"), to = as.Date("1995-12-31"))
  )
  expect_identical(
    date_bounds("1990-07-01", as.Date("1990-07-02")),
    list(from = as.Date("1990-07-01"), to = as.Date("1990-07-02"))
  )
  expect_identical(date_bounds(1990L, NULL), list(from = as.Date("1990-01-01"), to = NULL))
  expect_identical(date_bounds(), list(from = NULL, to = NULL))
  expect_identical(date_bounds(2000, 2000)$to, as.Date("2000-12-31"))
})

test_that("T-4.2 Q6: date_bounds() rejects reversed and malformed values", {
  expect_error(date_bounds(1995, 1990), class = "ausparl_input_error")
  expect_error(date_bounds("1990-07-02", "1990-07-01"), class = "ausparl_input_error")
  expect_error(date_bounds(1990.5), class = "ausparl_input_error")
  expect_error(date_bounds(to = "1990"), class = "ausparl_input_error")
  expect_error(date_bounds(c(1990, 1991)), class = "ausparl_input_error")
})

# ---- Q7 normalise_chamber() ---------------------------------------------------------------------

test_that("T-4.2 Q7: normalise_chamber() accepts any case and returns lowercase", {
  expect_identical(normalise_chamber("House"), "house")
  expect_identical(normalise_chamber(c("SENATE", "house")), c("senate", "house"))
  expect_null(normalise_chamber(NULL))
  expect_error(normalise_chamber("reps"), class = "ausparl_input_error")
  expect_error(normalise_chamber(c("house", NA)), class = "ausparl_input_error")
  expect_error(normalise_chamber(1), class = "ausparl_input_error")
})

# ---- Q8 select_columns() ------------------------------------------------------------------------

test_that("T-4.2 Q8: select_columns() keeps valid columns and rejects unknown ones", {
  local_sample_ap()
  members <- db_tbl("members")
  expect_identical(colnames(select_columns(members, c("PHID", "DisplayName"))),
    c("PHID", "DisplayName")
  )
  expect_identical(select_columns(members, NULL), members)
  expect_error(select_columns(members, c("PHID", "nope")), class = "ausparl_input_error")
  expect_error(select_columns(members, character()), class = "ausparl_input_error")
  expect_error(select_columns(members, 1), class = "ausparl_input_error")
})

# ---- Q9 collect_result() size guard -------------------------------------------------------------

test_that("T-4.18 Q9: the text ceiling applies when content is in the result", {
  local_sample_ap()
  withr::local_options(ausparl.max_rows = 1e6, ausparl.max_rows_text = 3)
  day <- filter_args(db_tbl("actions"), list(sitting_id = dplyr::pull(
    dplyr::collect(utils::head(db_tbl("sittings"), 1)), "sitting_id"
  )))

  err <- expect_error(collect_result(day), class = "ausparl_input_error")
  expect_s3_class(err, "ausparl_error")
  no_text <- collect_result(select_columns(day, c("action_id", "PHID")))
  expect_gt(nrow(no_text), 3)
})

test_that("T-4.18 Q9: the plain ceiling applies without content", {
  local_sample_ap()
  withr::local_options(ausparl.max_rows = 5, ausparl.max_rows_text = 1e6)
  expect_error(collect_result(db_tbl("sittings")), class = "ausparl_input_error")
  expect_error(collect_result(db_tbl("sittings"), limit = 7), class = "ausparl_input_error")

  withr::local_options(ausparl.max_rows = 8)
  expect_identical(nrow(collect_result(db_tbl("sittings"))), 8L)
})

test_that("T-4.18 Q9: the guard is skipped for collect = FALSE, a small limit, and Inf", {
  local_sample_ap()
  local_mocked_bindings(probe_rows = function(tbl, n) stop("probe must not run"))
  withr::local_options(ausparl.max_rows = 5)

  lazy <- collect_result(db_tbl("sittings"), collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  expect_identical(nrow(collect_result(db_tbl("sittings"), limit = 5)), 5L)
  expect_identical(nrow(dplyr::collect(collect_result(db_tbl("sittings"), FALSE, 2))), 2L)

  withr::local_options(ausparl.max_rows = Inf)
  expect_identical(nrow(collect_result(db_tbl("sittings"))), 8L)
})

test_that("T-4.18 Q9: the probe counts inside DuckDB with a LIMIT", {
  local_sample_ap()
  sql <- dbplyr::sql_render(probe_query(db_tbl("actions"), 11L))
  expect_match(sql, "COUNT(*)", fixed = TRUE)
  expect_match(sql, "LIMIT 11", fixed = TRUE)
  expect_equal(probe_rows(db_tbl("actions"), 11L), 11)

  seen <- NULL
  local_mocked_bindings(probe_rows = function(tbl, n) {
    seen <<- n
    0
  })
  withr::local_options(ausparl.max_rows = 5)
  collect_result(db_tbl("sittings"))
  expect_identical(seen, 6L)
})

test_that("T-4.18 Q9: collect, limit and the options are validated", {
  local_sample_ap()
  s <- db_tbl("sittings")
  expect_error(collect_result(s, collect = NA), class = "ausparl_input_error")
  expect_error(collect_result(s, limit = 0), class = "ausparl_input_error")
  expect_error(collect_result(s, limit = 1.5), class = "ausparl_input_error")
  expect_error(collect_result(s, limit = "10"), class = "ausparl_input_error")
  expect_error(collect_result(s, limit = Inf), class = "ausparl_input_error")
  withr::local_options(ausparl.max_rows = "lots")
  expect_error(collect_result(s), class = "ausparl_input_error")
  withr::local_options(ausparl.max_rows = 0)
  expect_error(collect_result(s), class = "ausparl_input_error")
})

test_that("T-4.18 Q9: .onLoad sets defaults only when the options are unset", {
  withr::local_options(ausparl.max_rows = 7, ausparl.max_rows_text = NULL)
  .onLoad("", "ausparl")
  expect_identical(getOption("ausparl.max_rows"), 7)
  expect_identical(getOption("ausparl.max_rows_text"), max_rows_text_default)
  .onLoad("", "ausparl")
  expect_identical(getOption("ausparl.max_rows"), 7)

  withr::local_options(ausparl.max_rows = NULL)
  .onLoad("", "ausparl")
  expect_identical(getOption("ausparl.max_rows"), max_rows_default)
})

test_that("T-4.18 Q9: DuckDB failures surface as ausparl_db_error", {
  local_sample_ap()
  bad <- dplyr::mutate(db_tbl("sittings"), x = dbplyr::sql("no_such_function(1)"))
  withr::local_options(ausparl.max_rows = Inf)
  expect_error(collect_result(bad), class = "ausparl_db_error")
  withr::local_options(ausparl.max_rows = 5)
  expect_error(collect_result(bad), class = "ausparl_db_error")
})

# ---- Q10 empty results --------------------------------------------------------------------------

test_that("T-4.20 Q10: an empty filtered result is a typed zero-row tibble", {
  local_sample_ap()
  for (table in c("members", "parl_service", "actions")) {
    src <- db_tbl(table)
    empty <- collect_result(filter_args(src, list(PHID = "no-such-phid")))
    expect_s3_class(empty, "tbl_df")
    expect_identical(nrow(empty), 0L)
    expect_identical(col_classes(empty), col_classes(collect_result(src, limit = 1)))
  }
})

# ---- Q11 / Q12 push-down and snapshots ----------------------------------------------------------

test_that("T-4.4 Q11: filters push down into the SQL WHERE clause", {
  local_sample_ap()
  q <- filter_args(db_tbl("members"), list(StateAbbrev = c("Vic", "Tas")))
  expect_match(dbplyr::sql_render(q), "WHERE", fixed = TRUE)
  q <- filter_active_during(db_tbl("parl_service"), 1990, "DateStart", "DateEnd")
  expect_match(dbplyr::sql_render(q), "WHERE", fixed = TRUE)
})

test_that("T-4.4 Q12: rendered SQL for representative filter calls", {
  local_sample_ap()
  expect_snapshot(dbplyr::sql_render(filter_args(db_tbl("members"), list(
    PHID = NULL,
    StateAbbrev = c("Vic", "Tas"),
    Gender = "Female",
    DateOfBirth = in_range("1940-01-01", "1960-12-31"),
    DisplayName = matches_pattern("%o'brien%")
  ))))
  expect_snapshot(dbplyr::sql_render(filter_active_during(
    db_tbl("parl_service"), in_range(1990, 1995), "DateStart", "DateEnd"
  )))
})

# ---- helper self-test ---------------------------------------------------------------------------

test_that("T-4.20 helper: expect_unique_key() detects duplicate keys", {
  local_sample_ap()
  expect_unique_key(db_tbl("sittings"), "sitting_id")
  expect_unique_key(db_tbl("actions"), c("action_id"))
  expect_failure(expect_unique_key(db_tbl("actions"), "sitting_id"))
  expect_failure(expect_unique_key(db_tbl("parl_service"), "PHID"))
})
