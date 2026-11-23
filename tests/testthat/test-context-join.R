# Tests for the context joins (J1-J8): the seven add_*() helpers.
# Sample DB only; no network.

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

by_action <- function(d) {
  d <- as.data.frame(d)
  d <- d[order(d$action_id, method = "radix"), , drop = FALSE]
  rownames(d) <- NULL
  d
}

registered <- function() grep("^ausparl_join_", DBI::dbListTables(db_con()), value = TRUE)

# Each helper, the columns it adds, and the same join written by hand over every action
# (`a.action_id, a.sitting_id` first, as in the test input).
helpers <- list(
  member = list(
    fn = add_member, cols = c("DisplayName", "Gender", "State"),
    sql = "SELECT a.action_id, a.sitting_id, m.DisplayName, m.Gender, m.State
           FROM actions a LEFT JOIN members m ON m.PHID = a.PHID"
  ),
  party = list(
    fn = add_party, cols = c("party_id_at_time", "party_at_time", "party_abbrev_at_time"),
    sql = "SELECT a.action_id, a.sitting_id, pa.party_id AS party_id_at_time, p.party_at_time,
                  pa.Abbrev AS party_abbrev_at_time
           FROM actions a
           LEFT JOIN v_party_at_time p ON p.action_id = a.action_id
           LEFT JOIN parties pa ON pa.Name = p.party_at_time"
  ),
  electorate = list(
    fn = add_electorate, cols = "electorate_at_time",
    sql = "SELECT a.action_id, a.sitting_id, v.electorate_at_time
           FROM actions a LEFT JOIN v_electorate_at_time v ON v.action_id = a.action_id"
  ),
  age = list(
    fn = add_age, cols = "age_at_time",
    sql = "SELECT a.action_id, a.sitting_id, v.age_at_time
           FROM actions a LEFT JOIN v_age_at_time v ON v.action_id = a.action_id"
  ),
  role = list(
    fn = add_role, cols = "role_at_time",
    sql = "SELECT a.action_id, a.sitting_id, v.role_at_time
           FROM actions a LEFT JOIN v_role_at_time v ON v.action_id = a.action_id"
  ),
  government_status = list(
    fn = add_government_status, cols = "government_status_at_time",
    sql = "SELECT a.action_id, a.sitting_id, v.government_status_at_time
           FROM actions a
           LEFT JOIN v_government_status_at_time v ON v.action_id = a.action_id"
  ),
  debate = list(
    fn = add_debate, cols = c("debate_title", "subdebate_title", "seq"),
    sql = "SELECT a.action_id, a.sitting_id, v.debate_title, v.subdebate_title, v.seq
           FROM actions a LEFT JOIN v_sitting_timeline v ON v.action_id = a.action_id"
  )
)

lazy_actions <- function() dplyr::select(db_tbl("actions"), "action_id", "sitting_id")

local_actions <- function() {
  x <- dplyr::collect(lazy_actions())
  x[order(x$action_id, method = "radix"), ]
}

# ---- J1 equals direct SQL -----------------------------------------------------------------------

test_that("T-4.5 J1: each helper equals direct SQL for tibble input, in the input's row order", {
  local_sample_ap()
  x <- local_actions()
  for (name in names(helpers)) {
    h <- helpers[[name]]
    got <- h$fn(x)
    direct <- DBI::dbGetQuery(db_con(), h$sql)
    expect_identical(names(got), c("action_id", "sitting_id", h$cols), label = name)
    expect_identical(got$action_id, x$action_id, label = name)
    expect_equal(by_action(got), by_action(direct), label = name)
  }
  expect_length(registered(), 0)
})

test_that("T-4.5 J1: each helper equals direct SQL for lazy input", {
  local_sample_ap()
  for (name in names(helpers)) {
    h <- helpers[[name]]
    got <- dplyr::collect(h$fn(lazy_actions()))
    direct <- DBI::dbGetQuery(db_con(), h$sql)
    expect_identical(names(got), c("action_id", "sitting_id", h$cols), label = name)
    expect_equal(by_action(got), by_action(direct), label = name)
  }
})

