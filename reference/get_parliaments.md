# Get parliaments

Reads the `parliaments` table: one row per parliament. Parliament
numbers and their dates.

## Usage

``` r
get_parliaments(
  parliament_id = NULL,
  Name = NULL,
  DateElection = NULL,
  DateOpening = NULL,
  DateDissolution = NULL,
  ParliamentEnd = NULL,
  ParliamentNext = NULL,
  ParliamentOrdinal = NULL,
  FQName = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- parliament_id:

  Filter on column `parliament_id` (`INTEGER`).

- Name:

  Filter on column `Name` (`VARCHAR`).

- DateElection:

  Filter on column `DateElection` (`DATE`).

- DateOpening:

  Filter on column `DateOpening` (`DATE`).

- DateDissolution:

  Filter on column `DateDissolution` (`DATE`).

- ParliamentEnd:

  Filter on column `ParliamentEnd` (`DATE`).

- ParliamentNext:

  Filter on column `ParliamentNext` (`DOUBLE`).

- ParliamentOrdinal:

  Filter on column `ParliamentOrdinal` (`VARCHAR`).

- FQName:

  Filter on column `FQName` (`VARCHAR`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per parliament and every column of `parliaments`
(zero rows if nothing matches), or a lazy table if `collect = FALSE`.

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
get_parliaments(parliament_id = in_range(38, 40))
#> # A tibble: 3 × 9
#>   parliament_id Name      DateElection DateOpening DateDissolution ParliamentEnd
#>           <int> <chr>     <date>       <date>      <date>          <date>       
#> 1            38 Thirty-e… 1996-03-02   1996-04-30  1998-08-31      1998-10-02   
#> 2            39 Thirty-n… 1998-10-03   1998-11-10  2001-10-08      2001-11-09   
#> 3            40 Fortieth… 2001-11-10   2002-02-12  2004-08-31      2004-10-08   
#> # ℹ 3 more variables: ParliamentNext <dbl>, ParliamentOrdinal <chr>,
#> #   FQName <chr>
db_disconnect()
```
