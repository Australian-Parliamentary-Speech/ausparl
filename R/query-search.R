# Full-text term search. Values are escaped, collection is guarded, and identified interjections
# are excluded by default. Two-stage matching: BM25 recall through the prebuilt
# `fts_main_actions` index, then an escaped, case-insensitive regex check on `content`. Filters
# come from the shared `speech_query()` builder, so search and get_speeches() agree, B1
# included. The index is never built or altered here.

fts_schema <- "fts_main_actions"

#' Search speeches for words and phrases
#'
#' Returns the turns whose text contains the given terms, one row per turn, with the number of
#' exact occurrences (`n_hits`) and a BM25 relevance score (`score`). It takes the same filters
#' as [get_speeches()] and returns the same columns plus `score` and `n_hits`. Counts by
#' year or by speaker are aggregations over this result; see the examples.
#'
#' **Two-stage matching.** With `exact = TRUE` (the default):
#' 1. *Recall.* The database's full-text index (`fts_main_actions`, BM25) finds candidate turns
#'    within the years of `from` and `to`. Each term is split into words the way the index
#'    splits text (lowercased, accents and punctuation removed, digits dropped) and stopwords
#'    such as "the" or "same" are dropped, so `"same-sex marriage"` searches for `sex` and
#'    `marriage`. The index stems words, so this stage finds more turns than match exactly.
#' 2. *Verification.* Each candidate's `content` is checked with a case-insensitive regular
#'    expression built from the term. Regex special characters are matched literally (so
#'    `"LGBTIQ+"` and `"C++"` mean exactly that), whitespace inside a phrase matches any run
#'    of whitespace, and a term must start and end at a word boundary wherever its first or
#'    last character is a letter, digit or underscore. `n_hits` is the total number of
#'    occurrences of all terms in the turn.
#'
#' With `conjunctive = TRUE` a turn must contain every term; with `FALSE`, at least one.
#'
#' **Terms with no indexed words.** If a term has no words left once stopwords and digits are
#' dropped (for example `"the"` or `"1996"`), the index cannot help, so the whole search scans
#' `content` with the regular expressions alone, within the other filters. This is slower; a
#' one-line message says so, and `score` is `NA`.
#'
#' **`exact = FALSE`.** Returns the index's candidates only: stemmed matches (`"tariff"`
#' also finds `"tariffs"`), without the regex check, and `n_hits` is `NA`.
#'
#' **Turn types (B1) and filters.** As in [get_speeches()]: interjections are left out
#' unless `type` includes `"interjection"`, and presiding-officer turns unless
#' `include_presiding = TRUE`.
#'
#' **Requirements.** Search needs the database's full-text index and the DuckDB `fts`
#' extension. If the database has no index (`fts_main_actions`), the call fails with an
#' `ausparl_db_error`: use the official released build of the database; ausparl never builds
#' the index. If the `fts` extension cannot be loaded, the call fails with an
#' `ausparl_db_error` saying how to install it. There is no fallback to a full regex scan in
#' either case.
#'
#' **Words with a soft hyphen.** The index splits words at every number, punctuation mark,
#' symbol and space (so `"budget—you"` gives `budget` and `you`), but a word that contains a
#' soft hyphen (U+00AD, usually invisible) stays one token, so the recall stage does not find
#' its parts on their own.
#'
#' @param terms A character vector of words or phrases, such as `c("LGBT", "same-sex
#'   marriage")`.
#' @param exact If `TRUE` (the default), verify every match exactly and count `n_hits`. If
#'   `FALSE`, return the index's stemmed matches with `n_hits = NA`.
#' @param conjunctive If `TRUE` (the default), a turn must contain every term; if `FALSE`, any
#'   term.
#' @inheritParams get_speeches
#' @return A tibble with one row per matching turn and the columns of [get_speeches()]
#'   (`content` when `include_text = TRUE`), plus `score` (BM25 relevance, `NA` for a regex
#'   scan) and `n_hits` (exact occurrences of all terms, `NA` when `exact = FALSE`). Rows are
#'   ordered by `score`, highest first. Zero rows if nothing matches. With `collect = FALSE`, an
#'   unordered lazy table, so it can be aggregated inside DuckDB.
#' @seealso [get_speeches()], [find_member()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' # Search needs the DuckDB fts extension, installed once with network access.
#' if (isTRUE(db_info()$fts_available)) {
#'   search_speeches_by_terms("immigration", include_text = FALSE)
#'   search_speeches_by_terms(c("foreign affairs", "Indonesia"),
#'     from = 2002, to = 2002,
#'     columns = c("action_id", "date", "name_raw", "n_hits")
#'   )
#'
#'   # Counts are aggregations over the lazy result.
#'   hits <- search_speeches_by_terms("government", include_text = FALSE, collect = FALSE)
#'   hits |>
#'     dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(n_hits)) |>
#'     dplyr::collect()
#'   hits |>
#'     dplyr::group_by(year = year(date)) |>
#'     dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(n_hits)) |>
#'     dplyr::collect()
#' }
#' db_disconnect()
search_speeches_by_terms <- function(terms, from = NULL, to = NULL, member = NULL,
                                     party = NULL, parliament_id = NULL, chamber = NULL,
                                     chamber_venue = NULL,
                                     type = c("speech", "question", "answer"),
                                     include_presiding = FALSE, exact = TRUE,
                                     conjunctive = TRUE, include_text = TRUE,
                                     columns = NULL, collect = TRUE, limit = NULL) {
  call <- rlang::current_env()

  # Validation, before any query: the search's own arguments, then the shared filters, so an
  # input error is never masked by a database check.
  terms <- check_terms(terms, call)
  check_flag(exact, "exact", call)
  check_flag(conjunctive, "conjunctive", call)
  check_flag(include_text, "include_text", call)
  check_flag(include_presiding, "include_presiding", call)
  check_getter_args(
    list(parliament_id = parliament_id, chamber_venue = chamber_venue), 0L,
    collect = collect, limit = limit, call = call
  )
  bounds <- date_bounds(from, to, call = call)
  normalise_chamber(chamber, call = call)
  check_speech_type(type, call)
  check_phids(member, "member", call)
  check_party(party, call)

  # The fts checks, in order: the index, then the extension.
  con <- db_con()
  check_fts_index(con, call)
  check_fts_extension(con, call)

  # Content is always fetched for verification and dropped afterwards if not wanted.
  tbl <- speech_query(
    member = member, party = party, parliament_id = parliament_id, chamber = chamber,
    chamber_venue = chamber_venue, from = from, to = to, type = type,
    include_presiding = include_presiding, include_text = TRUE, call = call
  )
  tokens <- lapply(terms, function(term) term_tokens(con, term, call))
  tbl <- if (any(lengths(tokens) == 0)) {
    inform_regex_scan(terms[lengths(tokens) == 0])
    tbl |>
      verify_terms(terms, conjunctive, count = exact) |>
      dplyr::mutate(score = dplyr::sql("CAST(NULL AS DOUBLE)"))
  } else {
    recall <- recall_query(con, unlist(tokens), conjunctive, bounds)
    tbl <- dplyr::inner_join(tbl, recall, by = "action_id")
    if (exact) {
      verify_terms(tbl, terms, conjunctive, count = TRUE)
    } else {
      dplyr::mutate(tbl, n_hits = dplyr::sql("CAST(NULL AS INTEGER)"))
    }
  }

  out_cols <- c(speech_cols, if (include_text) "content", "score", "n_hits")
  tbl <- dplyr::select(tbl, dplyr::all_of(out_cols))
  if (collect) {
    tbl <- dplyr::arrange(tbl, dplyr::desc(!!rlang::sym("score")), !!rlang::sym("action_id"))
  }
  tbl <- select_columns(tbl, columns, call = call)
  collect_result(tbl, collect = collect, limit = limit, call = call)
}

