# Get parties

Reads the `parties` table: one row per party. Look up party names,
abbreviations and ids.

## Usage

``` r
get_parties(
  party_id = NULL,
  Name = NULL,
  Abbrev = NULL,
  Colour = NULL,
  Active = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- party_id:

  Filter on column `party_id` (`INTEGER`).

- Name:

  Filter on column `Name` (`VARCHAR`).

- Abbrev:

  Filter on column `Abbrev` (`VARCHAR`).

- Colour:

  Filter on column `Colour` (`VARCHAR`).

- Active:

  Filter on column `Active` (`BOOLEAN`).

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

A tibble with one row per party and every column of `parties` (zero rows
if nothing matches), or a lazy table if `collect = FALSE`.

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
get_parties(Abbrev = c("ALP", "LP"))
#> # A tibble: 1 × 5
#>   party_id Name                   Abbrev Colour  Active
#>      <int> <chr>                  <chr>  <chr>   <lgl> 
#> 1        1 Australian Labor Party ALP    #BB1313 NA    
db_disconnect()
```
