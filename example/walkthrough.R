## ----setup--------------------------------------------------------------------
#| include: false
# ausparl: a worked example. walkthrough.R is the plain R version of walkthrough.qmd, made
# with knitr::purl(); edit the .qmd, not the .R. Run it from the top folder of the repository
# with source("example/walkthrough.R", echo = TRUE), or step through it line by line.
library(ausparl)
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

# Use the full database in dataset/ if it is there (Quarto runs this file from example/, a
# plain R run usually starts in the top folder); otherwise the copy db_connect() finds by
# itself (AUSPARL_DB, or one installed by db_download()); otherwise the bundled sample.
local_db <- c(
  file.path("..", "dataset", "hansard.duckdb"),
  file.path("dataset", "hansard.duckdb")
)
local_db <- local_db[file.exists(local_db)]
if (length(local_db) > 0) {
  db_connect(path = local_db[1])
  on_sample <- FALSE
} else {
  on_sample <- tryCatch(
    {
      db_connect()
      FALSE
    },
    ausparl_error = function(e) {
      db_connect(sample = TRUE)
      TRUE
    }
  )
}


## ----sample-note--------------------------------------------------------------
#| echo: false
#| results: asis
if (on_sample) {
  cat(
    "Note: this run uses the small sample database bundled with ausparl (eight sitting",
    "days), so the numbers are small. For the full database, run",
    "ausparl::db_download(dir = \"dataset\") once from the top folder of the repository.\n"
  )
}


## ----connect------------------------------------------------------------------
db_info() |>
  select(schema_version, built_at, n_sittings, n_actions, n_members, fts_available)


## ----find-member--------------------------------------------------------------
howard <- find_member("john howard")
howard |> select(PHID, DisplayName, chambers, first_service, last_service)


## ----profile------------------------------------------------------------------
profile <- member_profile(howard$PHID)
profile$ministry_records |>
  distinct(Role, Prep, Entity, RDateStart, RDateEnd) |>
  mutate(role = trimws(paste(Role, Prep, Entity))) |>
  select(role, RDateStart, RDateEnd) |>
  arrange(RDateStart)


## ----term-by-year-------------------------------------------------------------
if (isTRUE(db_info()$fts_available)) {
  by_year <- search_speeches_by_terms("immigration", include_text = FALSE, collect = FALSE) |>
    group_by(year = year(date)) |>
    summarise(n_turns = n(), n_mentions = sum(n_hits, na.rm = TRUE)) |>
    collect() |>
    arrange(year)
  print(
    ggplot(by_year, aes(year, n_mentions)) +
      geom_line() +
      geom_point() +
      labs(x = NULL, y = "Mentions", title = "\"immigration\" in Hansard, by year")
  )
} else {
  cat("Full-text search is not available on this machine, so the term search is skipped.\n")
}


## ----turns--------------------------------------------------------------------
turns <- get_speech_turns(sitting_id = "house_2002-10-15", include_text = FALSE)
nrow(turns)
turns |>
  filter(n_actions > 1) |>
  select(turn_no, name_raw, party_at_time, n_actions) |>
  head(5)

get_interjections(from = "2002-10-15", to = "2002-10-15", chamber = "house") |>
  count(interjector_name, target_name, sort = TRUE) |>
  head(5)


## ----government---------------------------------------------------------------
get_speeches(parliament_id = 40, include_text = FALSE, collect = FALSE) |>
  filter(!is.na(PHID)) |>
  add_government_status() |>
  count(chamber, government_status_at_time) |>
  arrange(chamber, government_status_at_time) |>
  collect()


## ----corpus-------------------------------------------------------------------
corp <- get_speeches(member = howard$PHID, parliament_id = 40, limit = 100) |>
  as_corpus()
quanteda::ndoc(corp)

quanteda::tokens(corp, remove_punct = TRUE, remove_numbers = TRUE) |>
  quanteda::tokens_tolower() |>
  quanteda::tokens_remove(quanteda::stopwords("en")) |>
  quanteda::dfm() |>
  quanteda::topfeatures(15)


## ----disconnect---------------------------------------------------------------
#| include: false
db_disconnect()

