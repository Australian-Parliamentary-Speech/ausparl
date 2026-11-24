# Get member occupations

Reads the `occupations` table: one row per member and occupation (a
member may have several, or none). Prior occupations, e.g. lawyers.

## Usage

``` r
get_occupations(
  PHID = NULL,
  Occupation = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- Occupation:

  Filter on column `Occupation` (`VARCHAR`).

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

A tibble with one row per member and occupation (a member may have
several, or none) and every column of `occupations` (zero rows if
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
get_occupations(Occupation = matches_pattern("%barrister%"))
#> # A tibble: 54 × 2
#>    PHID   Occupation                                
#>    <chr>  <chr>                                     
#>  1 009MD  Barrister                                 
#>  2 00AMX  Barrister from 1999 to 2001.              
#>  3 00AMX  Barrister                                 
#>  4 00AON  Barrister and solicitor                   
#>  5 00AON  Barrister                                 
#>  6 00AOU  Barrister and solicitor from 1996 to 1999.
#>  7 00AOU  Barrister                                 
#>  8 240756 Barrister and solicitor from 2000 to 2013.
#>  9 240756 Barrister                                 
#> 10 261393 Barrister from 2003 to 2011.              
#> # ℹ 44 more rows
db_disconnect()
```
