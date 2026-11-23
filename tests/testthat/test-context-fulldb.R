# Full-database checks for module context: skipped unless AUSPARL_DB points at hansard.duckdb;
# never on CRAN. The database is opened read-only through db_connect().

test_that("T-4.5 J9: 1996 speeches keep their row count through all 7 helpers", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  helpers <- list(
    add_member = add_member, add_party = add_party,
    add_electorate = add_electorate, add_age = add_age, add_role = add_role,
    add_government_status = add_government_status, add_debate = add_debate
  )
  lazy <- get_speeches(from = 1996, to = 1996, include_text = FALSE, collect = FALSE)
  local <- get_speeches(from = 1996, to = 1996, include_text = FALSE)
  n <- nrow(local)
  expect_gt(n, 0)
  message(sprintf("1996 speeches: %d rows", n))

  for (name in names(helpers)) {
    fn <- helpers[[name]]
    t_local <- system.time(got <- suppressMessages(fn(local)))[["elapsed"]]
    expect_identical(nrow(got), n, label = name)
    expect_identical(got$action_id, local$action_id, label = name)

    t_lazy <- system.time({
      n_lazy <- dplyr::pull(dplyr::collect(dplyr::count(suppressMessages(fn(lazy)))))
    })[["elapsed"]]
    expect_equal(n_lazy, n, label = name)
    message(sprintf("%s: tibble %.2f s, lazy count %.2f s", name, t_local, t_lazy))
  }

  chain <- function(d) {
    d |>
      add_member() |>
      add_party() |>
      add_electorate() |>
      add_age() |>
      add_role() |>
      add_government_status() |>
      add_debate()
  }
  chained <- suppressMessages(chain(local))
  expect_identical(nrow(chained), n)
  named <- chained[!is.na(chained$party_at_time), ]
  expect_false(anyNA(named$party_id_at_time))
  expect_false(anyNA(named$party_abbrev_at_time))
})

test_that("T-4.4 A9: activity functions for parliament 38 and full-corpus party activity, timed", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  calls <- list(
    member_activity = function() member_activity(parliament_id = 38),
    party_activity = function() party_activity(parliament_id = 38),
    parliament_summary = function() parliament_summary(parliament_id = 38)
  )
  out <- list()
  for (name in names(calls)) {
    secs <- system.time(out[[name]] <- calls[[name]]())[["elapsed"]]
    expect_gt(nrow(out[[name]]), 0)
    expect_true(all(out[[name]]$parliament_id == 38), label = name)
    message(sprintf("%s(parliament_id = 38): %d rows, %.2f s", name, nrow(out[[name]]), secs))
  }
  expect_identical(nrow(out$parliament_summary), 2L)
  party <- out$party_activity
  expect_false(anyNA(party$party_id_at_time[!is.na(party$party_at_time)]))
  expect_lte(sum(party$n_turns), sum(out$member_activity$n_turns))

  secs <- system.time(corpus <- party_activity())[["elapsed"]]
  expect_gt(nrow(corpus), nrow(party))
  message(sprintf("party_activity() full corpus: %d rows, %.2f s", nrow(corpus), secs))
})

test_that("T-4.15 C6: parliament 38 party counts agree between join and anchor (full DB)", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  elapsed <- system.time({
    from_join <- get_speeches(parliament_id = 38, include_text = FALSE, collect = FALSE) |>
      add_party() |>
      dplyr::filter(!is.na(party_at_time)) |>
      dplyr::count(party_at_time, chamber) |>
      dplyr::collect()
    activity <- party_activity(parliament_id = 38)
  })[["elapsed"]]
  message(sprintf("parliament 38 join vs anchor: %.2f s", elapsed))

  names(from_join) <- c("party_at_time", "chamber", "n")
  got <- merge(from_join, activity[activity$n_speeches > 0, ],
    by = c("party_at_time", "chamber"), all = TRUE
  )
  expect_gt(nrow(got), 0)
  expect_false(anyNA(got$n))
  expect_equal(got$n_speeches, got$n, ignore_attr = TRUE)
})
