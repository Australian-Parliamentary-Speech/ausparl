# Full-database checks for module outputs: skipped unless AUSPARL_DB points at hansard.duckdb;
# never on CRAN. The database is opened read-only through db_connect().

test_that("T-4.15 PC4: result_provenance() on 1996 speeches gives one row per distinct sitting", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  db_connect(path = full)

  speeches <- get_speeches(from = 1996, to = 1996, include_text = FALSE)
  ids <- unique(speeches$sitting_id)
  expect_gt(length(ids), 0)
  t_prov <- system.time(prov <- result_provenance(speeches))[["elapsed"]]
  expect_identical(nrow(prov), length(ids))
  expect_setequal(prov$sitting_id, ids)
  message(sprintf(
    "1996: %d speeches, %d sittings, provenance in %.2f s", nrow(speeches), length(ids), t_prov
  ))
})
