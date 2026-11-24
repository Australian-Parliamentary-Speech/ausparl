# Get parliamentary service periods

Reads the `parl_service` table, or the `v_parl_service_display` view
with `display = TRUE`: one row per service period. Who held which seat,
and when.

## Usage

``` r
get_parl_service(
  PHID = NULL,
  MemberOrSenator = NULL,
  Electorate = NULL,
  DateStart = NULL,
  DateEnd = NULL,
  Description = NULL,
  handbook_flag = NULL,
  electorate_id = NULL,
  DateEnd_status = NULL,
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

- MemberOrSenator:

  Filter on column `MemberOrSenator` (`VARCHAR`).

- Electorate:

  Filter on column `Electorate` (`VARCHAR`).

- DateStart:

  Filter on column `DateStart` (`DATE`).

- DateEnd:

  Filter on column `DateEnd` (`DATE`).

- Description:

  Filter on column `Description` (`VARCHAR`).

- handbook_flag:

  Filter on column `handbook_flag` (`VARCHAR`).

- electorate_id:

  Filter on column `electorate_id` (`INTEGER`).

- DateEnd_status:

  Filter on column `DateEnd_status` (`VARCHAR`).

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

  If `TRUE`, read the `v_parl_service_display` view, which adds display
  columns to the table's own. Filters still apply.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per service period and every column of
`parl_service` (or of `v_parl_service_display`) (zero rows if nothing
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
get_parl_service(MemberOrSenator = "Senator", active_during = 1996)
#> # A tibble: 51 × 11
#>    PHID  MemberOrSenator Electorate        DateStart  DateEnd    Description    
#>    <chr> <chr>           <chr>             <date>     <date>     <chr>          
#>  1 1M6   Senator         Victoria          1996-07-01 2002-06-30 Elected to the…
#>  2 2L6   Senator         Western Australia 1996-07-01 2002-06-30 Elected to the…
#>  3 2M6   Senator         New South Wales   1996-07-01 2002-06-30 Elected to the…
#>  4 3I6   Senator         South Australia   1995-11-29 1996-06-30 Chosen by the …
#>  5 3I6   Senator         South Australia   1996-07-01 2002-06-30 Elected to the…
#>  6 3L6   Senator         Victoria          1996-04-30 1999-06-30 Appointed by t…
#>  7 5F4   Senator         Tasmania          1990-07-01 1996-06-30 Re-elected 1990
#>  8 5F4   Senator         Tasmania          1996-07-01 2002-06-30 Re-elected 1996
#>  9 5K4   Senator         New South Wales   1993-07-01 1999-06-30 Re-elected 1993
#> 10 5L6   Senator         South Australia   1996-07-01 1996-07-12 Elected to the…
#> # ℹ 41 more rows
#> # ℹ 5 more variables: handbook_flag <chr>, DateStart_raw <date>,
#> #   DateEnd_raw <date>, electorate_id <int>, DateEnd_status <chr>
db_disconnect()
```
