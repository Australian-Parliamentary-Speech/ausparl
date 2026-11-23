# Tests for member lookup and speech queries (S1-S11): find_member() and get_speeches().
# Sample DB only; no network.

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

sort_rows <- function(d, key) {
  d <- as.data.frame(d)
  d <- d[order(d[[key]], method = "radix"), , drop = FALSE]
  rownames(d) <- NULL
  d
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

speech_out_cols <- c(
  "action_id", "sitting_id", "date", "chamber", "chamber_venue", "parliament_id",
  "PHID", "name_raw", "party_id_at_time", "party_at_time",
  "is_speech", "is_question", "is_answer", "is_interjection", "is_non_speech", "is_petition",
  "is_motion_no_speech", "has_quote"
)

# The B1 default, written by hand.
b1_where <- "(v.is_speech OR v.is_question OR v.is_answer) AND NOT v.is_interjection
             AND v.resolution <> 'sentinel'"

# The speech query written by hand, with a WHERE clause.
speech_sql <- function(where = b1_where, content = FALSE) {
  text_col <- if (content) ", v.content" else ""
  paste0("
    SELECT v.action_id, v.sitting_id, s.date, s.chamber, v.chamber_venue, s.parliament_id,
           v.PHID, v.name_raw, pa.party_id AS party_id_at_time, p.party_at_time,
           v.is_speech, v.is_question, v.is_answer, v.is_interjection, v.is_non_speech,
           v.is_petition, v.is_motion_no_speech, v.has_quote", text_col, "
    FROM v_speech v
    JOIN sittings s ON s.sitting_id = v.sitting_id
    LEFT JOIN v_party_at_time p ON p.action_id = v.action_id
    LEFT JOIN parties pa ON pa.Name = p.party_at_time
    WHERE ", where)
}

expect_speeches_equal <- function(got, where, content = FALSE) {
  direct <- DBI::dbGetQuery(db_con(), speech_sql(where, content))
  expect_equal(sort_rows(got, "action_id"), sort_rows(direct, "action_id"))
  invisible(got)
}

member_sql <- function(where_member = "TRUE", where_service = NULL) {
  service <- if (is.null(where_service)) {
    ""
  } else {
    paste0(" AND EXISTS (SELECT 1 FROM parl_service ps WHERE ps.PHID = m.PHID AND ",
           where_service, ")")
  }
  paste0("
    SELECT m.PHID, m.DisplayName, m.Gender, m.DateOfBirth, m.State,
      CASE WHEN sum((ps.MemberOrSenator = 'Member')::INT) > 0
                AND sum((ps.MemberOrSenator = 'Senator')::INT) > 0 THEN 'house, senate'
           WHEN sum((ps.MemberOrSenator = 'Member')::INT) > 0 THEN 'house'
           WHEN sum((ps.MemberOrSenator = 'Senator')::INT) > 0 THEN 'senate' END AS chambers,
      min(ps.DateStart) AS first_service,
      CASE WHEN count(ps.PHID) > count(ps.DateEnd) THEN NULL ELSE max(ps.DateEnd) END
        AS last_service
    FROM members m LEFT JOIN parl_service ps ON ps.PHID = m.PHID
    WHERE ", where_member, service, "
    GROUP BY m.PHID, m.DisplayName, m.Gender, m.DateOfBirth, m.State")
}

expect_members_equal <- function(got, sql) {
  expect_equal(sort_rows(got, "PHID"), sort_rows(DBI::dbGetQuery(db_con(), sql), "PHID"))
}

# The known speech: John Howard (ZD4), Liberal (party 4), house, parliament 40, 2002-10-15.
known <- "house_2002-10-15_R2"

# ---- S1 find_member() ---------------------------------------------------------------------------

test_that("T-4.1 S1: find_member() matches every name token, in any order and case", {
  local_sample_ap()
  got <- find_member("john howard")
  expect_s3_class(got, "tbl_df")
  expect_identical(got$PHID, "ZD4")
  expect_identical(find_member("HOWARD  John")$PHID, "ZD4")
  expect_identical(find_member(" winston  JOHN ")$PHID, "ZD4")
  expect_setequal(find_member("howard")$PHID, c("ZD4", "CT4"))
  expect_members_equal(
    find_member("howard"),
    member_sql("m.DisplayName ILIKE '%howard%'")
  )
  expect_members_equal(
    find_member("the hon peter"),
    member_sql("m.DisplayName ILIKE '%the%' AND m.DisplayName ILIKE '%hon%'
                AND m.DisplayName ILIKE '%peter%'")
  )
  expect_identical(find_member("ZD4")$PHID, character())
  # Wildcards are literal.
  expect_identical(nrow(find_member("%")), 0L)
  expect_identical(nrow(find_member("h_ward")), 0L)
})

test_that("S1: chamber and active_during equal direct SQL", {
  local_sample_ap()
  expect_members_equal(
    find_member("peter", chamber = "Senate"),
    member_sql("m.DisplayName ILIKE '%peter%'", "ps.MemberOrSenator = 'Senator'")
  )
  expect_members_equal(
    find_member("a", chamber = "house", active_during = 2012),
    member_sql(
      "m.DisplayName ILIKE '%a%'",
      "ps.MemberOrSenator = 'Member' AND ps.DateStart <= DATE '2012-12-31'
       AND (ps.DateEnd IS NULL OR ps.DateEnd >= DATE '2012-01-01')"
    )
  )
  expect_members_equal(
    find_member("e", active_during = in_range("1950-01-01", "1960-06-30")),
    member_sql(
      "m.DisplayName ILIKE '%e%'",
      "ps.DateStart <= DATE '1960-06-30'
       AND (ps.DateEnd IS NULL OR ps.DateEnd >= DATE '1950-01-01')"
    )
  )
  expect_members_equal(
    find_member("e", chamber = c("house", "senate")),
    member_sql("m.DisplayName ILIKE '%e%'", "ps.MemberOrSenator IN ('Member', 'Senator')")
  )
  both <- find_member("e")
  expect_true("house, senate" %in% both$chambers)
  expect_identical(find_member("howard", chamber = "senate")$PHID, character())
})

test_that("T-4.20 S1: no match is a typed zero-row tibble; arguments are validated", {
  local_sample_ap()
  none <- find_member("nobody-by-this-name")
  expect_identical(nrow(none), 0L)
  expect_identical(col_classes(none), col_classes(find_member("howard")))
  expect_identical(col_classes(none)[["first_service"]], "Date")

  for (bad in list("", "   ", NA_character_, c("a", "b"), 1, NULL)) {
    expect_error(find_member(bad), class = "ausparl_input_error")
  }
  expect_error(find_member("howard", chamber = "lords"), class = "ausparl_input_error")
  expect_error(find_member("howard", active_during = "1996"), class = "ausparl_input_error")
})

# ---- S2 filters ---------------------------------------------------------------------------------

test_that("T-4.2 S2: member, party, parliament, chamber and date filters return the known speech", {
  local_sample_ap()
  checks <- list(
    list(get_speeches(member = "ZD4", include_text = FALSE), "v.PHID = 'ZD4'"),
    list(get_speeches(party = 4, include_text = FALSE), "pa.party_id = 4"),
    list(
      get_speeches(party = "liberal party of australia", include_text = FALSE),
      "pa.party_id = 4"
    ),
    list(get_speeches(parliament_id = 40, include_text = FALSE), "s.parliament_id = 40"),
    list(get_speeches(chamber = "HOUSE", include_text = FALSE), "s.chamber = 'house'"),
    list(
      get_speeches(from = "2002-10-15", to = "2002-10-15", include_text = FALSE),
      "s.date = DATE '2002-10-15'"
    ),
    list(
      get_speeches(from = 2002, to = 2002, include_text = FALSE),
      "s.date BETWEEN DATE '2002-01-01' AND DATE '2002-12-31'"
    )
  )
  for (check in checks) {
    expect_true(known %in% check[[1]]$action_id)
    expect_speeches_equal(check[[1]], paste(b1_where, "AND", check[[2]]))
  }

  combined <- get_speeches(
    member = "ZD4", party = "LIBERAL PARTY OF AUSTRALIA", parliament_id = in_range(40, 40),
    chamber = "house", chamber_venue = 1, from = 2002, include_text = FALSE
  )
  expect_true(known %in% combined$action_id)
  expect_speeches_equal(combined, paste(
    b1_where, "AND v.PHID = 'ZD4' AND pa.party_id = 4 AND s.parliament_id = 40",
    "AND s.chamber = 'house' AND v.chamber_venue = 1 AND s.date >= DATE '2002-01-01'"
  ))
  expect_speeches_equal(
    get_speeches(member = c("ZD4", "CT4"), parliament_id = c(38, 40), include_text = FALSE),
    paste(b1_where, "AND v.PHID IN ('ZD4', 'CT4') AND s.parliament_id IN (38, 40)")
  )
})

test_that("S2: unfiltered default equals direct SQL; tibble or lazy and pipeable", {
  local_sample_ap()
  got <- get_speeches()
  expect_s3_class(got, "tbl_df")
  expect_identical(names(got), c(speech_out_cols, "content"))
  expect_speeches_equal(got, b1_where, content = TRUE)

  lazy <- get_speeches(collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  counted <- lazy |>
    dplyr::count(.data$chamber) |>
    dplyr::collect()
  expect_identical(sum(counted$n), as.numeric(nrow(got)))
  expect_identical(nrow(get_speeches(limit = 7)), 7L)
  expect_identical(
    names(get_speeches(columns = c("date", "action_id"), limit = 1)),
    c("date", "action_id")
  )
})

test_that("S2: arguments are validated at entry", {
  local_sample_ap()
  expect_error(get_speeches(from = "1996"), class = "ausparl_input_error")
  expect_error(get_speeches(from = 1997, to = 1996), class = "ausparl_input_error")
  expect_error(get_speeches(chamber = "lords"), class = "ausparl_input_error")
  expect_error(get_speeches(parliament_id = NA), class = "ausparl_input_error")
  expect_error(get_speeches(chamber_venue = list(1)), class = "ausparl_input_error")
  expect_error(get_speeches(include_presiding = NA), class = "ausparl_input_error")
  expect_error(get_speeches(include_text = "yes"), class = "ausparl_input_error")
  expect_error(get_speeches(columns = "nope"), class = "ausparl_input_error")
  expect_error(get_speeches(collect = NA), class = "ausparl_input_error")
  expect_error(get_speeches(limit = 0), class = "ausparl_input_error")
  for (bad in list(123, NA_character_, character(), "", matches_pattern("%x%"))) {
    expect_error(get_speeches(member = bad), class = "ausparl_input_error")
  }
  for (bad in list(NA, 1.5, "", "  ", character(), TRUE, list("ALP"), NA_real_)) {
    expect_error(get_speeches(party = bad), class = "ausparl_input_error")
  }
})

# ---- S3 / S4 turn types -------------------------------------------------------------------------

test_that("T-4.17 S3: B1 excludes interjections unless requested", {
  local_sample_ap()
  default <- get_speeches(include_text = FALSE, include_presiding = TRUE)
  expect_identical(sum(default$is_interjection), 0L)

  with_inj <- get_speeches(
    type = c("speech", "question", "answer", "interjection"), include_text = FALSE,
    include_presiding = TRUE
  )
  expect_gt(sum(with_inj$is_interjection), 0)
  expect_true(all(default$action_id %in% with_inj$action_id))

  only <- get_speeches(type = "interjection", include_text = FALSE)
  expect_gt(nrow(only), 0)
  expect_true(all(only$is_interjection))
})

test_that("S4: flag OR semantics equal direct SQL; invalid type is an input error", {
  local_sample_ap()
  no_sentinel <- "v.resolution <> 'sentinel'"
  cases <- list(
    list("speech", "v.is_speech AND NOT v.is_interjection"),
    list("question", "v.is_question AND NOT v.is_interjection"),
    list("answer", "v.is_answer AND NOT v.is_interjection"),
    list("interjection", "v.is_interjection"),
    list(c("question", "answer"), "(v.is_question OR v.is_answer) AND NOT v.is_interjection"),
    list(c("Speech", "interjection"), "(v.is_speech OR v.is_interjection)"),
    list(
      c("speech", "question", "answer", "interjection"),
      "(v.is_speech OR v.is_question OR v.is_answer OR v.is_interjection)"
    )
  )
  for (case in cases) {
    expect_speeches_equal(
      get_speeches(type = case[[1]], include_text = FALSE),
      paste(case[[2]], "AND", no_sentinel)
    )
  }
  for (bad in list("speeches", c("speech", "motion"), NA_character_, character(), 1, NULL)) {
    expect_error(get_speeches(type = bad), class = "ausparl_input_error")
  }
})

# ---- S5 presiding and unmatched turns -----------------------------------------------------------

test_that("S5: include_presiding toggles sentinel rows; rows with no member PHID are kept", {
  local_sample_ap()
  sentinel_ids <- DBI::dbGetQuery(db_con(), "
    SELECT action_id FROM v_speech WHERE resolution = 'sentinel'
      AND (is_speech OR is_question OR is_answer) AND NOT is_interjection
  ")$action_id
  # Speakers who are not one member: none has a PHID, and all are kept by default.
  unmatched_ids <- DBI::dbGetQuery(db_con(), "
    SELECT action_id FROM v_speech
    WHERE resolution IN ('unmatched', 'unknown', 'collective', 'non_member')
      AND (is_speech OR is_question OR is_answer) AND NOT is_interjection
  ")$action_id
  expect_gt(length(sentinel_ids), 0)
  expect_gt(length(unmatched_ids), 0)

  without <- get_speeches(include_text = FALSE)
  with <- get_speeches(include_text = FALSE, include_presiding = TRUE)
  expect_false(any(sentinel_ids %in% without$action_id))
  expect_true(all(sentinel_ids %in% with$action_id))
  expect_setequal(setdiff(with$action_id, without$action_id), sentinel_ids)
  expect_true(all(unmatched_ids %in% without$action_id))
  expect_true(all(is.na(without$PHID[without$action_id %in% unmatched_ids])))
  expect_speeches_equal(
    with,
    "(v.is_speech OR v.is_question OR v.is_answer) AND NOT v.is_interjection"
  )
})

# ---- S6 party resolution ------------------------------------------------------------------------

test_that("S6: party resolves by id, abbreviation, name and unique substring", {
  local_sample_ap()
  by_id <- function(x) {
    sort(get_speeches(party = x, include_text = FALSE, include_presiding = TRUE)$action_id)
  }
  alp <- by_id(1)
  expect_gt(length(alp), 0)
  expect_identical(by_id("ALP"), alp)
  expect_identical(by_id("alp"), alp)
  expect_identical(by_id(" Australian Labor Party "), alp)
  expect_identical(by_id(1L), alp)
  expect_identical(by_id(factor("ALP")), alp)
  # A unique substring of Name.
  expect_identical(by_id("protectionist"), by_id(48))
  expect_gt(length(by_id(48)), 0)
  # Several values are OR-ed.
  expect_setequal(by_id(c("ALP", "GRN")), c(alp, by_id(7)))
  # The filter compares the party at the time, and ALP is party 1 only (no lineage).
  got <- get_speeches(party = "ALP", include_text = FALSE)
  expect_true(all(got$party_id_at_time == 1L))
  expect_true(all(got$party_at_time == "Australian Labor Party"))
})

test_that("S6: ambiguous and unknown parties raise classed errors", {
  local_sample_ap()
  expect_error(get_speeches(party = "LIB"), class = "ausparl_ambiguous_input")
  expect_error(get_speeches(party = "lib"), class = "ausparl_ambiguous_input")
  expect_error(get_speeches(party = "Labor"), class = "ausparl_ambiguous_input")
  expect_error(get_speeches(party = c("ALP", "Labor")), class = "ausparl_ambiguous_input")
  err <- rlang::catch_cnd(get_speeches(party = "LIB"), classes = "ausparl_ambiguous_input")
  expect_s3_class(err, "ausparl_error")
  expect_error(get_speeches(party = "no such party"), class = "ausparl_not_found")
  expect_error(get_speeches(party = 999), class = "ausparl_not_found")
  expect_error(get_speeches(party = c(1, 999)), class = "ausparl_not_found")
})

# ---- S7 bridge ----------------------------------------------------------------------------------

test_that("T-4.19 S7: every non-NA party_at_time has a non-NA party_id_at_time", {
  local_sample_ap()
  got <- get_speeches(
    type = c("speech", "question", "answer", "interjection"), include_presiding = TRUE,
    include_text = FALSE
  )
  expect_gt(sum(!is.na(got$party_at_time)), 0)
  expect_false(any(!is.na(got$party_at_time) & is.na(got$party_id_at_time)))
  expect_identical(is.na(got$party_at_time), is.na(got$party_id_at_time))
})

# ---- S8 unknown member --------------------------------------------------------------------------

test_that("S8: an unknown member PHID raises ausparl_not_found", {
  local_sample_ap()
  expect_error(get_speeches(member = "no-such-phid"), class = "ausparl_not_found")
  expect_error(get_speeches(member = c("ZD4", "no-such-phid")), class = "ausparl_not_found")
})

# ---- S9 grain -----------------------------------------------------------------------------------

test_that("S9: the party joins do not fan out", {
  local_sample_ap()
  all_types <- c("speech", "question", "answer", "interjection")
  expect_unique_key(
    get_speeches(type = all_types, include_presiding = TRUE, collect = FALSE),
    "action_id"
  )
  expect_unique_key(get_speeches(collect = FALSE), "action_id")
  # Every v_speech row with a turn-type flag; quotes carry none, so they are never returned.
  n_view <- DBI::dbGetQuery(db_con(), "SELECT count(*) AS n FROM v_speech
    WHERE is_speech OR is_question OR is_answer OR is_interjection")$n
  got <- get_speeches(type = all_types, include_presiding = TRUE, include_text = FALSE)
  expect_identical(nrow(got), as.integer(n_view))
  quotes <- DBI::dbGetQuery(db_con(), "SELECT action_id FROM v_speech
    WHERE action_type = 'quote'")$action_id
  expect_gt(length(quotes), 0)
  expect_false(any(quotes %in% got$action_id))
})

# ---- S10 include_text and the text threshold ----------------------------------------------------

test_that("T-4.18 S10: include_text toggles content; the text threshold applies", {
  local_sample_ap()
  with_text <- get_speeches(member = "ZD4")
  without <- get_speeches(member = "ZD4", include_text = FALSE)
  expect_identical(names(with_text), c(speech_out_cols, "content"))
  expect_identical(names(without), speech_out_cols)
  expect_identical(
    sort_rows(with_text[speech_out_cols], "action_id"),
    sort_rows(without, "action_id")
  )
  expect_true(all(!is.na(with_text$content)))
  expect_speeches_equal(with_text, paste(b1_where, "AND v.PHID = 'ZD4'"), content = TRUE)

  withr::local_options(ausparl.max_rows_text = 10, ausparl.max_rows = 1e6)
  expect_error(get_speeches(), class = "ausparl_input_error")
  expect_error(get_speeches(columns = c("action_id", "content")), class = "ausparl_input_error")
  n <- nrow(get_speeches(include_text = FALSE))
  expect_gt(n, 10)
  expect_identical(nrow(get_speeches(columns = "action_id")), n)
  expect_identical(nrow(get_speeches(limit = 10)), 10L)
})

# ---- S11 empty results and SQL snapshots --------------------------------------------------------

test_that("T-4.20 S11: an empty result is a typed zero-row tibble", {
  local_sample_ap()
  pairs <- list(
    list(get_speeches(from = 1800, to = 1800), get_speeches(limit = 1)),
    list(
      get_speeches(member = "ZD4", chamber = "senate", include_text = FALSE),
      get_speeches(include_text = FALSE, limit = 1)
    )
  )
  for (pair in pairs) {
    expect_s3_class(pair[[1]], "tbl_df")
    expect_identical(nrow(pair[[1]]), 0L)
    expect_identical(col_classes(pair[[1]]), col_classes(pair[[2]]))
  }
  expect_identical(col_classes(pairs[[1]][[1]])[["date"]], "Date")
  expect_identical(col_classes(pairs[[1]][[1]])[["party_id_at_time"]], "integer")
})

test_that("T-4.4 S11: rendered SQL for one representative call per function", {
  local_sample_ap()
  render <- function(lazy) dbplyr::sql_render(lazy)
  expect_snapshot(render(get_speeches(
    party = "ALP", from = 1996, to = 1996, chamber = "House", include_text = FALSE,
    collect = FALSE
  )))
  expect_snapshot(render(find_member_query(
    c("john", "howard"), chamber = "house", active_during = 1996, call = NULL
  )))
})
