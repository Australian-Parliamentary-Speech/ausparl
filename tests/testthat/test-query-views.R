# Tests for the analysis-view queries (V1-V9, V12-V19): get_interjections(), get_sitting_timeline()
# and get_speech_turns(). Sample DB only; no network.

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

# Asserts a result has the same rows as direct SQL, in any order.
expect_same_rows <- function(got, sql) {
  sort_rows <- function(d) {
    d <- as.data.frame(d)
    d <- d[do.call(order, unname(as.list(d))), , drop = FALSE]
    rownames(d) <- NULL
    d
  }
  expect_equal(sort_rows(got), sort_rows(DBI::dbGetQuery(db_con(), sql)))
  invisible(got)
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

interjection_cols <- c(
  "interjection_action_id", "target_action_id", "sitting_id", "date", "chamber",
  "chamber_venue", "interjector_PHID", "interjector_name", "target_PHID", "target_name",
  "interjection_type"
)
timeline_cols <- c(
  "sitting_id", "date", "chamber", "seq", "action_id", "debate_title", "subdebate_title",
  "action_type", "PHID", "speaker_name"
)

# The interjection query written by hand, with a WHERE clause appended.
interjection_sql <- function(where = "TRUE") {
  paste("
    SELECT v.interjection_action_id, v.target_action_id, a.sitting_id, s.date, s.chamber,
           a.chamber_venue, a.PHID AS interjector_PHID, mi.DisplayName AS interjector_name,
           t.PHID AS target_PHID, mt.DisplayName AS target_name,
           a.action_type AS interjection_type
    FROM v_interjection_target v
    JOIN actions a ON a.action_id = v.interjection_action_id
    LEFT JOIN actions t ON t.action_id = v.target_action_id
    JOIN sittings s ON s.sitting_id = a.sitting_id
    LEFT JOIN members mi ON mi.PHID = a.PHID
    LEFT JOIN members mt ON mt.PHID = t.PHID
    WHERE", where)
}

timeline_sql <- function(where = "TRUE", content = FALSE) {
  text_col <- if (content) ", a.content" else ""
  paste0("
    SELECT t.sitting_id, s.date, s.chamber, t.seq, t.action_id, t.debate_title,
           t.subdebate_title, t.action_type, t.PHID, t.speaker_name", text_col, "
    FROM v_sitting_timeline t
    JOIN sittings s ON s.sitting_id = t.sitting_id
    LEFT JOIN actions a ON a.action_id = t.action_id
    WHERE ", where, "
    ORDER BY t.sitting_id, t.seq")
}

# ---- V1 unfiltered ------------------------------------------------------------------------------

test_that("T-4.1 V1: unfiltered interjections equal direct SQL; tibble or lazy and pipeable", {
  local_sample_ap()
  got <- get_interjections()
  expect_s3_class(got, "tbl_df")
  expect_identical(names(got), interjection_cols)
  expect_same_rows(got, interjection_sql())

  lazy <- get_interjections(collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  counted <- lazy |>
    dplyr::count(.data$interjection_type) |>
    dplyr::collect()
  expect_identical(sum(counted$n), as.numeric(nrow(got)))
})

test_that("T-4.1 V1: unfiltered timeline equals direct SQL; tibble or lazy and pipeable", {
  local_sample_ap()
  got <- get_sitting_timeline()
  expect_s3_class(got, "tbl_df")
  expect_identical(names(got), c(timeline_cols, "content"))
  expect_equal(as.data.frame(got), DBI::dbGetQuery(db_con(), timeline_sql(content = TRUE)))

  lazy <- get_sitting_timeline(include_text = FALSE, collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  first <- lazy |>
    dplyr::filter(.data$seq == 1) |>
    dplyr::collect()
  expect_identical(nrow(first), 8L)
})

# ---- V2 interjection filters --------------------------------------------------------------------

test_that("T-4.2 V2: interjection filters equal direct SQL", {
  local_sample_ap()
  expect_same_rows(
    get_interjections(from = 2002, to = 2002),
    interjection_sql("s.date BETWEEN DATE '2002-01-01' AND DATE '2002-12-31'")
  )
  expect_same_rows(
    get_interjections(from = "2000-03-07"),
    interjection_sql("s.date >= DATE '2000-03-07'")
  )
  expect_same_rows(
    get_interjections(to = as.Date("1918-09-19")),
    interjection_sql("s.date <= DATE '1918-09-19'")
  )
  expect_same_rows(
    get_interjections(chamber = "SENATE"),
    interjection_sql("s.chamber = 'senate'")
  )
  expect_same_rows(get_interjections(chamber_venue = 1), interjection_sql("a.chamber_venue = 1"))

  phids <- DBI::dbGetQuery(db_con(), interjection_sql(
    "a.PHID IS NOT NULL AND t.PHID IS NOT NULL ORDER BY v.interjection_action_id LIMIT 2"
  ))
  one <- phids$interjector_PHID[1]
  got <- get_interjections(interjector = one)
  expect_gt(nrow(got), 0)
  expect_same_rows(got, interjection_sql(sprintf("a.PHID = '%s'", one)))

  targets <- unique(phids$target_PHID)
  expect_same_rows(
    get_interjections(target = targets),
    interjection_sql(sprintf("t.PHID IN (%s)", paste0("'", targets, "'", collapse = ", ")))
  )
  expect_same_rows(
    get_interjections(interjector = one, target = phids$target_PHID[1], from = 1900),
    interjection_sql(sprintf(
      "a.PHID = '%s' AND t.PHID = '%s' AND s.date >= DATE '1900-01-01'",
      one, phids$target_PHID[1]
    ))
  )
})

# ---- V3 NULL interjector / target ---------------------------------------------------------------

test_that("V3: NULL-interjector and NULL-target rows are kept", {
  local_sample_ap()
  got <- get_interjections()
  n_view <- DBI::dbGetQuery(db_con(), "SELECT count(*) AS n FROM v_interjection_target")$n
  expect_identical(nrow(got), as.integer(n_view))
  expect_gt(sum(is.na(got$interjector_PHID)), 0)
  expect_gt(sum(is.na(got$target_action_id)), 0)
  expect_true(all(is.na(got$target_PHID[is.na(got$target_action_id)])))
  expect_true(all(is.na(got$interjector_name[is.na(got$interjector_PHID)])))
  expect_setequal(unique(got$interjection_type), c("speech", "unresolved_interjection"))
})

# ---- V4 PHID validation -------------------------------------------------------------------------

test_that("V4: unknown PHIDs raise ausparl_not_found; wrong types raise ausparl_input_error", {
  local_sample_ap()
  expect_error(get_interjections(interjector = "no-such-phid"), class = "ausparl_not_found")
  expect_error(get_interjections(target = "no-such-phid"), class = "ausparl_not_found")
  known <- DBI::dbGetQuery(db_con(), "SELECT PHID FROM members LIMIT 1")$PHID
  expect_error(
    get_interjections(interjector = known, target = c(known, "no-such-phid")),
    class = "ausparl_not_found"
  )

  bad <- list(123, NA_character_, character(), "", matches_pattern("%x%"), list("a"), TRUE)
  for (value in bad) {
    expect_error(get_interjections(interjector = value), class = "ausparl_input_error")
    expect_error(get_interjections(target = value), class = "ausparl_input_error")
  }
})

test_that("V4: other interjection arguments are validated at entry", {
  local_sample_ap()
  expect_error(get_interjections(from = "1996"), class = "ausparl_input_error")
  expect_error(get_interjections(from = 1997, to = 1996), class = "ausparl_input_error")
  expect_error(get_interjections(chamber = "lords"), class = "ausparl_input_error")
  expect_error(get_interjections(chamber_venue = NA), class = "ausparl_input_error")
  expect_error(get_interjections(columns = "content"), class = "ausparl_input_error")
  expect_error(get_interjections(collect = NA), class = "ausparl_input_error")
  expect_error(get_interjections(limit = 0), class = "ausparl_input_error")
})

# ---- V5 timeline filters and order --------------------------------------------------------------

test_that("V5: timeline filters equal direct SQL; collected rows ordered by sitting_id, seq", {
  local_sample_ap()
  plain <- function(where) DBI::dbGetQuery(db_con(), timeline_sql(where))
  check <- function(got, where) {
    expect_equal(as.data.frame(got), plain(where))
  }
  check(
    get_sitting_timeline(sitting_id = "house_1990-09-17", include_text = FALSE),
    "t.sitting_id = 'house_1990-09-17'"
  )
  check(
    get_sitting_timeline(date = as.Date("2019-11-26"), include_text = FALSE),
    "s.date = DATE '2019-11-26'"
  )
  check(
    get_sitting_timeline(date = c("1990-09-17", "1983-05-10"), include_text = FALSE),
    "s.date IN (DATE '1990-09-17', DATE '1983-05-10')"
  )
  check(
    get_sitting_timeline(date = in_range(1983, 1990), include_text = FALSE),
    "s.date BETWEEN DATE '1983-01-01' AND DATE '1990-12-31'"
  )
  check(
    get_sitting_timeline(date = in_range(from = "2002-01-01"), include_text = FALSE),
    "s.date >= DATE '2002-01-01'"
  )
  check(
    get_sitting_timeline(chamber = "Senate", include_text = FALSE),
    "s.chamber = 'senate'"
  )

  got <- get_sitting_timeline(include_text = FALSE)
  expect_identical(got$sitting_id, sort(got$sitting_id))
  for (id in unique(got$sitting_id)) {
    expect_false(is.unsorted(got$seq[got$sitting_id == id], strictly = TRUE))
  }
  expect_identical(
    get_sitting_timeline(include_text = FALSE, columns = "action_id", limit = 5)$action_id,
    got$action_id[1:5]
  )
  expect_identical(
    get_sitting_timeline(sitting_id = "house_1990-09-17", columns = "seq", limit = 3)$seq,
    got$seq[got$sitting_id == "house_1990-09-17"][1:3]
  )
})

test_that("V5: the lazy timeline is unordered and can be aggregated in DuckDB", {
  local_sample_ap()
  lazy <- get_sitting_timeline(collect = FALSE)
  expect_false(grepl("ORDER BY", dbplyr::sql_render(lazy), fixed = TRUE))
  counted <- lazy |>
    dplyr::count(.data$action_type) |>
    dplyr::collect()
  expect_same_rows(
    counted,
    "SELECT action_type, count(*) AS n FROM v_sitting_timeline GROUP BY action_type"
  )

  arranged <- get_sitting_timeline(include_text = FALSE, collect = FALSE) |>
    dplyr::arrange(.data$sitting_id, .data$seq) |>
    dplyr::collect()
  expect_identical(arranged, get_sitting_timeline(include_text = FALSE))
})

test_that("V5: timeline arguments are validated at entry", {
  local_sample_ap()
  expect_error(get_sitting_timeline(date = "02/05/1996"), class = "ausparl_input_error")
  expect_error(get_sitting_timeline(date = 1996), class = "ausparl_input_error")
  expect_error(get_sitting_timeline(date = NA), class = "ausparl_input_error")
  expect_error(
    get_sitting_timeline(date = matches_pattern("%1996%")),
    class = "ausparl_input_error"
  )
  expect_error(get_sitting_timeline(sitting_id = NA), class = "ausparl_input_error")
  expect_error(get_sitting_timeline(chamber = 1), class = "ausparl_input_error")
  expect_error(get_sitting_timeline(include_text = "yes"), class = "ausparl_input_error")
  expect_error(get_sitting_timeline(columns = "nope"), class = "ausparl_input_error")
})

# ---- V6 include_text and the text threshold -----------------------------------------------------

test_that("T-4.18 V6: include_text adds or omits content; the text threshold applies", {
  local_sample_ap()
  with_text <- get_sitting_timeline(sitting_id = "house_1990-09-17")
  without <- get_sitting_timeline(sitting_id = "house_1990-09-17", include_text = FALSE)
  expect_identical(names(with_text), c(timeline_cols, "content"))
  expect_identical(names(without), timeline_cols)
  expect_identical(with_text[timeline_cols], without)
  expect_gt(sum(!is.na(with_text$content)), 0)

  withr::local_options(ausparl.max_rows_text = 10, ausparl.max_rows = 1e6)
  expect_error(get_sitting_timeline(), class = "ausparl_input_error")
  expect_identical(nrow(get_sitting_timeline(include_text = FALSE)), 1488L)
  expect_identical(nrow(get_sitting_timeline(columns = "action_id")), 1488L)
  expect_identical(nrow(get_sitting_timeline(limit = 10)), 10L)
  # Interjections carry no content, so only the plain threshold applies.
  expect_identical(nrow(get_interjections()), 146L)
})

# ---- V7 grain -----------------------------------------------------------------------------------

test_that("V7: the joins do not fan out", {
  local_sample_ap()
  expect_unique_key(get_interjections(collect = FALSE), "interjection_action_id")
  expect_unique_key(get_sitting_timeline(collect = FALSE), "action_id")
  expect_unique_key(get_sitting_timeline(include_text = FALSE, collect = FALSE), "action_id")
  got <- get_sitting_timeline()
  expect_identical(anyDuplicated(got$action_id), 0L)
  n_view <- DBI::dbGetQuery(db_con(), "SELECT count(*) AS n FROM v_sitting_timeline")$n
  expect_identical(nrow(got), as.integer(n_view))
})

# ---- V8 empty results ---------------------------------------------------------------------------

test_that("T-4.20 V8: an empty result is a typed zero-row tibble", {
  local_sample_ap()
  empties <- list(
    list(get_interjections(from = 1800, to = 1800), get_interjections(limit = 1)),
    list(get_sitting_timeline(sitting_id = "none"), get_sitting_timeline(limit = 1)),
    list(
      get_sitting_timeline(date = "1800-01-01", include_text = FALSE),
      get_sitting_timeline(include_text = FALSE, limit = 1)
    )
  )
  for (pair in empties) {
    expect_s3_class(pair[[1]], "tbl_df")
    expect_identical(nrow(pair[[1]]), 0L)
    expect_identical(col_classes(pair[[1]]), col_classes(pair[[2]]))
  }
  expect_identical(col_classes(empties[[1]][[1]])[["date"]], "Date")
})

# ---- V9 SQL snapshots ---------------------------------------------------------------------------

test_that("T-4.4 V9: rendered SQL for one representative call per function", {
  local_sample_ap()
  render <- function(lazy) dbplyr::sql_render(lazy)
  expect_snapshot(render(get_interjections(
    from = 1996, to = 1996, chamber = "House", collect = FALSE
  )))
  expect_snapshot(render(get_sitting_timeline(
    sitting_id = "house_1996-05-02", collect = FALSE
  )))
})

# ---- get_speech_turns() (V12-V18) ---------------------------------------------------------------

turn_cols <- c(
  "sitting_id", "date", "chamber", "parliament_id", "turn_no", "first_action_id", "n_actions",
  "PHID", "name_raw", "resolution", "party_id_at_time", "party_at_time", "has_quote", "is_quote"
)

# The turn query written by hand, independently of the package: the quote flags by counting, the
# party name from v_party_at_time and its id by matching the name to `parties`, which must
# agree with the id the package reads from the view.
turn_sql <- function(where = "TRUE", content = FALSE) {
  text_col <- if (content) ", t.content" else ""
  paste0("
    WITH flags AS (
      SELECT sitting_id, turn_no,
             count(*) FILTER (WHERE has_quote) > 0 AS has_quote,
             count(*) FILTER (WHERE action_type = 'quote') = count(*) AS is_quote
      FROM actions
      WHERE turn_no IS NOT NULL AND turn_no <> 0 AND is_non_speech IS NOT TRUE
      GROUP BY sitting_id, turn_no
    )
    SELECT t.sitting_id, s.date, s.chamber, s.parliament_id, t.turn_no, t.first_action_id,
           t.n_actions, t.PHID, a.name_raw, t.resolution, p.party_id AS party_id_at_time,
           pt.party_at_time, f.has_quote, f.is_quote", text_col, "
    FROM v_speech_turns t
    JOIN sittings s ON s.sitting_id = t.sitting_id
    LEFT JOIN actions a ON a.action_id = t.first_action_id
    LEFT JOIN flags f ON f.sitting_id = t.sitting_id AND f.turn_no = t.turn_no
    LEFT JOIN v_party_at_time pt ON pt.action_id = t.first_action_id
    LEFT JOIN parties p ON p.Name = pt.party_at_time
    WHERE ", where, "
    ORDER BY t.sitting_id, t.turn_no")
}

test_that("T-4.1 V12: unfiltered speech turns equal direct SQL; tibble or lazy and pipeable", {
  local_sample_ap()
  got <- get_speech_turns()
  expect_s3_class(got, "tbl_df")
  expect_identical(names(got), c(turn_cols, "content"))
  expect_identical(nrow(got), 967L)
  expect_equal(as.data.frame(got), DBI::dbGetQuery(db_con(), turn_sql(content = TRUE)))

  lazy <- get_speech_turns(collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  expect_false(grepl("ORDER BY", dbplyr::sql_render(lazy), fixed = TRUE))
  counted <- lazy |>
    dplyr::count(.data$resolution) |>
    dplyr::collect()
  expect_same_rows(
    counted,
    "SELECT resolution, count(*) AS n FROM v_speech_turns GROUP BY resolution"
  )
  arranged <- get_speech_turns(include_text = FALSE, collect = FALSE) |>
    dplyr::arrange(.data$sitting_id, .data$turn_no) |>
    dplyr::collect()
  expect_identical(arranged, get_speech_turns(include_text = FALSE))

  # Presiding-officer, unresolved and NULL-resolution turns are all kept.
  expect_true(all(c("sentinel", "collective", "unknown") %in% got$resolution))
  expect_gt(sum(is.na(got$resolution)), 0)
  expect_gt(sum(got$n_actions > 1), 0)
})

test_that("T-4.2 V13: speech-turn filters equal direct SQL", {
  local_sample_ap()
  check <- function(got, where) {
    expect_gt(nrow(got), 0)
    expect_equal(as.data.frame(got), DBI::dbGetQuery(db_con(), turn_sql(where)))
  }
  check(get_speech_turns(member = "H6X", include_text = FALSE), "t.PHID = 'H6X'")
  check(
    get_speech_turns(member = c("H6X", "KIN"), include_text = FALSE),
    "t.PHID IN ('H6X', 'KIN')"
  )
  check(get_speech_turns(party = "ALP", include_text = FALSE), "p.party_id = 1")
  check(get_speech_turns(party = 1, include_text = FALSE), "p.party_id = 1")
  check(get_speech_turns(parliament_id = 40, include_text = FALSE), "s.parliament_id = 40")
  check(
    get_speech_turns(parliament_id = in_range(33, 40), include_text = FALSE),
    "s.parliament_id BETWEEN 33 AND 40"
  )
  check(get_speech_turns(chamber = "SENATE", include_text = FALSE), "s.chamber = 'senate'")
  check(
    get_speech_turns(from = 2002, to = 2002, include_text = FALSE),
    "s.date BETWEEN DATE '2002-01-01' AND DATE '2002-12-31'"
  )
  check(get_speech_turns(from = "1990-09-17", include_text = FALSE), "s.date >= DATE '1990-09-17'")
  check(
    get_speech_turns(to = as.Date("1990-09-17"), include_text = FALSE),
    "s.date <= DATE '1990-09-17'"
  )
  check(
    get_speech_turns(sitting_id = "house_1990-09-17", include_text = FALSE),
    "t.sitting_id = 'house_1990-09-17'"
  )
  check(
    get_speech_turns(sitting_id = matches_pattern("SENATE%"), include_text = FALSE),
    "t.sitting_id ILIKE 'senate%'"
  )
  check(
    get_speech_turns(resolution = "sentinel", include_text = FALSE),
    "t.resolution = 'sentinel'"
  )
  check(
    get_speech_turns(resolution = c("collective", "unknown"), include_text = FALSE),
    "t.resolution IN ('collective', 'unknown')"
  )
  check(
    get_speech_turns(party = "ALP", chamber = "house", from = 2002, include_text = FALSE),
    "p.party_id = 1 AND s.chamber = 'house' AND s.date >= DATE '2002-01-01'"
  )

  # Collected rows are ordered by sitting_id, turn_no, and `limit` keeps the first of them.
  all_turns <- get_speech_turns(include_text = FALSE)
  expect_identical(
    get_speech_turns(columns = "first_action_id", limit = 5)$first_action_id,
    all_turns$first_action_id[1:5]
  )
  expect_identical(
    get_speech_turns(sitting_id = "house_1990-09-17", columns = "turn_no", limit = 3)$turn_no,
    all_turns$turn_no[all_turns$sitting_id == "house_1990-09-17"][1:3]
  )
})

test_that("V14: has_quote and is_quote equal values computed by hand from actions", {
  local_sample_ap()
  acts <- DBI::dbGetQuery(db_con(), "
    SELECT sitting_id, turn_no, has_quote, action_type, is_non_speech FROM actions
  ")
  in_turn <- !is.na(acts$turn_no) & acts$turn_no != 0 & !(acts$is_non_speech %in% TRUE)
  acts <- acts[in_turn, ]
  key <- paste(acts$sitting_id, acts$turn_no)
  per_turn <- function(x, f) c(tapply(x, key, f))
  any_flag <- per_turn(acts$has_quote %in% TRUE, any)
  all_quote <- per_turn(acts$action_type %in% "quote", all)
  any_quote <- per_turn(acts$action_type %in% "quote", any)

  got <- get_speech_turns(include_text = FALSE)
  got_key <- paste(got$sitting_id, got$turn_no)
  expect_setequal(got_key, names(any_flag))
  expect_identical(got$has_quote, unname(any_flag[got_key]))
  expect_identical(got$is_quote, unname(all_quote[got_key]))

  # The sample must keep quote-only and mixed turns, so a rebuild that loses them fails here.
  mixed <- unname(any_quote[got_key]) & !got$is_quote
  expect_identical(sum(got$is_quote), 12L)
  expect_identical(sum(mixed), 7L)
  expect_true(all(got$has_quote[got$is_quote]))
  expect_identical(nrow(dplyr::filter(got, !.data$is_quote)), 955L)
})

test_that("T-4.18 V15: include_text adds or omits content; the text threshold applies", {
  local_sample_ap()
  with_text <- get_speech_turns(sitting_id = "house_1990-09-17")
  without <- get_speech_turns(sitting_id = "house_1990-09-17", include_text = FALSE)
  expect_identical(names(with_text), c(turn_cols, "content"))
  expect_identical(names(without), turn_cols)
  expect_identical(with_text[turn_cols], without)
  expect_gt(sum(!is.na(with_text$content)), 0)

  withr::local_options(ausparl.max_rows_text = 10, ausparl.max_rows = 1e6)
  expect_error(get_speech_turns(), class = "ausparl_input_error")
  expect_identical(nrow(get_speech_turns(include_text = FALSE)), 967L)
  expect_identical(nrow(get_speech_turns(columns = "turn_no")), 967L)
  expect_identical(nrow(get_speech_turns(limit = 10)), 10L)
})

test_that("V16: speech turns are unique on (sitting_id, turn_no); the joins do not fan out", {
  local_sample_ap()
  expect_unique_key(get_speech_turns(collect = FALSE), c("sitting_id", "turn_no"))
  expect_unique_key(get_speech_turns(collect = FALSE), "first_action_id")
  n_view <- DBI::dbGetQuery(db_con(), "SELECT count(*) AS n FROM v_speech_turns")$n
  expect_identical(nrow(get_speech_turns(include_text = FALSE)), as.integer(n_view))
  got <- get_speech_turns(include_text = FALSE)
  expect_false(any(!is.na(got$party_at_time) & is.na(got$party_id_at_time)))
})

test_that("T-4.20 V17: an empty speech-turn result is a typed zero-row tibble", {
  local_sample_ap()
  pairs <- list(
    list(get_speech_turns(sitting_id = "none"), get_speech_turns(limit = 1)),
    list(
      get_speech_turns(from = 1800, to = 1800, include_text = FALSE),
      get_speech_turns(include_text = FALSE, limit = 1)
    )
  )
  for (pair in pairs) {
    expect_s3_class(pair[[1]], "tbl_df")
    expect_identical(nrow(pair[[1]]), 0L)
    expect_identical(col_classes(pair[[1]]), col_classes(pair[[2]]))
  }
  expect_identical(col_classes(pairs[[1]][[1]])[c("date", "is_quote")],
                   c(date = "Date", is_quote = "logical"))
})

test_that("V18: speech-turn arguments are validated at entry", {
  local_sample_ap()
  expect_error(get_speech_turns(member = "no-such-phid"), class = "ausparl_not_found")
  expect_error(get_speech_turns(party = "no such party"), class = "ausparl_not_found")
  expect_error(get_speech_turns(party = 99999), class = "ausparl_not_found")
  expect_error(get_speech_turns(party = "Labor"), class = "ausparl_ambiguous_input")

  bad <- list(
    list(member = 123), list(member = NA_character_), list(member = ""),
    list(party = NA), list(party = TRUE), list(party = 1.5), list(party = ""),
    list(parliament_id = NA), list(sitting_id = NA), list(sitting_id = character()),
    list(resolution = NA_character_), list(resolution = c("resolved", NA)),
    list(resolution = list("resolved")),
    list(chamber = "lords"), list(from = "1996"), list(from = 1997, to = 1996),
    list(include_text = "yes"), list(include_text = NA),
    list(columns = "nope"), list(collect = NA), list(limit = 0)
  )
  for (args in bad) {
    expect_error(do.call(get_speech_turns, args), class = "ausparl_input_error")
  }
})

test_that("T-4.4 V19: rendered SQL for one representative get_speech_turns() call", {
  local_sample_ap()
  expect_snapshot(dbplyr::sql_render(get_speech_turns(
    party = "ALP", from = 1996, to = 1996, include_text = FALSE, collect = FALSE
  )))
})
