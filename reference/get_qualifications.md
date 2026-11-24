# Get member qualifications

Reads the `qualifications` table: one row per member and qualification
(a member may have several, or none). Education background.

## Usage

``` r
get_qualifications(
  PHID = NULL,
  Qualification = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- Qualification:

  Filter on column `Qualification` (`VARCHAR`).

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

A tibble with one row per member and qualification (a member may have
several, or none) and every column of `qualifications` (zero rows if
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
get_qualifications(Qualification = matches_pattern("%laws%"))
#> # A tibble: 75 × 2
#>    PHID   Qualification                                    
#>    <chr>  <chr>                                            
#>  1 00AMX  Bachelor of Laws, University of Queensland       
#>  2 00AN3  Bachelor of Laws, Monash University              
#>  3 00AOO  Bachelor of Laws Honours, University of Adelaide 
#>  4 00AOO  Master of Laws, University of Cambridge          
#>  5 00AOU  Bachelor of Laws Honours, University of Adelaide 
#>  6 124514 Bachelor of Laws Honours, University of Melbourne
#>  7 132880 Bachelor of Laws, Australian National University 
#>  8 240756 Bachelor of Laws Honours, Flinders University    
#>  9 242515 Bachelor of Laws, Deakin University              
#> 10 242515 Master of Laws, University of Melbourne          
#> # ℹ 65 more rows
db_disconnect()
```
