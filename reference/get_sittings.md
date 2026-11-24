# Get sitting days

Reads the `sittings` table: one row per sitting day. Which days sat, by
chamber and parliament.

## Usage

``` r
get_sittings(
  sitting_id = NULL,
  chamber = NULL,
  date = NULL,
  parliament_id = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- sitting_id:

  Filter on column `sitting_id` (`VARCHAR`).

- chamber:

  Filter on `chamber` (`VARCHAR`): `"house"` and/or `"senate"`, in any
  case.

- date:

  Filter on column `date` (`DATE`).

- parliament_id:

  Filter on column `parliament_id` (`INTEGER`).

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

A tibble with one row per sitting day and every column of `sittings`
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
get_sittings(chamber = "House")
#> # A tibble: 4 × 4
#>   sitting_id       chamber date       parliament_id
#>   <chr>            <chr>   <date>             <int>
#> 1 house_1902-10-10 house   1902-10-10             1
#> 2 house_1990-09-17 house   1990-09-17            36
#> 3 house_2002-10-15 house   2002-10-15            40
#> 4 house_2024-02-29 house   2024-02-29            47
db_disconnect()
```
