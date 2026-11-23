# Full-database checks for module query: skipped unless AUSPARL_DB points at hansard.duckdb;
# never on CRAN. The database is opened read-only through db_connect().

test_that("T-4.18 Q13: a result at the size-guard ceiling stays within ~1.5 GB in R", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  # Three random 50k-row samples of actions, measured with and without `content`.
  per_row <- vapply(1:3, function(seed) {
    rows <- DBI::dbGetQuery(db_con(), sprintf(
      "SELECT * FROM actions USING SAMPLE reservoir(50000 ROWS) REPEATABLE (%d)", seed
    ))
    rows <- tibble::as_tibble(rows)
    c(
      text = as.numeric(utils::object.size(rows)) / nrow(rows),
      plain = as.numeric(utils::object.size(rows[setdiff(names(rows), "content")])) / nrow(rows)
    )
  }, numeric(2))
  bytes <- apply(per_row, 1, max)
  message(sprintf(
    "actions bytes/row: %.0f with content, %.0f without", bytes[["text"]], bytes[["plain"]]
  ))

  budget <- 1.5 * 2^30
  expect_lte(max_rows_text_default * bytes[["text"]], budget)
  expect_lte(max_rows_default * bytes[["plain"]], budget)
  # The text ceiling must be the lower one: content dominates row size.
  expect_lt(max_rows_text_default, max_rows_default)
})

test_that("T-4.4 V10: get_interjections() for 1996 matches direct SQL on the full DB", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  elapsed <- system.time(got <- get_interjections(from = 1996, to = 1996))[["elapsed"]]
  message(sprintf("get_interjections(from = 1996, to = 1996): %d rows in %.2f s", nrow(got),
                  elapsed))
  expect_identical(nrow(got), 12599L)

  direct <- DBI::dbGetQuery(db_con(), "
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
    WHERE s.date BETWEEN DATE '1996-01-01' AND DATE '1996-12-31'
  ")
  by_id <- function(d) {
    d <- as.data.frame(d)[order(d$interjection_action_id, method = "radix"), ]
    rownames(d) <- NULL
    d
  }
  expect_equal(by_id(got), by_id(direct))
})

test_that("T-4.4 S12: get_speeches() for 1996 matches direct SQL on the full DB", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  elapsed <- system.time(
    got <- get_speeches(from = 1996, to = 1996, include_text = FALSE)
  )[["elapsed"]]
  message(sprintf(
    "get_speeches(from = 1996, to = 1996, include_text = FALSE): %d rows in %.2f s",
    nrow(got), elapsed
  ))

  direct <- DBI::dbGetQuery(db_con(), "
    SELECT count(*) AS n
    FROM v_speech v
    JOIN sittings s ON s.sitting_id = v.sitting_id
    WHERE s.date BETWEEN DATE '1996-01-01' AND DATE '1996-12-31'
      AND (v.is_speech OR v.is_question OR v.is_answer)
      AND NOT v.is_interjection
      AND (v.resolution IS NULL OR v.resolution <> 'sentinel')
  ")$n
  expect_identical(nrow(got), as.integer(direct))
  expect_identical(sum(got$is_interjection), 0L)
  expect_identical(anyDuplicated(got$action_id), 0L)
  expect_false(any(!is.na(got$party_at_time) & is.na(got$party_id_at_time)))
})

test_that("T-4.4 V20: get_speech_turns() for 1996 matches direct SQL on the full DB", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  elapsed <- system.time(
    got <- get_speech_turns(from = 1996, to = 1996, include_text = FALSE)
  )[["elapsed"]]
  message(sprintf(
    "get_speech_turns(from = 1996, to = 1996, include_text = FALSE): %d rows in %.2f s",
    nrow(got), elapsed
  ))

  direct <- DBI::dbGetQuery(db_con(), "
    SELECT count(*) AS n
    FROM v_speech_turns t
    JOIN sittings s ON s.sitting_id = t.sitting_id
    WHERE s.date BETWEEN DATE '1996-01-01' AND DATE '1996-12-31'
  ")$n
  expect_identical(nrow(got), as.integer(direct))
  expect_identical(anyDuplicated(paste(got$sitting_id, got$turn_no)), 0L)
  expect_false(any(!is.na(got$party_at_time) & is.na(got$party_id_at_time)))
  expect_false(anyNA(got$has_quote))
  expect_false(anyNA(got$is_quote))

  # Unbounded and lazy: the whole view counted inside DuckDB.
  elapsed <- system.time(
    n_all <- dplyr::pull(dplyr::collect(dplyr::count(get_speech_turns(collect = FALSE))))
  )[["elapsed"]]
  message(sprintf("get_speech_turns(collect = FALSE) |> count(): %.0f turns in %.2f s",
                  n_all, elapsed))
  n_view <- DBI::dbGetQuery(db_con(), "SELECT count(*) AS n FROM v_speech_turns")$n
  expect_equal(n_all, n_view)
})

