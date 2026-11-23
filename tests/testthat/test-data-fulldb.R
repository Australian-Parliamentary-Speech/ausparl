# Full-database checks: skipped unless AUSPARL_DB points at hansard.duckdb; never on CRAN.

test_that("T-4.21 S3: no sample day is its chamber's first sitting day of the year", {
  full <- skip_if_no_full_db()
  sample_con <- local_sample_con()
  ids <- DBI::dbGetQuery(sample_con, "SELECT sitting_id FROM sittings")$sitting_id

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = full, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  first <- DBI::dbGetQuery(con, "
    SELECT sitting_id FROM (
      SELECT sitting_id, row_number() OVER (PARTITION BY chamber, year(date) ORDER BY date) AS k
      FROM sittings
    ) WHERE k = 1")$sitting_id
  expect_length(intersect(ids, first), 0)
})

test_that("T-4.15 C9: db_connect() opens the full database at schema 7 and reports it", {
  full <- skip_if_no_full_db()
  withr::defer(db_disconnect())
  elapsed <- system.time(db_connect(path = full))[["elapsed"]]
  message(sprintf("db_connect() on the full DB: %.2f s", elapsed))

  info <- db_info()
  expect_match(info$schema_version, "^7\\.")
  expect_equal(info$n_actions, 6510255)
  expect_identical(info$path, normalizePath(full))
  sittings <- db_tbl("sittings") |> dplyr::count() |> dplyr::collect()
  expect_gt(sittings$n, 15000)
})
