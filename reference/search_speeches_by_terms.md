# Search speeches for words and phrases

Returns the turns whose text contains the given terms, one row per turn,
with the number of exact occurrences (`n_hits`) and a BM25 relevance
score (`score`). It takes the same filters as
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
and returns the same columns plus `score` and `n_hits`. Counts by year
or by speaker are aggregations over this result; see the examples.

## Usage

``` r
search_speeches_by_terms(
  terms,
  from = NULL,
  to = NULL,
  member = NULL,
  party = NULL,
  parliament_id = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  type = c("speech", "question", "answer"),
  include_presiding = FALSE,
  exact = TRUE,
  conjunctive = TRUE,
  include_text = TRUE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- terms:

  A character vector of words or phrases, such as
  `c("LGBT", "same-sex marriage")`.

- from, to:

  Sitting-date bounds, inclusive: a year (covering the whole year), a
  `Date`, or a `"YYYY-MM-DD"` string. `NULL` leaves that end open.

- member:

  Character vector of member PHIDs. A PHID that matches no member is an
  error; look one up with
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md).

- party:

  Party ids (numbers) or party names or abbreviations (strings); see
  Details.

- parliament_id:

  Filter on the sitting's `parliament_id`: a vector of values or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- chamber:

  `"house"` and/or `"senate"`, in any case.

- chamber_venue:

  Filter on the turn's `chamber_venue`: a vector of values or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- type:

  Turn types to return: any of `"speech"`, `"question"`, `"answer"` and
  `"interjection"`. Defaults to all but `"interjection"`.

- include_presiding:

  If `TRUE`, also return presiding-officer turns.

- exact:

  If `TRUE` (the default), verify every match exactly and count
  `n_hits`. If `FALSE`, return the index's stemmed matches with
  `n_hits = NA`.

- conjunctive:

  If `TRUE` (the default), a turn must contain every term; if `FALSE`,
  any term.

- include_text:

  If `TRUE` (the default), add the `content` column. Results with
  `content` are held to the lower size ceiling,
  `getOption("ausparl.max_rows_text")`.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per matching turn and the columns of
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
(`content` when `include_text = TRUE`), plus `score` (BM25 relevance,
`NA` for a regex scan) and `n_hits` (exact occurrences of all terms,
`NA` when `exact = FALSE`). Rows are ordered by `score`, highest first.
Zero rows if nothing matches. With `collect = FALSE`, an unordered lazy
table, so it can be aggregated inside DuckDB.

## Details

**Two-stage matching.** With `exact = TRUE` (the default):

1.  *Recall.* The database's full-text index (`fts_main_actions`, BM25)
    finds candidate turns within the years of `from` and `to`. Each term
    is split into words the way the index splits text (lowercased,
    accents and punctuation removed, digits dropped) and stopwords such
    as "the" or "same" are dropped, so `"same-sex marriage"` searches
    for `sex` and `marriage`. The index stems words, so this stage finds
    more turns than match exactly.

2.  *Verification.* Each candidate's `content` is checked with a
    case-insensitive regular expression built from the term. Regex
    special characters are matched literally (so `"LGBTIQ+"` and `"C++"`
    mean exactly that), whitespace inside a phrase matches any run of
    whitespace, and a term must start and end at a word boundary
    wherever its first or last character is a letter, digit or
    underscore. `n_hits` is the total number of occurrences of all terms
    in the turn.

With `conjunctive = TRUE` a turn must contain every term; with `FALSE`,
at least one.

**Terms with no indexed words.** If a term has no words left once
stopwords and digits are dropped (for example `"the"` or `"1996"`), the
index cannot help, so the whole search scans `content` with the regular
expressions alone, within the other filters. This is slower; a one-line
message says so, and `score` is `NA`.

**`exact = FALSE`.** Returns the index's candidates only: stemmed
matches (`"tariff"` also finds `"tariffs"`), without the regex check,
and `n_hits` is `NA`.

**Turn types (B1) and filters.** As in
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md):
interjections are left out unless `type` includes `"interjection"`, and
presiding-officer turns unless `include_presiding = TRUE`.

**Requirements.** Search needs the database's full-text index and the
DuckDB `fts` extension. If the database has no index
(`fts_main_actions`), the call fails with an `ausparl_db_error`: use the
official released build of the database; ausparl never builds the index.
If the `fts` extension cannot be loaded, the call fails with an
`ausparl_db_error` saying how to install it. There is no fallback to a
full regex scan in either case.

**Words with a soft hyphen.** The index splits words at every number,
punctuation mark, symbol and space (so `"budget—you"` gives `budget` and
`you`), but a word that contains a soft hyphen (U+00AD, usually
invisible) stays one token, so the recall stage does not find its parts
on their own.

## See also

[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md),
[`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md)

## Examples

``` r
db_connect(sample = TRUE)
# Search needs the DuckDB fts extension, installed once with network access.
if (isTRUE(db_info()$fts_available)) {
  search_speeches_by_terms("immigration", include_text = FALSE)
  search_speeches_by_terms(c("foreign affairs", "Indonesia"),
    from = 2002, to = 2002,
    columns = c("action_id", "date", "name_raw", "n_hits")
  )

  # Counts are aggregations over the lazy result.
  hits <- search_speeches_by_terms("government", include_text = FALSE, collect = FALSE)
  hits |>
    dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(n_hits)) |>
    dplyr::collect()
  hits |>
    dplyr::group_by(year = year(date)) |>
    dplyr::summarise(n_turns = dplyr::n(), n_occurrences = sum(n_hits)) |>
    dplyr::collect()
}
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> # A tibble: 7 × 3
#>    year n_turns n_occurrences
#>   <dbl>   <dbl>         <dbl>
#> 1  1902      11            13
#> 2  1918      14            44
#> 3  1983      23            68
#> 4  1990      55           592
#> 5  2002     128           630
#> 6  2019      99           496
#> 7  2024      58           157
db_disconnect()
```