test_that("T-4.5 J1: add_member() adds the requested members columns", {
  local_sample_ap()
  x <- local_actions()
  got <- add_member(x, cols = c("DateOfBirth", "PHID"))
  direct <- DBI::dbGetQuery(db_con(), "
    SELECT a.action_id, a.sitting_id, m.DateOfBirth, a.PHID
    FROM actions a LEFT JOIN members m ON m.PHID = a.PHID")
  expect_equal(by_action(got), by_action(direct))
})

# ---- J2 party change ----------------------------------------------------------------------------

test_that("T-4.5 J2: K8L resolves to different parties on its two sample days", {
  local_sample_ap()
  turns <- dplyr::filter(db_tbl("actions"), .data$PHID == "K8L") |>
    dplyr::select("action_id", "sitting_id") |>
    dplyr::collect()
  k8l <- add_party(turns)
  k8l$day <- substr(k8l$sitting_id, nchar(k8l$sitting_id) - 9, nchar(k8l$sitting_id))
  by_day <- unique(k8l[c("day", "party_at_time", "party_abbrev_at_time")])
  expect_identical(nrow(by_day), 2L)
  expect_identical(length(unique(by_day$day)), 2L)
  expect_identical(length(unique(by_day$party_at_time)), 2L)
  expect_false(anyNA(by_day$party_at_time))
})

# ---- J3 row-preserving --------------------------------------------------------------------------

test_that("T-4.5 J3: row count unchanged, action_id unique, rows without PHID kept with NA", {
  local_sample_ap()
  x <- local_actions()
  no_phid <- DBI::dbGetQuery(db_con(), "SELECT action_id FROM actions WHERE PHID IS NULL")
  expect_gt(nrow(no_phid), 0)
  for (name in names(helpers)) {
    h <- helpers[[name]]
    lazy <- h$fn(lazy_actions())
    expect_unique_key(lazy, "action_id")
    expect_identical(dplyr::pull(dplyr::collect(dplyr::count(lazy))), as.numeric(nrow(x)))
    got <- h$fn(x)
    expect_identical(nrow(got), nrow(x))
    expect_unique_key(got, "action_id")
    member_cols <- setdiff(h$cols, c("debate_title", "subdebate_title", "seq"))
    if (length(member_cols)) {
      unmatched <- got[got$action_id %in% no_phid$action_id, member_cols]
      expect_true(all(is.na(unlist(unmatched))), label = name)
    }
  }
})

test_that("T-4.5 J3: a shuffled tibble with repeats and unknown ids keeps every row in order", {
  local_sample_ap()
  ids <- c("house_2002-10-15_R2", "no_such_action", "house_2002-10-15_R2", NA)
  x <- data.frame(action_id = ids, k = 4:1, stringsAsFactors = FALSE)
  got <- add_party(x)
  expect_s3_class(got, "tbl_df")
  expect_identical(got$action_id, ids)
  expect_identical(got$k, 4:1)
  expect_identical(got$party_id_at_time[1], got$party_id_at_time[3])
  expect_false(is.na(got$party_id_at_time[1]))
  expect_true(all(is.na(got$party_id_at_time[c(2, 4)])))
  expect_length(registered(), 0)
})

# ---- J4 same type out, chaining -----------------------------------------------------------------

test_that("T-4.1 J4: output type matches input type and helpers chain", {
  local_sample_ap()
  lazy <- get_speeches(collect = FALSE, include_text = FALSE)
  lazy <- suppressMessages(add_role(add_party(lazy)))
  expect_s3_class(lazy, "tbl_lazy")
  expect_true(all(c("party_abbrev_at_time", "role_at_time") %in% colnames(lazy)))

  local <- get_speeches(include_text = FALSE)
  chain <- function(d) {
    d |>
      add_party() |>
      add_role() |>
      add_member() |>
      add_debate()
  }
  chained <- suppressMessages(chain(local))
  expect_s3_class(chained, "tbl_df")
  expect_identical(nrow(chained), nrow(local))
  expect_identical(names(chained)[seq_along(local)], names(local))
  expect_equal(
    by_action(chained),
    by_action(dplyr::collect(suppressMessages(add_debate(add_member(lazy)))))
  )
})

# ---- J5 columns already present -----------------------------------------------------------------

test_that("T-4.5 J5: present columns are skipped with one message; only missing ones added", {
  local_sample_ap()
  speeches <- get_speeches(include_text = FALSE, limit = 20)
  expect_message(got <- add_party(speeches), "party_at_time")
  expect_identical(names(got), c(names(speeches), "party_abbrev_at_time"))
  expect_identical(got$party_at_time, speeches$party_at_time)

  msgs <- testthat::capture_messages(add_party(speeches))
  expect_length(msgs, 1)

  lazy <- get_speeches(include_text = FALSE, collect = FALSE)
  expect_message(lazy_got <- add_party(lazy))
  expect_identical(colnames(lazy_got), c(colnames(lazy), "party_abbrev_at_time"))

  # All present: x is returned unchanged, with the message.
  full <- suppressMessages(add_party(speeches))
  expect_message(same <- add_party(full))
  expect_identical(same, full)
  expect_message(same_lazy <- add_member(lazy_got, cols = "PHID"))
  expect_identical(same_lazy, lazy_got)

  # Nothing present: no message.
  expect_no_message(add_role(speeches))
})

# ---- J6 input errors ----------------------------------------------------------------------------

test_that("T-4.5 J6: bad input raises ausparl_input_error", {
  local_sample_ap()
  err <- "ausparl_input_error"
  expect_error(add_party(tibble::tibble(id = "house_2002-10-15_R2")), class = err)
  expect_error(add_party(tibble::tibble(action_id = 1:3)), class = err)
  expect_error(
    add_party(data.frame(action_id = factor("house_2002-10-15_R2"))),
    class = err
  )
  expect_error(add_party("house_2002-10-15_R2"), class = err)
  expect_error(add_party(list(action_id = "house_2002-10-15_R2")), class = err)
  expect_error(add_party(db_tbl("members")), class = err)
  expect_error(
    add_party(dplyr::mutate(db_tbl("sittings"), action_id = 1L)),
    class = err
  )

  other <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(other, shutdown = TRUE))
  DBI::dbWriteTable(other, "turns", data.frame(action_id = "house_2002-10-15_R2"))
  expect_error(add_party(dplyr::tbl(other, "turns")), class = err)

  x <- tibble::tibble(action_id = "house_2002-10-15_R2")
  expect_error(add_member(x, cols = "Nope"), class = err)
  expect_error(add_member(x, cols = c("DisplayName", "Nope")), class = err)
  expect_error(add_member(x, cols = 1), class = err)
  expect_error(add_member(x, cols = character()), class = err)
  expect_error(add_member(x, cols = NA_character_), class = err)
  expect_length(registered(), 0)
})

