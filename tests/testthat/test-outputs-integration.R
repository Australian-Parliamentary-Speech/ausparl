# Module integration: outputs. Query/context results flow into the corpus and provenance
# hand-offs on the bundled sample DB (no mocks, no full DB).

local_outputs_sample <- function(env = parent.frame()) {
  withr::local_envvar(AUSPARL_DB = NA, .local_envir = env)
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
  db_con()
}

skip_without_fts_out <- function() {
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

search_chain <- function(collect = TRUE) {
  search_speeches_by_terms("government", collect = collect) |>
    add_party() |>
    add_role()
}

test_that("T-4.7 O1: search -> join -> corpus keeps every row and docvar", {
  local_outputs_sample()
  skip_without_fts_out()
  testthat::skip_if_not_installed("quanteda")

  source <- suppressMessages(search_chain())
  expect_gt(nrow(source), 0)
  corpus <- as_corpus(source)

  expect_identical(quanteda::ndoc(corpus), nrow(source))
  expect_identical(quanteda::docnames(corpus), source$action_id)
  expect_identical(as.character(corpus), stats::setNames(source$content, source$action_id))

  docvars <- quanteda::docvars(corpus)
  expected <- as.data.frame(source[setdiff(names(source), c("action_id", "content"))])
  expect_identical(names(docvars), names(expected))
  for (col in names(expected)) {
    expect_identical(docvars[[col]], expected[[col]], info = col)
  }
})

test_that("T-4.1 O2: a corpus traces back to its source files", {
  local_outputs_sample()
  skip_without_fts_out()
  testthat::skip_if_not_installed("quanteda")

  corpus <- as_corpus(suppressMessages(search_chain()))
  docvars <- quanteda::docvars(corpus)
  prov <- result_provenance(docvars)

  expect_setequal(prov$sitting_id, unique(docvars$sitting_id))
  expect_identical(nrow(prov), length(unique(docvars$sitting_id)))
  expect_false(anyNA(prov$sha256))
})

test_that("T-4.1 O3: provenance from a result equals the generated getter", {
  local_outputs_sample()
  speeches <- get_speeches(include_text = FALSE)
  ids <- unique(speeches$sitting_id)

  from_result <- result_provenance(speeches)
  from_getter <- get_provenance(sitting_id = ids)
  from_result <- from_result[order(from_result$path), ]
  from_getter <- from_getter[order(from_getter$path), ]
  expect_identical(nrow(from_result), length(ids))
  expect_identical(
    as.data.frame(from_result, row.names = NULL),
    as.data.frame(from_getter[names(from_result)], row.names = NULL)
  )
})

test_that("T-4.7 O5: a lazy chain collects inside as_corpus() to the same corpus", {
  local_outputs_sample()
  skip_without_fts_out()
  testthat::skip_if_not_installed("quanteda")

  eager <- as_corpus(suppressMessages(search_chain()))
  lazy <- as_corpus(suppressMessages(search_chain(collect = FALSE)))

  ord <- order(quanteda::docnames(lazy))
  ord_eager <- order(quanteda::docnames(eager))
  expect_identical(quanteda::docnames(lazy)[ord], quanteda::docnames(eager)[ord_eager])
  expect_identical(as.character(lazy)[ord], as.character(eager)[ord_eager])
  dv_lazy <- quanteda::docvars(lazy)[ord, , drop = FALSE]
  dv_eager <- quanteda::docvars(eager)[ord_eager, , drop = FALSE]
  rownames(dv_lazy) <- rownames(dv_eager) <- NULL
  expect_identical(names(dv_lazy), names(dv_eager))
  expect_equal(dv_lazy, dv_eager)
})