test_that("T-4.3 R13: \"immigration\" in 1996 equals the Guide reference SQL on the full DB", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)
  skip_if_not(fts_loaded(db_con()), "the DuckDB fts extension cannot be loaded")

  elapsed <- system.time(
    got <- search_speeches_by_terms("immigration", from = 1996, to = 1996, include_text = FALSE)
  )[["elapsed"]]
  message(sprintf(
    "search_speeches_by_terms(\"immigration\", from = 1996, to = 1996): %d rows in %.2f s",
    nrow(got), elapsed
  ))

  # The two-stage reference SQL (BM25 candidates, then a regex check), over all actions.
  reference <- "
    WITH candidates AS (
      SELECT action_id, score FROM (
        SELECT action_id,
               fts_main_actions.match_bm25(action_id, 'immigration', conjunctive := 1) AS score
        FROM actions WHERE year BETWEEN 1996 AND 1996
      ) t WHERE score IS NOT NULL
    )
    SELECT a.action_id, s.date, c.score,
           CAST(len(regexp_extract_all(a.content, '\\bimmigration\\b', 0, 'i')) AS INTEGER)
             AS n_hits
    FROM candidates c
    JOIN actions a USING (action_id)
    JOIN sittings s ON s.sitting_id = a.sitting_id
    WHERE s.date BETWEEN DATE '1996-01-01' AND DATE '1996-12-31'
      AND regexp_matches(a.content, '\\bimmigration\\b', 'i')"
  all_turns <- DBI::dbGetQuery(db_con(), reference)
  expect_identical(nrow(all_turns), 597L)

  # The same reference restricted to the B1 turns of v_speech, which search applies.
  b1 <- DBI::dbGetQuery(db_con(), paste0("
    SELECT r.* FROM (", reference, ") r JOIN v_speech v USING (action_id)
    WHERE (v.is_speech OR v.is_question OR v.is_answer) AND NOT v.is_interjection
      AND (v.resolution IS NULL OR v.resolution <> 'sentinel')"))
  by_id <- function(d) {
    d <- as.data.frame(d)[order(d$action_id, method = "radix"), ]
    rownames(d) <- NULL
    d
  }
  expect_equal(by_id(got[c("action_id", "date", "score", "n_hits")]), by_id(b1))
  expect_identical(sum(got$is_interjection), 0L)
  expect_identical(anyDuplicated(got$action_id), 0L)
})

test_that("T-4.15 I9: every exported query function runs once on the full DB (timed)", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  sitting <- get_sittings(
    date = in_range("1996-01-01", "1996-12-31"), chamber = "house", limit = 1
  )$sitting_id
  debate <- get_debates(sitting_id = sitting, limit = 1)$debate_id

  calls <- list(
    get_sittings = quote(get_sittings(date = in_range("1996-01-01", "1996-12-31"))),
    get_debates = quote(get_debates(sitting_id = sitting)),
    get_subdebates = quote(get_subdebates(debate_id = debate)),
    get_actions = quote(get_actions(sitting_id = sitting)),
    get_provenance = quote(get_provenance(schema_generation = "v2.2")),
    get_members = quote(get_members()),
    get_parliaments = quote(get_parliaments()),
    get_parties = quote(get_parties()),
    get_electorates = quote(get_electorates()),
    get_parl_service = quote(get_parl_service(active_during = 1996)),
    get_party_service = quote(get_party_service(active_during = 1996)),
    get_ministries = quote(get_ministries()),
    get_ministry_records = quote(get_ministry_records(active_during = 1996)),
    get_shadow_ministry_records = quote(get_shadow_ministry_records(active_during = 1996)),
    get_committee_members = quote(get_committee_members(active_during = 1996)),
    get_presiding_officers = quote(get_presiding_officers()),
    get_elections = quote(get_elections()),
    get_occupations = quote(get_occupations()),
    get_qualifications = quote(get_qualifications()),
    get_schools = quote(get_schools()),
    get_interjections = quote(get_interjections(from = 1996, to = 1996)),
    get_sitting_timeline = quote(get_sitting_timeline(sitting_id = sitting)),
    find_member = quote(find_member("howard")),
    get_speeches = quote(get_speeches(from = 1996, to = 1996, include_text = FALSE)),
    get_speech_turns = quote(get_speech_turns(from = 1996, to = 1996, include_text = FALSE)),
    search_speeches_by_terms = quote(
      search_speeches_by_terms("immigration", from = 1996, to = 1996, include_text = FALSE)
    )
  )
  exported <- c(grep("^get_", getNamespaceExports("ausparl"), value = TRUE),
                "find_member", "search_speeches_by_terms")
  expect_setequal(names(calls), exported)

  for (fn in names(calls)) {
    elapsed <- system.time(result <- eval(calls[[fn]]))[["elapsed"]]
    message(sprintf("%-32s %8d rows  %6.2f s", fn, nrow(result), elapsed))
    expect_s3_class(result, "tbl_df")
    expect_gt(nrow(result), 0, label = fn)
  }
})
