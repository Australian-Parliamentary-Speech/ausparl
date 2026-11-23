# Tests for provenance (PC1-PC3): result_provenance() only.
# Sample DB only; no network.

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

# Rows in sitting_id order, as a plain data frame, for comparison with direct SQL.
by_sitting <- function(d) {
  d <- as.data.frame(d)
  d <- d[order(d$sitting_id, method = "radix"), , drop = FALSE]
  rownames(d) <- NULL
  d
}

direct_provenance <- function(ids) {
  con <- db_con()
  if (length(ids) == 0) {
    return(DBI::dbGetQuery(con, "SELECT * FROM provenance WHERE FALSE"))
  }
  DBI::dbGetQuery(
    con, glue::glue_sql("SELECT * FROM provenance WHERE sitting_id IN ({ids*})", .con = con)
  )
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

# ---- PC1 equals direct SQL ----------------------------------------------------------------------

test_that("T-4.1 PC1: an id vector equals direct SQL, each distinct sitting looked up once", {
  local_sample_ap()
  ids <- c("house_1990-09-17", "senate_1983-05-10", "house_1990-09-17")
  got <- result_provenance(ids)
  expect_s3_class(got, "tbl_df")
  expect_identical(
    names(got),
    c(
      "path", "sha256", "schema_generation", "parsed_at", "input_row_count",
      "output_action_count", "sitting_id", "source"
    )
  )
  expect_equal(by_sitting(got), by_sitting(direct_provenance(unique(ids))))
  expect_identical(sort(got$sitting_id), sort(unique(ids)))
})

test_that("T-4.1 PC1: a tibble result equals direct SQL over its distinct sittings", {
  local_sample_ap()
  speeches <- get_speeches(from = 2002, to = 2002, include_text = FALSE)
  ids <- unique(speeches$sitting_id)
  expect_gt(nrow(speeches), length(ids))
  got <- result_provenance(speeches)
  expect_s3_class(got, "tbl_df")
  expect_equal(by_sitting(got), by_sitting(direct_provenance(ids)))
  expect_identical(anyDuplicated(got$sitting_id), 0L)

  # NA sitting ids in a result are ignored.
  with_na <- tibble::tibble(sitting_id = c(ids[1], NA_character_))
  expect_equal(by_sitting(result_provenance(with_na)), by_sitting(direct_provenance(ids[1])))
})

test_that("T-4.1 PC1: a lazy result equals direct SQL and composes with the pipe", {
  local_sample_ap()
  lazy <- get_speeches(include_text = FALSE, collect = FALSE)
  ids <- unique(dplyr::pull(dplyr::collect(lazy), "sitting_id"))
  got <- lazy |> result_provenance()
  expect_equal(by_sitting(got), by_sitting(direct_provenance(ids)))

  still_lazy <- result_provenance(lazy, collect = FALSE)
  expect_s3_class(still_lazy, "tbl_lazy")
  expect_equal(by_sitting(dplyr::collect(still_lazy)), by_sitting(got))
})

test_that("T-4.1 PC1: columns and limit apply", {
  local_sample_ap()
  speeches <- get_speeches(from = 2002, to = 2002, include_text = FALSE)
  got <- result_provenance(speeches, columns = c("sitting_id", "sha256"))
  expect_identical(names(got), c("sitting_id", "sha256"))
  expect_equal(
    by_sitting(got),
    by_sitting(direct_provenance(unique(speeches$sitting_id))[c("sitting_id", "sha256")])
  )
  expect_identical(nrow(result_provenance(speeches, limit = 1)), 1L)
})

# ---- PC2 zero rows and input errors -------------------------------------------------------------

test_that("T-4.20 PC2: unknown sitting ids give a typed zero-row tibble", {
  local_sample_ap()
  typed <- col_classes(direct_provenance(character(0)))
  for (x in list(
    "house_1800-01-01", character(0),
    tibble::tibble(sitting_id = character(0)),
    tibble::tibble(sitting_id = "nope")
  )) {
    got <- result_provenance(x)
    expect_s3_class(got, "tbl_df")
    expect_identical(nrow(got), 0L)
    expect_identical(col_classes(got), typed)
  }
})

test_that("T-4.20 PC2: wrong input or no sitting_id column raises ausparl_input_error", {
  local_sample_ap()
  bad <- list(
    42, list("house_1996-05-02"), NULL, c("house_1996-05-02", NA),
    data.frame(action_id = "x"), data.frame(sitting_id = 1)
  )
  for (x in bad) {
    expect_error(result_provenance(x), class = "ausparl_input_error")
  }
  expect_error(result_provenance(db_tbl("members")), class = "ausparl_input_error")
  numeric_ids <- dplyr::transmute(db_tbl("provenance"), sitting_id = input_row_count)
  expect_error(result_provenance(numeric_ids), class = "ausparl_input_error")

  other <- local_sample_con()
  expect_error(
    result_provenance(dplyr::tbl(other, "sittings")),
    class = "ausparl_input_error"
  )
  expect_error(
    result_provenance("house_1996-05-02", columns = "nope"),
    class = "ausparl_input_error"
  )
  expect_error(result_provenance("house_1996-05-02", collect = NA), class = "ausparl_input_error")
  expect_error(result_provenance("house_1996-05-02", limit = 0), class = "ausparl_input_error")
})

# ---- PC3 SQL snapshot ---------------------------------------------------------------------------

test_that("T-4.4 PC3: result_provenance() SQL", {
  local_sample_ap()
  expect_snapshot(dbplyr::sql_render(
    result_provenance(c("house_1996-05-02", "senate_1996-09-16"), collect = FALSE)
  ))
})
