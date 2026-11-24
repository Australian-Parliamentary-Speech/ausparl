# Get presiding-office periods

Reads the `presiding_officers` table: one row per presiding-office
period. Who held a presiding office (Speaker, President, deputies,
panels), and when. `Chamber` holds "House" or "Senate" as stored
(capitalised, matched exactly).

## Usage

``` r
get_presiding_officers(
  PHID = NULL,
  Office = NULL,
  Chamber = NULL,
  DateStart = NULL,
  DateEnd = NULL,
  Note = NULL,
  handbook_flag = NULL,
  presiding_officer_id = NULL,
  ...,
  active_during = NULL,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- Office:

  Filter on column `Office` (`VARCHAR`).

- Chamber:

  Filter on column `Chamber` (`VARCHAR`).

- DateStart:

  Filter on column `DateStart` (`DATE`).

- DateEnd:

  Filter on column `DateEnd` (`DATE`).

- Note:

  Filter on column `Note` (`VARCHAR`).

- handbook_flag:

  Filter on column `handbook_flag` (`VARCHAR`).

- presiding_officer_id:

  Filter on column `presiding_officer_id` (`VARCHAR`).

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

A tibble with one row per presiding-office period and every column of
`presiding_officers` (zero rows if nothing matches), or a lazy table if
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
get_presiding_officers(Chamber = "Senate", active_during = 2000)
#> # A tibble: 9 × 8
#>   PHID  Office                 Chamber DateStart  DateEnd    Note  handbook_flag
#>   <chr> <chr>                  <chr>   <date>     <date>     <chr> <chr>        
#> 1 FF4   Temporary Chair of Co… Senate  1993-05-05 2008-06-30 NA    NA           
#> 2 VJ4   Temporary Chair of Co… Senate  1995-05-10 2008-06-30 NA    NA           
#> 3 EP5   Temporary Chair of Co… Senate  1996-05-01 2007-08-14 NA    NA           
#> 4 TH4   Temporary Chairman of… Senate  1996-05-01 2005-06-30 NA    NA           
#> 5 VI4   President of the Sena… Senate  1996-08-20 2002-08-18 NA    NA           
#> 6 FX5   Temporary Chair of Co… Senate  1996-09-12 2002-02-12 NA    NA           
#> 7 5F4   Temporary Chair of Co… Senate  1997-09-03 2002-08-19 NA    NA           
#> 8 7L6   Temporary Chair of Co… Senate  1997-09-29 2002-08-19 NA    NA           
#> 9 DT6   Temporary Chair of Co… Senate  1998-11-10 2002-10-15 NA    NA           
#> # ℹ 1 more variable: presiding_officer_id <chr>
db_disconnect()
```
