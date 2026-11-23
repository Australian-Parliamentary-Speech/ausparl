# Module integration: context. Checks that join helpers and anchor aggregates agree with
# each other and compose on query-module output, on the bundled sample DB (no mocks).

local_context_sample <- function(env = parent.frame()) {
  withr::local_envvar(AUSPARL_DB = NA, .local_envir = env)
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
  db_con()
}

skip_without_fts_ctx <- function() {
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

count_words <- function(x) {
  x[is.na(x)] <- ""
  lengths(regmatches(x, gregexpr("\\S+", x)))
}

chain_all <- function(x) {
  x |>
    add_member() |>
    add_party() |>
    add_electorate() |>
    add_age() |>
    add_role() |>
    add_government_status() |>
    add_debate()
}

key_counts <- function(df, keys) {
  out <- stats::aggregate(
    list(n = rep(1, nrow(df))), df[keys],
    FUN = sum
  )
  out[do.call(order, out[keys]), , drop = FALSE]
}

test_that("T-4.5 C1: all seven helpers chain on speeches, lazy and collected", {
  local_context_sample()
  base <- get_speeches(include_text = FALSE)

  collected <- suppressMessages(chain_all(base))
  expect_s3_class(collected, "tbl_df")
  expect_identical(nrow(collected), nrow(base))
  expect_identical(collected$action_id, base$action_id)
  expect_true(all(c(
    "DisplayName", "party_abbrev_at_time", "electorate_at_time", "age_at_time",
    "role_at_time", "government_status_at_time", "debate_title", "seq"
  ) %in% names(collected)))

  lazy <- suppressMessages(chain_all(get_speeches(include_text = FALSE, collect = FALSE)))
  expect_s3_class(lazy, "tbl_lazy")
  expect_unique_key(lazy, "action_id")
  expect_identical(
    dplyr::pull(dplyr::count(lazy), n), as.numeric(nrow(base))
  )
})

test_that("T-4.5 C2: party counts from join equal party_activity() n_speeches", {
  local_context_sample()
  joined <- suppressMessages(add_party(get_speeches(include_text = FALSE)))
  joined <- joined[!is.na(joined$party_at_time), ]
  from_join <- key_counts(joined, c("party_at_time", "parliament_id", "chamber"))

  activity <- party_activity()
  keys <- c("party_at_time", "parliament_id", "chamber")
  activity <- activity[activity$n_speeches > 0, c(keys, "n_speeches")]
  activity <- activity[do.call(order, activity[c("party_at_time", "parliament_id", "chamber")]), ]

  expect_identical(nrow(from_join), nrow(activity))
  expect_equal(from_join$n, activity$n_speeches, ignore_attr = TRUE)
  expect_identical(from_join$party_at_time, activity$party_at_time)
})

test_that("T-4.5 C3: member speech and word counts agree with member_activity()", {
  local_context_sample()
  speeches <- get_speeches(include_text = TRUE)
  speeches <- speeches[!is.na(speeches$PHID), ]
  speeches$words <- count_words(speeches$content)

  keys <- c("PHID", "parliament_id", "chamber")
  n_sp <- key_counts(speeches, keys)
  words <- stats::aggregate(list(words = speeches$words), speeches[keys], FUN = sum)
  expected <- merge(n_sp, words, by = keys)

  activity <- member_activity()
  got <- merge(expected, activity[c(keys, "n_speeches", "n_words")], by = keys, all.x = TRUE)
  expect_identical(nrow(got), nrow(expected))
  expect_equal(got$n_speeches, got$n, ignore_attr = TRUE)
  expect_equal(got$n_words, got$words, ignore_attr = TRUE)
})

test_that("T-4.5 C4: interjections agree across views, join and anchor", {
  local_context_sample()
  sittings <- get_sittings(columns = c("sitting_id", "parliament_id"))

  inter <- get_interjections()
  inter <- merge(inter, sittings, by = "sitting_id")

  # Made, by party: view -> join -> count equals party activity.
  made <- data.frame(
    action_id = inter$interjection_action_id,
    parliament_id = inter$parliament_id, chamber = inter$chamber
  )
  made <- add_party(made)
  made <- made[!is.na(made$party_at_time), ]
  from_view <- key_counts(made, c("party_at_time", "parliament_id", "chamber"))
  party <- party_activity()
  party <- party[party$n_interjections > 0, ]
  got <- merge(from_view, party, by = c("party_at_time", "parliament_id", "chamber"), all = TRUE)
  expect_false(anyNA(got$n))
  expect_equal(got$n_interjections, got$n, ignore_attr = TRUE)

  # Received, by target member: view equals member activity.
  received <- inter[!is.na(inter$target_PHID), ]
  received <- data.frame(
    PHID = received$target_PHID,
    parliament_id = received$parliament_id, chamber = received$chamber
  )
  from_view <- key_counts(received, c("PHID", "parliament_id", "chamber"))
  member <- member_activity()
  member <- member[member$n_interjections_received > 0, ]
  got <- merge(from_view, member, by = c("PHID", "parliament_id", "chamber"), all = TRUE)
  expect_false(anyNA(got$n))
  expect_equal(got$n_interjections_received, got$n, ignore_attr = TRUE)
})

test_that("T-4.5 C5: search results compose with join helpers", {
  local_context_sample()
  skip_without_fts_ctx()
  hits <- search_speeches_by_terms("government", include_text = FALSE)
  expect_gt(nrow(hits), 0)

  expect_message(
    out <- add_party(hits) |> add_government_status(),
    "Skipping"
  )
  expect_identical(nrow(out), nrow(hits))
  expect_identical(out$action_id, hits$action_id)
  expect_true(all(c("party_abbrev_at_time", "government_status_at_time") %in% names(out)))
})