test_that("T-4.5 J6: a failing local join raises ausparl_db_error and unregisters the input", {
  local_sample_ap()
  bad <- dplyr::tbl(db_con(), dplyr::sql(
    "SELECT action_id, error('boom')::VARCHAR AS bad FROM actions"
  ))
  expect_error(
    join_local(tibble::tibble(action_id = "house_2002-10-15_R2"), bad, "bad", call = NULL),
    class = "ausparl_db_error"
  )
  expect_length(registered(), 0)
})

# ---- J7 bridge check ----------------------------------------------------------------------------

test_that("T-4.19 J7: non-NA party_at_time implies non-NA party id and abbreviation", {
  local_sample_ap()
  got <- add_party(local_actions())
  named <- got[!is.na(got$party_at_time), ]
  expect_gt(nrow(named), 0)
  expect_false(anyNA(named$party_id_at_time))
  expect_false(anyNA(named$party_abbrev_at_time))
  expect_type(got$party_id_at_time, "integer")
})

# ---- J8 empty input and SQL snapshots -----------------------------------------------------------

test_that("T-4.20 J8: empty input gives a typed zero-row result", {
  local_sample_ap()
  x <- local_actions()
  empty <- x[0, ]
  lazy_empty <- dplyr::filter(lazy_actions(), FALSE)
  for (name in names(helpers)) {
    h <- helpers[[name]]
    typed <- col_classes(h$fn(utils::head(x, 5)))

    got <- h$fn(empty)
    expect_s3_class(got, "tbl_df")
    expect_identical(nrow(got), 0L)
    expect_identical(col_classes(got), typed, label = name)

    got_lazy <- dplyr::collect(h$fn(lazy_empty))
    expect_identical(nrow(got_lazy), 0L)
    expect_identical(col_classes(got_lazy), typed, label = name)
  }
  expect_length(registered(), 0)
})

test_that("T-4.4 J8: rendered SQL for one representative call per helper", {
  local_sample_ap()
  render <- function(lazy) dbplyr::sql_render(lazy)
  turns <- function() dplyr::select(db_tbl("v_speech"), "action_id")
  expect_snapshot(render(add_member(turns())))
  expect_snapshot(render(add_party(turns())))
  expect_snapshot(render(add_electorate(turns())))
  expect_snapshot(render(add_age(turns())))
  expect_snapshot(render(add_role(turns())))
  expect_snapshot(render(add_government_status(turns())))
  expect_snapshot(render(add_debate(turns())))
})
