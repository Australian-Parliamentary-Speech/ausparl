# Tests for the anchored queries (A1-A8, A11): member_profile() and the three activity
# functions. Sample DB only; no network. Expected values are computed independently: turn rows
# are read with hand-written SQL and aggregated in R, with words counted by strsplit().

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

# Every v_speech turn with its sitting, party at the time (id by name match) and R-side word count.
# Quotes (action_type 'quote', passages read out) are not turns and are dropped unless
# `quotes = TRUE`.
raw_turns <- function(quotes = FALSE) {
  d <- DBI::dbGetQuery(db_con(), "
    SELECT v.action_id, v.PHID, v.chamber_venue, s.parliament_id, s.chamber, v.action_type,
           coalesce(v.is_speech, FALSE) AS sp, coalesce(v.is_question, FALSE) AS q,
           coalesce(v.is_answer, FALSE) AS a, coalesce(v.is_interjection, FALSE) AS ij,
           v.content, p.party_at_time, pa.party_id AS party_id_at_time
    FROM v_speech v
    JOIN sittings s ON s.sitting_id = v.sitting_id
    LEFT JOIN v_party_at_time p ON p.action_id = v.action_id
    LEFT JOIN parties pa ON pa.Name = p.party_at_time")
  d$quote <- !is.na(d$action_type) & d$action_type == "quote"
  if (!quotes) d <- d[!d$quote, ]
  d$b1 <- (d$sp | d$q | d$a) & !d$ij
  tokens <- strsplit(trimws(ifelse(is.na(d$content), "", d$content)), "\\s+")
  d$words <- ifelse(d$b1, vapply(tokens, function(t) sum(nzchar(t)), numeric(1)), 0)
  d
}

# Interjections received, by target PHID x parliament x chamber, in SQL.
raw_received <- function() {
  DBI::dbGetQuery(db_con(), "
    SELECT a.PHID, s.parliament_id, s.chamber, count(*) AS n_interjections_received
    FROM v_interjection_target t
    JOIN actions a ON a.action_id = t.target_action_id
    JOIN sittings s ON s.sitting_id = a.sitting_id
    WHERE a.PHID IS NOT NULL
    GROUP BY ALL")
}

key_of <- function(d, keys) do.call(paste, c(unname(as.list(d[keys])), sep = "|"))

sorted <- function(d, keys) {
  d <- as.data.frame(d)
  d <- d[order(key_of(d, keys), method = "radix"), , drop = FALSE]
  rownames(d) <- NULL
  d
}

# Base-R aggregation of `d` by `keys`: one row per key, each summary a function of the group.
group_summary <- function(d, keys, fns) {
  groups <- split(d, key_of(d, keys), drop = TRUE)
  rows <- lapply(groups, function(g) {
    out <- g[1, keys, drop = FALSE]
    for (name in names(fns)) out[[name]] <- as.numeric(fns[[name]](g))
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

expected_member <- function() {
  t <- raw_turns()
  t <- t[!is.na(t$PHID), ]
  keys <- c("PHID", "parliament_id", "chamber")
  made <- group_summary(t, keys, list(
    n_turns = nrow, n_speeches = function(g) sum(g$b1),
    n_questions = function(g) sum(g$q & !g$ij), n_answers = function(g) sum(g$a & !g$ij),
    n_interjections_made = function(g) sum(g$ij), n_words = function(g) sum(g$words)
  ))
  out <- merge(made, raw_received(), by = keys, all = TRUE)
  metrics <- c(
    "n_turns", "n_speeches", "n_questions", "n_answers", "n_interjections_made",
    "n_interjections_received", "n_words"
  )
  for (m in metrics) out[[m]] <- dplyr::coalesce(as.numeric(out[[m]]), 0)
  out[c(keys, metrics)]
}

expected_party <- function() {
  t <- raw_turns()
  t <- t[!is.na(t$party_at_time), ]
  group_summary(
    t, c("party_id_at_time", "party_at_time", "parliament_id", "chamber"),
    list(
      n_members = function(g) length(unique(g$PHID)), n_turns = nrow,
      n_speeches = function(g) sum(g$b1), n_interjections = function(g) sum(g$ij),
      n_words = function(g) sum(g$words)
    )
  )
}

# ---- A1 member profile --------------------------------------------------------------------------

test_that("T-4.1 A1: member_profile() returns the nine getter tibbles", {
  local_sample_ap()
  got <- member_profile("ZD4")
  getters <- list(
    members = get_members, parl_service = get_parl_service,
    party_service = get_party_service, ministry_records = get_ministry_records,
    shadow_ministry_records = get_shadow_ministry_records,
    committee_members = get_committee_members, occupations = get_occupations,
    qualifications = get_qualifications, schools = get_schools
  )
  expect_type(got, "list")
  expect_identical(names(got), names(getters))
  for (name in names(getters)) {
    expect_s3_class(got[[name]], "tbl_df")
    expect_identical(got[[name]], getters[[name]](PHID = "ZD4"), label = name)
  }
  expect_identical(nrow(got$members), 1L)
})

test_that("T-4.1 A1: member_profile() rejects unknown and several PHIDs", {
  local_sample_ap()
  expect_error(member_profile("NOPE_NOT_A_PHID"), class = "ausparl_not_found")
  expect_error(member_profile(c("ZD4", "009MD")), class = "ausparl_input_error")
  expect_error(member_profile(NA_character_), class = "ausparl_input_error")
  expect_error(member_profile(""), class = "ausparl_input_error")
  expect_error(member_profile(4), class = "ausparl_input_error")
})

# ---- A2 member activity -------------------------------------------------------------------------

test_that("T-4.2 A2: member_activity() metrics equal direct SQL, one row per key", {
  local_sample_ap()
  got <- member_activity()
  keys <- c("PHID", "parliament_id", "chamber")
  expect_s3_class(got, "tbl_df")
  expect_identical(names(got), names(expected_member()))
  expect_false(anyDuplicated(key_of(got, keys)) > 0)
  expect_equal(sorted(got, keys), sorted(expected_member(), keys))
  expect_gt(sum(got$n_interjections_received), 0)
  expect_gt(sum(got$n_words), 0)
  # collected rows are ordered by the keys
  expect_identical(key_of(got, keys), key_of(sorted(got, keys), keys))
})

test_that("T-4.1 A2: collect = FALSE returns a lazy table that composes with the pipe", {
  local_sample_ap()
  lazy <- member_activity(collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  n <- lazy |>
    dplyr::filter(.data$n_speeches > 0) |>
    dplyr::count() |>
    dplyr::pull()
  expect_equal(n, sum(member_activity()$n_speeches > 0))
  expect_s3_class(party_activity(collect = FALSE), "tbl_lazy")
  expect_s3_class(parliament_summary(collect = FALSE), "tbl_lazy")
})

# ---- A3 n_speeches against get_speeches() -------------------------------------------------------

test_that("T-4.17 A3: n_speeches equals get_speeches() rows (B1) per member and parliament", {
  local_sample_ap()
  act <- member_activity()
  act <- act[act$n_speeches > 0, ]
  act <- act[order(-act$n_speeches, act$PHID, method = "radix"), ]
  pairs <- unique(rbind(
    data.frame(PHID = "ZD4", parliament_id = 38L),
    as.data.frame(utils::head(act, 6))[c("PHID", "parliament_id")]
  ))
  for (i in seq_len(nrow(pairs))) {
    phid <- pairs$PHID[i]
    pid <- pairs$parliament_id[i]
    speeches <- get_speeches(member = phid, parliament_id = pid, include_text = FALSE)
    expect_false(any(speeches$is_interjection))
    want <- sum(act$n_speeches[act$PHID == phid & act$parliament_id == pid])
    expect_equal(nrow(speeches), want, label = paste(phid, pid))
  }
})

# ---- A4 party activity --------------------------------------------------------------------------

test_that("T-4.19 A4: party_activity() equals direct SQL; the id bridge is complete", {
  local_sample_ap()
  got <- party_activity()
  keys <- c("party_id_at_time", "party_at_time", "parliament_id", "chamber")
  want <- expected_party()
  expect_identical(
    names(got),
    c(keys, "n_members", "n_turns", "n_speeches", "n_interjections", "n_words")
  )
  expect_false(anyDuplicated(key_of(got, keys)) > 0)
  expect_equal(sorted(got, keys), sorted(want[names(got)], keys))
  expect_false(anyNA(got$party_at_time))
  expect_false(anyNA(got$party_id_at_time[!is.na(got$party_at_time)]))
})

test_that("T-4.2 A4: n_members counts speaking members per party, parliament and chamber", {
  local_sample_ap()
  got <- party_activity(party_id = 1, parliament_id = 40, chamber = "house")
  expect_identical(nrow(got), 1L)
  speakers <- DBI::dbGetQuery(db_con(), "
    SELECT count(DISTINCT v.PHID) AS n
    FROM v_speech v JOIN sittings s ON s.sitting_id = v.sitting_id
    JOIN v_party_at_time p ON p.action_id = v.action_id
    JOIN parties pa ON pa.Name = p.party_at_time
    WHERE pa.party_id = 1 AND s.parliament_id = 40 AND s.chamber = 'house'
      AND v.action_type IS DISTINCT FROM 'quote'")$n
  expect_equal(got$n_members, as.numeric(speakers))
  # Speaking members, not serving members: fewer than the House's serving members.
  serving <- parliament_summary(parliament_id = 40, chamber = "house")$n_members
  expect_lt(got$n_members, serving)
})

# ---- A5 parliament summary ----------------------------------------------------------------------

test_that("T-4.2 A5: parliament_summary() equals direct SQL", {
  local_sample_ap()
  got <- parliament_summary()
  keys <- c("parliament_id", "chamber")
  expect_identical(
    names(got),
    c(keys, "n_sitting_days", "n_members", "n_turns", "mean_words_per_speech")
  )
  want <- DBI::dbGetQuery(db_con(), "
    WITH pairs AS (
      SELECT parliament_id, chamber, count(DISTINCT sitting_id) AS n_sitting_days
      FROM sittings GROUP BY ALL
    ),
    periods AS (
      SELECT parliament_id, coalesce(DateOpening, DateElection) AS p_start,
             coalesce(ParliamentEnd, DateDissolution) AS p_end
      FROM parliaments
    ),
    serving AS (
      SELECT pr.parliament_id, pr.chamber, count(DISTINCT ps.PHID) AS n_members
      FROM pairs pr JOIN periods pe USING (parliament_id)
      JOIN parl_service ps
        ON ps.MemberOrSenator = CASE pr.chamber WHEN 'house' THEN 'Member' ELSE 'Senator' END
       AND (pe.p_end IS NULL OR ps.DateStart <= pe.p_end)
       AND (ps.DateEnd IS NULL OR ps.DateEnd >= pe.p_start)
      GROUP BY ALL
    ),
    turns AS (
      SELECT s.parliament_id, s.chamber, count(*) AS n_turns
      FROM v_speech v JOIN sittings s ON s.sitting_id = v.sitting_id
      WHERE v.action_type IS DISTINCT FROM 'quote'
      GROUP BY ALL
    )
    SELECT pairs.parliament_id, pairs.chamber, n_sitting_days, n_members, n_turns
    FROM pairs LEFT JOIN serving USING (parliament_id, chamber)
    LEFT JOIN turns USING (parliament_id, chamber)")
  t <- raw_turns()
  words <- stats::aggregate(cbind(words, b1) ~ parliament_id + chamber, data = t, FUN = sum)
  want <- merge(want, words, by = keys, all.x = TRUE)
  want$mean_words_per_speech <- ifelse(want$b1 > 0, want$words / want$b1, NA_real_)

  got <- sorted(got, keys)
  want <- sorted(want, keys)
  expect_identical(nrow(got), nrow(want))
  expect_equal(got$n_sitting_days, as.numeric(want$n_sitting_days))
  expect_equal(got$n_members, as.numeric(want$n_members))
  expect_equal(got$n_turns, as.numeric(want$n_turns))
  expect_equal(got$mean_words_per_speech, want$mean_words_per_speech)
  # n_turns includes presiding and unmatched turns, but not quotes
  expect_equal(sum(got$n_turns), nrow(t))
  expect_gt(sum(got$n_turns), sum(member_activity()$n_turns))
})

# ---- A6 cross-function consistency --------------------------------------------------------------

test_that("T-4.2 A6: member n_turns sum to party n_turns for turns that have a party", {
  local_sample_ap()
  t <- raw_turns()
  no_party <- sum(!is.na(t$PHID) & is.na(t$party_at_time))
  member <- member_activity()
  party <- party_activity()
  expect_equal(sum(member$n_turns) - no_party, sum(party$n_turns))
  for (pid in unique(party$parliament_id)) {
    expect_equal(
      sum(member$n_turns[member$parliament_id == pid]) -
        sum(!is.na(t$PHID) & is.na(t$party_at_time) & t$parliament_id == pid),
      sum(party$n_turns[party$parliament_id == pid]),
      label = paste("parliament", pid)
    )
  }
})

# ---- A11 quotes are not turns -------------------------------------------------------------------

test_that("T-4.2 A11: quotes are not counted as turns by any activity function", {
  local_sample_ap()
  all <- raw_turns(quotes = TRUE)
  q <- all[all$quote, ]
  # The sample's quotes: 12 resolved with a PHID (all with a party at the time), 8 without.
  expect_identical(nrow(q), 20L)
  expect_identical(sum(!is.na(q$PHID)), 12L)
  expect_identical(sum(!is.na(q$party_at_time)), 12L)
  # No quote is flagged as a speech, question, answer or interjection.
  expect_false(any(q$sp | q$q | q$a | q$ij))

  with_phid <- all[!is.na(all$PHID), ]
  expect_equal(sum(member_activity()$n_turns), sum(!with_phid$quote))
  expect_equal(sum(member_activity()$n_turns), nrow(with_phid) - 12)
  with_party <- all[!is.na(all$party_at_time), ]
  expect_equal(sum(party_activity()$n_turns), nrow(with_party) - 12)

  # Per member x parliament x chamber, n_turns is the member's turns minus their quotes.
  mkeys <- c("PHID", "parliament_id", "chamber")
  member <- member_activity()
  quoted <- group_summary(q[!is.na(q$PHID), ], mkeys, list(n_quotes = nrow))
  everything <- group_summary(with_phid, mkeys, list(n_all = nrow))
  joined <- merge(merge(everything, quoted, by = mkeys, all.x = TRUE), member, by = mkeys)
  joined$n_quotes <- dplyr::coalesce(joined$n_quotes, 0)
  expect_gt(sum(joined$n_quotes), 0)
  expect_equal(joined$n_turns, joined$n_all - joined$n_quotes)

  # parliament_summary() excludes all 20 quotes, with or without a PHID.
  skeys <- c("parliament_id", "chamber")
  per_pair <- DBI::dbGetQuery(db_con(), "
    SELECT s.parliament_id, s.chamber,
           count(*) - count(*) FILTER (WHERE v.action_type = 'quote') AS n_turns
    FROM v_speech v JOIN sittings s ON s.sitting_id = v.sitting_id
    GROUP BY ALL")
  summary <- parliament_summary()
  joined <- merge(summary[c(skeys, "n_turns")], per_pair, by = skeys, all.x = TRUE)
  joined$n_turns.y <- dplyr::coalesce(as.numeric(joined$n_turns.y), 0)
  expect_equal(joined$n_turns.x, joined$n_turns.y)
  expect_equal(sum(summary$n_turns), nrow(all) - 20)
})

# ---- A7 filters and argument errors -------------------------------------------------------------

test_that("T-4.2 A7: each filter keeps exactly the matching rows", {
  local_sample_ap()
  all_member <- member_activity()
  all_party <- party_activity()
  all_summary <- parliament_summary()
  mkeys <- c("PHID", "parliament_id", "chamber")
  pkeys <- c("party_id_at_time", "party_at_time", "parliament_id", "chamber")
  skeys <- c("parliament_id", "chamber")

  expect_equal(
    sorted(member_activity(PHID = c("ZD4", "009MD")), mkeys),
    sorted(all_member[all_member$PHID %in% c("ZD4", "009MD"), ], mkeys)
  )
  expect_equal(
    sorted(member_activity(parliament_id = 38), mkeys),
    sorted(all_member[all_member$parliament_id == 38, ], mkeys)
  )
  expect_equal(
    sorted(member_activity(parliament_id = in_range(38, 40)), mkeys),
    sorted(all_member[all_member$parliament_id %in% 38:40, ], mkeys)
  )
  expect_equal(
    sorted(member_activity(chamber = "Senate"), mkeys),
    sorted(all_member[all_member$chamber == "senate", ], mkeys)
  )
  expect_equal(
    sorted(party_activity(party_id = c(1, 4)), pkeys),
    sorted(all_party[all_party$party_id_at_time %in% c(1, 4), ], pkeys)
  )
  expect_equal(
    sorted(party_activity(parliament_id = 38, chamber = "house"), pkeys),
    sorted(all_party[all_party$parliament_id == 38 & all_party$chamber == "house", ], pkeys)
  )
  expect_equal(
    sorted(parliament_summary(parliament_id = 38), skeys),
    sorted(all_summary[all_summary$parliament_id == 38, ], skeys)
  )

  # chamber_venue filters turns
  t <- raw_turns()
  venues <- sort(unique(t$chamber_venue))
  v <- venues[1]
  by_venue <- member_activity(chamber_venue = v)
  expect_equal(sum(by_venue$n_turns), sum(!is.na(t$PHID) & t$chamber_venue == v))
  expect_equal(
    sum(party_activity(chamber_venue = v)$n_turns),
    sum(!is.na(t$party_at_time) & t$chamber_venue == v)
  )
  summary_venue <- parliament_summary(chamber_venue = v)
  expect_equal(sum(summary_venue$n_turns), sum(t$chamber_venue == v))
  expect_identical(nrow(summary_venue), nrow(all_summary))

  # columns and limit
  cols <- member_activity(columns = c("PHID", "n_words"))
  expect_identical(names(cols), c("PHID", "n_words"))
  expect_identical(nrow(party_activity(limit = 3)), 3L)
})

test_that("T-4.2 A7: bad arguments raise ausparl_input_error; unknown PHIDs not_found", {
  local_sample_ap()
  fns <- list(member_activity, party_activity, parliament_summary)
  for (fn in fns) {
    expect_error(fn(parliament_id = "38"), class = "ausparl_input_error")
    expect_error(fn(parliament_id = NA), class = "ausparl_input_error")
    expect_error(fn(parliament_id = 38.5), class = "ausparl_input_error")
    expect_error(fn(parliament_id = in_range("1996-01-01")), class = "ausparl_input_error")
    expect_error(fn(parliament_id = matches_pattern("3%")), class = "ausparl_input_error")
    expect_error(fn(chamber = "lower"), class = "ausparl_input_error")
    expect_error(fn(chamber_venue = "main"), class = "ausparl_input_error")
    expect_error(fn(columns = "nope"), class = "ausparl_input_error")
    expect_error(fn(collect = "yes"), class = "ausparl_input_error")
    expect_error(fn(limit = 0), class = "ausparl_input_error")
  }
  expect_error(member_activity(PHID = 4), class = "ausparl_input_error")
  expect_error(member_activity(PHID = NA_character_), class = "ausparl_input_error")
  expect_error(member_activity(PHID = "NOPE_NOT_A_PHID"), class = "ausparl_not_found")
  expect_error(party_activity(party_id = "ALP"), class = "ausparl_input_error")
  expect_error(party_activity(party_id = c(1, NA)), class = "ausparl_input_error")
  expect_error(member_activity(party_id = 1), "unused argument")
})

test_that("T-4.18 A7: the size guard applies to the activity results", {
  local_sample_ap()
  withr::local_options(ausparl.max_rows = 2)
  expect_error(member_activity(), class = "ausparl_input_error")
  expect_error(party_activity(), class = "ausparl_input_error")
  expect_error(parliament_summary(), class = "ausparl_input_error")
  expect_identical(nrow(parliament_summary(limit = 2)), 2L)
})

# ---- A8 typed zero rows and SQL snapshots -------------------------------------------------------

test_that("T-4.20 A8: no match gives a typed zero-row tibble", {
  local_sample_ap()
  calls <- list(
    member = function(...) member_activity(...),
    party = function(...) party_activity(...),
    summary = function(...) parliament_summary(...)
  )
  for (name in names(calls)) {
    typed <- col_classes(calls[[name]]())
    got <- calls[[name]](parliament_id = 999)
    expect_s3_class(got, "tbl_df")
    expect_identical(nrow(got), 0L, label = name)
    expect_identical(col_classes(got), typed, label = name)
  }
  none <- member_activity(PHID = "ZD4", parliament_id = 1)
  expect_identical(nrow(none), 0L)
  expect_identical(nrow(party_activity(party_id = 99999)), 0L)
})

test_that("T-4.4 A8: rendered SQL for one representative call per activity function", {
  local_sample_ap()
  render <- function(lazy) dbplyr::sql_render(lazy)
  expect_snapshot(render(member_activity(PHID = "ZD4", parliament_id = 38, collect = FALSE)))
  expect_snapshot(render(party_activity(party_id = 1, chamber = "house", collect = FALSE)))
  expect_snapshot(render(parliament_summary(parliament_id = 38, collect = FALSE)))
})
