q <- function(con, sql) DBI::dbGetQuery(con, sql)

test_that("T-4.21 S1: sample opens read-only at schema 7.0.0", {
  con <- local_sample_con()
  expect_identical(q(con, "SELECT schema_version FROM schema_version")$schema_version, "7.0.0")
  expect_error(DBI::dbExecute(con, "CREATE TABLE scratch (x INT)"))
})

test_that("T-4.21 S2: 8 days, 4 per chamber, each chamber x era once", {
  con <- local_sample_con()
  days <- q(con, "SELECT s.chamber, p.schema_generation AS era
                  FROM sittings s JOIN provenance p USING (sitting_id)")
  expect_identical(nrow(days), 8L)
  expect_identical(as.vector(table(days$chamber)[c("house", "senate")]), c(4L, 4L))
  expect_identical(nrow(unique(days)), 8L)
  expect_setequal(unique(days$era), c("v2.0", "v2.1", "v2.2", "legacy-html"))
})

test_that("T-4.21 S3: every sample day has question and answer turns", {
  con <- local_sample_con()
  per_day <- q(con, "SELECT sitting_id,
                       count(*) FILTER (WHERE is_question) AS n_q,
                       count(*) FILTER (WHERE is_answer) AS n_a
                     FROM actions GROUP BY sitting_id")
  expect_identical(nrow(per_day), 8L)
  expect_true(all(per_day$n_q > 0 & per_day$n_a > 0))
})

test_that("T-4.21 S4: all 47 tables and views are present", {
  con <- local_sample_con()
  objs <- q(con, "SELECT schema_name, 'table' AS kind FROM duckdb_tables()
                  UNION ALL
                  SELECT schema_name, 'view' FROM duckdb_views() WHERE NOT internal")
  expect_identical(sum(objs$schema_name == "main" & objs$kind == "table"), 24L)
  expect_identical(sum(objs$schema_name == "main" & objs$kind == "view"), 17L)
  expect_identical(sum(objs$schema_name == "fts_main_actions"), 6L)
})

test_that("T-4.21 S5: known row counts", {
  con <- local_sample_con()
  n <- function(tbl) q(con, paste("SELECT count(*) AS n FROM", tbl))$n
  expect_equal(n("sittings"), 8)
  expect_equal(n("actions"), 1488)
  expect_equal(n("members"), 303)
  # Trimmed reference tables hold only PHIDs that appear in the sample's turns, as speaker or
  # as presiding officer; every presiding officer named on a turn is kept.
  keep <- "(SELECT PHID FROM actions WHERE PHID IS NOT NULL
            UNION SELECT presiding_phid FROM actions WHERE presiding_phid IS NOT NULL)"
  expect_equal(n(paste("party_service WHERE PHID NOT IN", keep)), 0)
  expect_equal(n(paste("presiding_officers WHERE PHID NOT IN", keep)), 0)
  expect_equal(n("actions WHERE presiding_phid NOT IN (SELECT PHID FROM members)"), 0)
})

test_that("T-4.21 S6: file is <= 6 MB on disk and <= 2 MB gzip-compressed", {
  path <- sample_db_path()
  expect_lte(file.size(path), 6 * 2^20)
  raw <- readBin(path, "raw", file.size(path))
  expect_lte(length(memCompress(raw, "gzip")), 2 * 2^20)
})

test_that("T-4.21 S7: has a targeted interjection, a sentinel turn, a party change, a quote", {
  con <- local_sample_con()
  expect_gt(q(con, "SELECT count(*) AS n FROM v_interjection_target it
                    JOIN actions a ON a.action_id = it.interjection_action_id")$n, 0)
  expect_gt(q(con, "SELECT count(*) AS n FROM actions WHERE resolution = 'sentinel'")$n, 0)
  changers <- q(con, "SELECT a.PHID FROM actions a JOIN v_party_at_time p USING (action_id)
                      WHERE p.party_at_time IS NOT NULL
                      GROUP BY a.PHID HAVING count(DISTINCT p.party_at_time) > 1")
  expect_gt(nrow(changers), 0)
  expect_gt(q(con, "SELECT count(*) AS n FROM actions
                    WHERE action_type = 'quote' AND resolution IS NULL")$n, 0)
})