# ---- internals: fts checks ----------------------------------------------------------------------

# The index is part of the released database; it is checked in the catalog and never built.
check_fts_index <- function(con, call) {
  n <- run_query(function() {
    DBI::dbGetQuery(con, glue::glue_sql(
      "SELECT count(*) AS n FROM duckdb_tables() WHERE schema_name = {fts_schema}",
      .con = con
    ))$n
  }, call)
  if (n == 0) {
    abort_db(c(
      "This database has no full-text index ({.field {fts_schema}}), so term search cannot
       run.",
      "i" = "Use the official released build of the Hansard database, which includes the
             index. ausparl never builds it."
    ), call = call)
  }
  invisible()
}

# Uses the extension if the connection already has it, else tries to load it once.
check_fts_extension <- function(con, call) {
  if (fts_loaded(con)) {
    return(invisible())
  }
  loaded <- tryCatch(
    {
      load_fts_extension(con)
      fts_loaded(con)
    },
    error = function(e) FALSE
  )
  if (!loaded) {
    abort_db(c(
      "Term search needs the DuckDB {.pkg fts} extension, which could not be loaded.",
      "i" = "Install it once with network access:
             {.code DBI::dbExecute(db_con(), \"INSTALL fts\")}, then reconnect with
             {.code db_connect()}.",
      "i" = "Other functions work without it."
    ), call = call)
  }
  invisible()
}

# ---- internals: terms ---------------------------------------------------------------------------

check_terms <- function(terms, call) {
  ok <- is.character(terms) && length(terms) > 0 && !anyNA(terms) &&
    all(nzchar(trimws(terms)))
  if (!ok) {
    abort_input(c(
      "{.arg terms} must be a character vector of words or phrases, none empty or
       {.val NA}.",
      "x" = "It is {.obj_type_friendly {terms}}{if (anyNA(terms)) ' containing NA' else ''}.",
      "i" = "For example {.code terms = c(\"LGBT\", \"same-sex marriage\")}."
    ), call = call)
  }
  unique(trimws(terms))
}

# The words of `term` as the index sees them: split by the index's own tokenizer, without
# empty pieces or the index's stopwords. Digits are removed by the tokenizer.
term_tokens <- function(con, term, call) {
  sql <- glue::glue_sql("
    SELECT t FROM (SELECT unnest(fts_main_actions.tokenize({term})) AS t)
    WHERE t <> '' AND t NOT IN (SELECT sw FROM fts_main_actions.stopwords)
  ", .con = con)
  run_query(function() DBI::dbGetQuery(con, sql)$t, call)
}

# A case-insensitive RE2 pattern matching `term` literally, with whitespace inside a phrase
# matching any run of whitespace. RE2 has no lookaround, so `\b` is added only at an edge whose
# character is a word character; elsewhere a boundary would wrongly require one.
term_pattern <- function(term) {
  words <- strsplit(trimws(term), "[[:space:]]+")[[1]]
  body <- paste(escape_regex(words), collapse = "\\s+")
  first <- substr(words[1], 1, 1)
  last_word <- words[length(words)]
  last <- substr(last_word, nchar(last_word), nchar(last_word))
  paste0(
    if (is_word_char(first)) "\\b",
    body,
    if (is_word_char(last)) "\\b"
  )
}

escape_regex <- function(x) {
  gsub("([][\\\\.|()*+?{}^$])", "\\\\\\1", x, perl = TRUE)
}

# RE2's `\b` treats only ASCII letters, digits and underscore as word characters.
is_word_char <- function(x) {
  grepl("^[A-Za-z0-9_]$", x)
}

# The one-line notice for the token fallback: when no pattern yields an index token, every turn
# in the filtered set is scanned by regex.
inform_regex_scan <- function(no_tokens) {
  cli::cli_inform(
    "{.val {no_tokens}} ha{?s/ve} no indexed words (only stopwords or digits), so
     {.field content} is scanned with a regular expression; this is slower."
  )
}

# ---- internals: the two stages ------------------------------------------------------------------

# BM25 candidates within the year range: (action_id, score). Hand-written because match_bm25 is
# a table macro dbplyr cannot express; values are DBI-escaped by glue_sql().
recall_query <- function(con, tokens, conjunctive, bounds) {
  year_of <- function(d) as.integer(format(d, "%Y"))
  where <- list(dplyr::sql("TRUE"))
  if (!is.null(bounds$from)) {
    where <- c(where, glue::glue_sql("year >= {y}", y = year_of(bounds$from), .con = con))
  }
  if (!is.null(bounds$to)) {
    where <- c(where, glue::glue_sql("year <= {y}", y = year_of(bounds$to), .con = con))
  }
  sql <- glue::glue_sql("
    SELECT action_id, score
    FROM (
      SELECT action_id,
             fts_main_actions.match_bm25(action_id, {query}, conjunctive := {conj})
               AS score
      FROM actions
      WHERE {where}
    ) AS fts
    WHERE score IS NOT NULL
  ",
    query = paste(unique(tokens), collapse = " "),
    conj = as.integer(conjunctive),
    where = glue::glue_sql_collapse(where, sep = " AND "),
    .con = con
  )
  dplyr::tbl(con, dplyr::sql(sql))
}

# Keeps rows whose `content` matches every term (`conjunctive`) or any term, and adds `n_hits`:
# the total occurrences of all terms, or NA when `count = FALSE`.
verify_terms <- function(tbl, terms, conjunctive, count) {
  content <- rlang::sym("content")
  patterns <- vapply(terms, term_pattern, character(1), USE.NAMES = FALSE)
  matches <- lapply(patterns, function(p) rlang::call2("regexp_matches", content, p, "i"))
  op <- if (conjunctive) "&" else "|"
  tbl <- dplyr::filter(tbl, !!Reduce(function(a, b) rlang::call2(op, a, b), matches))
  if (!count) {
    return(dplyr::mutate(tbl, n_hits = dplyr::sql("CAST(NULL AS INTEGER)")))
  }
  counts <- lapply(patterns, function(p) {
    rlang::call2("len", rlang::call2("regexp_extract_all", content, p, 0L, "i"))
  })
  n_hits <- Reduce(function(a, b) rlang::expr(!!a + !!b), counts)
  dplyr::mutate(tbl, n_hits = as.integer(!!n_hits))
}
