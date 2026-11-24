# Get party membership periods

Reads the `party_service` table, or the `v_party_service_display` view
with `display = TRUE`: one row per party membership period. Party
affiliation history, and the members of a party in a period.

## Usage

``` r
get_party_service(
  PHID = NULL,
  DateStart = NULL,
  DateEnd = NULL,
  Party = NULL,
  handbook_flag = NULL,
  date_uncertain = NULL,
  party_id = NULL,
  ...,
  active_during = NULL,
  display = FALSE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- DateStart:

  Filter on column `DateStart` (`DATE`).

- DateEnd:

  Filter on column `DateEnd` (`DATE`).

- Party:

  Filter on column `Party` (`VARCHAR`).

- handbook_flag:

  Filter on column `handbook_flag` (`VARCHAR`).

- date_uncertain:

  Filter on column `date_uncertain` (`BOOLEAN`).

- party_id:

  Filter on column `party_id` (`INTEGER`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- active_during:

  Keep rows whose period overlaps this: a year, a date (`Date` or
  `"YYYY-MM-DD"`), or an
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
  of years or dates. The period runs from `DateStart` to `DateEnd`; a
  missing `DateEnd` means it is ongoing. `NULL` (the default) applies no
  date filter.

- display:

  If `TRUE`, read the `v_party_service_display` view, which adds display
  columns to the table's own. Filters still apply.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per party membership period and every column of
`party_service` (or of `v_party_service_display`) (zero rows if nothing
matches), or a lazy table if `collect = FALSE`.

## Details

Every column except `content` and `*_raw` columns is a filter argument,
spelt as in the database. Each takes `NULL` (no filter, the default), a
vector of values to match,
[`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
for an inclusive range, or
[`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md)
for a case-insensitive pattern. Filters combine with AND. Stored values
are returned unchanged, and no other filter is applied.

Generated from the database catalog by `data-raw/generate-getters.R`;
for tables without a getter use
[`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md).

## See also

[`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md),
[`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md),
[`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md)

## Examples

``` r
db_connect(sample = TRUE)
get_party_service(party_id = 1, active_during = in_range(1990, 1995))
#> # A tibble: 44 × 7
#>    PHID  DateStart  DateEnd    Party       handbook_flag date_uncertain party_id
#>    <chr> <date>     <date>     <chr>       <chr>         <lgl>             <int>
#>  1 0E4   1984-12-01 1993-03-13 Australian… NA            FALSE                 1
#>  2 3J4   1988-03-26 2007-10-17 Australian… NA            FALSE                 1
#>  3 4E4   1983-03-05 1994-03-25 Australian… NA            FALSE                 1
#>  4 4F4   1974-05-18 1993-03-31 Australian… NA            FALSE                 1
#>  5 4I4   1979-06-23 2004-08-31 Australian… NA            FALSE                 1
#>  6 5K4   1989-04-04 2015-02-06 Australian… NA            FALSE                 1
#>  7 5V5   1993-03-13 2013-08-05 Australian… NA            FALSE                 1
#>  8 656   1994-05-10 2011-06-30 Australian… NA            FALSE                 1
#>  9 6J4   1987-07-11 1996-03-02 Australian… NA            FALSE                 1
#> 10 9E4   1977-12-10 1994-02-04 Australian… NA            FALSE                 1
#> # ℹ 34 more rows
db_disconnect()
```
