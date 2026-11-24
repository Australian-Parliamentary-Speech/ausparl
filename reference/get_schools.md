# Get member schools

Reads the `schools` table: one row per member and school (a member may
have several, or none). Schooling background.

## Usage

``` r
get_schools(
  PHID = NULL,
  secondary_school = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- secondary_school:

  Filter on column `secondary_school` (`VARCHAR`).

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

A tibble with one row per member and school (a member may have several,
or none) and every column of `schools` (zero rows if nothing matches),
or a lazy table if `collect = FALSE`.

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
get_schools(secondary_school = matches_pattern("%grammar%"))
#> # A tibble: 4 × 2
#>   PHID   secondary_school            
#>   <chr>  <chr>                       
#> 1 261393 Newcastle Grammar School    
#> 2 300120 Canberra Grammar School     
#> 3 300126 Central Coast Grammar School
#> 4 I8M    Knox Grammar School         
db_disconnect()
```
