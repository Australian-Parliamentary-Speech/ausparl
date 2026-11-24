# Get ministries

Reads the `ministries` table: one row per ministry and governing party.
Which ministry governed in a period.

## Usage

``` r
get_ministries(
  MinistryNumber = NULL,
  MinistryName = NULL,
  DateStart = NULL,
  DateEnd = NULL,
  Party = NULL,
  pID = NULL,
  party_id = NULL,
  ...,
  active_during = NULL,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- MinistryNumber:

  Filter on column `MinistryNumber` (`INTEGER`).

- MinistryName:

  Filter on column `MinistryName` (`VARCHAR`).

- DateStart:

  Filter on column `DateStart` (`DATE`).

- DateEnd:

  Filter on column `DateEnd` (`DATE`).

- Party:

  Filter on column `Party` (`VARCHAR`).

- pID:

  Filter on column `pID` (`DOUBLE`).

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

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per ministry and governing party and every column
of `ministries` (zero rows if nothing matches), or a lazy table if
`collect = FALSE`.

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
get_ministries(active_during = 1975)
#> # A tibble: 5 × 7
#>   MinistryNumber MinistryName         DateStart  DateEnd    Party   pID party_id
#>            <int> <chr>                <date>     <date>     <chr> <dbl>    <int>
#> 1             50 Whitlam Ministry (2… 1974-05-18 1975-11-11 Aust…     1        1
#> 2             51 Fraser Ministry      1975-11-11 1975-12-13 Libe…     4        4
#> 3             51 Fraser Ministry      1975-11-11 1975-12-13 Nati…    43       43
#> 4             52 Fraser Ministry (2n… 1975-12-13 1977-12-10 Libe…     4        4
#> 5             52 Fraser Ministry (2n… 1975-12-13 1977-12-10 Nati…    43       43
db_disconnect()
```
