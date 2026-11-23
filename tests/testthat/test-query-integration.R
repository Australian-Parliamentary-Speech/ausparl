# Module integration: query. Exercises the seams between filters, tables, views, speeches
# and search on the bundled sample DB (no network, no mocks).

local_query_sample <- function(env = parent.frame()) {
  withr::local_envvar(AUSPARL_DB = NA, .local_envir = env)
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
  db_con()
}

skip_without_fts <- function() {
  testthat::skip_on_cran()
  ok <- tryCatch(
    {
      load_fts_extension(db_con())
      TRUE
    },
    error = function(e) FALSE
  )
  testthat::skip_if_not(ok, "fts extension cannot be loaded")
}

query_getters <- function() {
  sort(grep("^get_", getNamespaceExports("ausparl"), value = TRUE))
}

test_that("T-4.2 I1: find member -> speeches -> search compose consistently", {
  con <- local_query_sample()

  found <- find_member("john howard")
  expect_true("ZD4" %in% found$PHID)

  speeches <- get_speeches(member = "ZD4", include_text = FALSE)
  actions <- get_actions(PHID = "ZD4")
  expect_gt(nrow(speeches), 0)
  expect_true(all(speeches$action_id %in% actions$action_id))

  flags <- c("is_speech", "is_question", "is_answer", "is_interjection")
  both <- merge(speeches[c("action_id", flags)], actions[c("action_id", flags)],
    by = "action_id", suffixes = c(".s", ".a")
  )
  for (f in flags) expect_identical(both[[paste0(f, ".s")]], both[[paste0(f, ".a")]])

  skip_without_fts()
  hits <- search_speeches_by_terms("repatriation", member = "ZD4", include_text = FALSE)
  expect_gt(nrow(hits), 0)
  expect_true(all(hits$action_id %in% speeches$action_id))

  reference <- DBI::dbGetQuery(con, "
    SELECT a.action_id
    FROM (SELECT action_id,
                 fts_main_actions.match_bm25(action_id, 'repatriation') AS score
          FROM actions) c
    JOIN v_speech a USING (action_id)
    WHERE c.score IS NOT NULL AND a.PHID = 'ZD4'
      AND (a.is_speech OR a.is_question OR a.is_answer) AND NOT a.is_interjection
      AND (a.resolution IS NULL OR a.resolution <> 'sentinel')
      AND regexp_matches(a.content, '\\brepatriation\\b', 'i')")
  expect_setequal(hits$action_id, reference$action_id)
})

test_that("T-4.17 I2: an interjector's interjections agree between views and speeches", {
  local_query_sample()
  interjectors <- get_interjections()$interjector_PHID
  interjectors <- head(names(sort(table(interjectors), decreasing = TRUE)), 3)
  expect_length(interjectors, 3)

  for (phid in interjectors) {
    from_view <- get_interjections(interjector = phid)$interjection_action_id
    from_speeches <- get_speeches(
      member = phid, type = "interjection", include_text = FALSE
    )$action_id
    expect_gt(length(from_view), 0)
    expect_setequal(from_view, from_speeches)
  }
})

test_that("T-4.17 I3: B1 applies to speeches and search, not to raw access", {
  local_query_sample()
  expect_identical(sum(get_speeches(include_text = FALSE)$is_interjection), 0L)
  expect_gt(sum(get_actions()$is_interjection), 0)
  expect_gt(nrow(get_interjections()), 0)

  skip_without_fts()
  hits <- search_speeches_by_terms("government", include_text = FALSE)
  expect_gt(nrow(hits), 0)
  expect_identical(sum(hits$is_interjection), 0L)
})

test_that("T-4.1 I4: each sitting's timeline matches its actions", {
  local_query_sample()
  for (id in get_sittings()$sitting_id) {
    timeline <- get_sitting_timeline(sitting_id = id, include_text = FALSE)
    actions <- get_actions(sitting_id = id)
    expect_identical(nrow(timeline), nrow(actions), info = id)
    expect_setequal(timeline$action_id, actions$action_id)
  }
})

test_that("T-4.20 I5: every query function returns a typed zero-row result", {
  local_query_sample()

  for (getter in query_getters()) {
    handwritten <- c(
      "get_interjections", "get_sitting_timeline", "get_speeches", "get_speech_turns"
    )
    if (getter %in% handwritten) {
      next
    }
    fun <- getExportedValue("ausparl", getter)
    first <- names(formals(fun))[1]
    probe <- fun(limit = 1)
    value <- if (is.character(probe[[first]])) {
      "zz__none"
    } else if (inherits(probe[[first]], "Date")) {
      as.Date("1800-01-01")
    } else {
      -999999
    }
    empty <- do.call(fun, stats::setNames(list(value), first))
    expect_s3_class(empty, "tbl_df")
    expect_identical(nrow(empty), 0L, info = getter)
    expect_identical(lapply(empty, class), lapply(probe, class), info = getter)
  }

  others <- list(
    get_interjections(from = 1800, to = 1800),
    get_sitting_timeline(sitting_id = "zz__none"),
    get_speeches(from = 1800, to = 1800),
    get_speech_turns(from = 1800, to = 1800),
    find_member("zzqqxxnone")
  )
  for (empty in others) {
    expect_s3_class(empty, "tbl_df")
    expect_identical(nrow(empty), 0L)
    expect_gt(ncol(empty), 0)
  }

  skip_without_fts()
  none <- search_speeches_by_terms("zzqqxxnone")
  expect_s3_class(none, "tbl_df")
  expect_identical(nrow(none), 0L)
})

test_that("T-4.18 I6: the size guard behaves the same across query functions", {
  local_query_sample()
  withr::local_options(ausparl.max_rows = 1, ausparl.max_rows_text = 1)

  expect_error(get_actions(), class = "ausparl_input_error")
  expect_error(get_members(), class = "ausparl_input_error")
  expect_error(get_interjections(), class = "ausparl_input_error")
  expect_error(get_sitting_timeline(), class = "ausparl_input_error")
  expect_error(get_speeches(), class = "ausparl_input_error")

  expect_s3_class(get_actions(collect = FALSE), "tbl_lazy")
  expect_s3_class(get_interjections(collect = FALSE), "tbl_lazy")
  expect_s3_class(get_sitting_timeline(collect = FALSE), "tbl_lazy")
  expect_s3_class(get_speeches(collect = FALSE), "tbl_lazy")

  skip_without_fts()
  expect_error(search_speeches_by_terms("government"), class = "ausparl_input_error")
  expect_s3_class(search_speeches_by_terms("government", collect = FALSE), "tbl_lazy")
})

test_that("T-4.19 I7: the party bridge holds for speeches and search", {
  local_query_sample()
  speeches <- get_speeches(include_text = FALSE)
  expect_true(all(!is.na(speeches$party_id_at_time[!is.na(speeches$party_at_time)])))

  skip_without_fts()
  hits <- search_speeches_by_terms("government", include_text = FALSE)
  expect_true(all(!is.na(hits$party_id_at_time[!is.na(hits$party_at_time)])))
})

test_that("T-4.4 I8: lazy speeches and search compose inside DuckDB", {
  local_query_sample()
  skip_without_fts()
  speeches <- get_speeches(chamber = "house", include_text = FALSE, collect = FALSE)
  hits <- search_speeches_by_terms("government", include_text = FALSE, collect = FALSE)

  joined <- dplyr::semi_join(speeches, hits, by = "action_id") |> dplyr::collect()
  expected <- intersect(
    dplyr::collect(speeches)$action_id,
    dplyr::collect(hits)$action_id
  )
  expect_gt(length(expected), 0)
  expect_setequal(joined$action_id, expected)
})

test_that("T-4.1 N1: exports are the 47 prefix-free names of the public API", {
  expected <- c(
    "db_connect", "db_disconnect", "db_con", "db_info", "db_tbl", "db_download", "in_range",
    "matches_pattern", "result_provenance",
    "get_speeches", "get_speech_turns", "search_speeches_by_terms", "get_sitting_timeline",
    "get_interjections",
    "find_member", "member_profile", "member_activity", "party_activity", "parliament_summary",
    "add_party", "add_role", "add_government_status", "add_electorate", "add_age",
    "add_member", "add_debate",
    "get_sittings", "get_debates", "get_subdebates", "get_actions", "get_members",
    "get_parliaments", "get_parties", "get_party_service", "get_parl_service",
    "get_electorates", "get_elections", "get_ministries", "get_ministry_records",
    "get_shadow_ministry_records", "get_committee_members", "get_presiding_officers",
    "get_occupations", "get_qualifications", "get_schools", "get_provenance", "as_corpus"
  )
  expect_length(expected, 47)
  exports <- getNamespaceExports("ausparl")
  expect_setequal(exports, expected)
  expect_identical(grep("^ap_", exports, value = TRUE), character())
})
