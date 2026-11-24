# Get ministerial appointments

Reads the `ministry_records` table, or the `v_ministry_records_display`
view with `display = TRUE`: one row per ministerial appointment.
Front-bench roles and portfolios.

## Usage

``` r
get_ministry_records(
  ministry_number = NULL,
  PHID = NULL,
  Role = NULL,
  Prep = NULL,
  Entity = NULL,
  RDateStart = NULL,
  RDateEnd = NULL,
  ministry_record_id = NULL,
  ministry_party = NULL,
  ...,
  active_during = NULL,
  display = FALSE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- ministry_number:

  Filter on column `ministry_number` (`INTEGER`).

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- Role:

  Filter on column `Role` (`VARCHAR`).

- Prep:

  Filter on column `Prep` (`VARCHAR`).

- Entity:

  Filter on column `Entity` (`VARCHAR`).

- RDateStart:

  Filter on column `RDateStart` (`DATE`).

- RDateEnd:

  Filter on column `RDateEnd` (`DATE`).

- ministry_record_id:

  Filter on column `ministry_record_id` (`VARCHAR`).

- ministry_party:

  Filter on column `ministry_party` (`VARCHAR`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- active_during:

  Keep rows whose period overlaps this: a year, a date (`Date` or
  `"YYYY-MM-DD"`), or an
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
  of years or dates. The period runs from `RDateStart` to `RDateEnd`; a
  missing `RDateEnd` means it is ongoing. `NULL` (the default) applies
  no date filter.

- display:

  If `TRUE`, read the `v_ministry_records_display` view, which adds
  display columns to the table's own. Filters still apply.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per ministerial appointment and every column of
`ministry_records` (or of `v_ministry_records_display`) (zero rows if
nothing matches), or a lazy table if `collect = FALSE`.

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
get_ministry_records(Role = matches_pattern("%treasurer%"), active_during = 2000)
#> # A tibble: 4 × 9
#>   ministry_number PHID  Role      Prep  Entity RDateStart RDateEnd  
#>             <int> <chr> <chr>     <chr> <chr>  <date>     <date>    
#> 1              61 CT4   Treasurer ""    ""     1996-03-11 2007-12-03
#> 2              62 CT4   Treasurer ""    ""     1996-03-11 2007-12-03
#> 3              63 CT4   Treasurer ""    ""     1996-03-11 2007-12-03
#> 4              64 CT4   Treasurer ""    ""     1996-03-11 2007-12-03
#> # ℹ 2 more variables: ministry_record_id <chr>, ministry_party <chr>
db_disconnect()
```
