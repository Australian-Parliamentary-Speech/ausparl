# Get debates

Reads the `debates` table: one row per debate. Debate titles and their
order within a sitting.

## Usage

``` r
get_debates(
  debate_id = NULL,
  sitting_id = NULL,
  title = NULL,
  debate_order = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- debate_id:

  Filter on column `debate_id` (`VARCHAR`).

- sitting_id:

  Filter on column `sitting_id` (`VARCHAR`).

- title:

  Filter on column `title` (`VARCHAR`).

- debate_order:

  Filter on column `debate_order` (`INTEGER`).

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

A tibble with one row per debate and every column of `debates` (zero
rows if nothing matches), or a lazy table if `collect = FALSE`.

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
get_debates(sitting_id = "house_2002-10-15")
#> # A tibble: 22 × 4
#>    debate_id            sitting_id       title                      debate_order
#>    <chr>                <chr>            <chr>                             <int>
#>  1 house_2002-10-15_D1  house_2002-10-15 N/A                                   1
#>  2 house_2002-10-15_D2  house_2002-10-15 MINISTERIAL ARRANGEMENTS              2
#>  3 house_2002-10-15_D3  house_2002-10-15 QUESTIONS WITHOUT NOTICE              3
#>  4 house_2002-10-15_D4  house_2002-10-15 DISTINGUISHED VISITORS                4
#>  5 house_2002-10-15_D5  house_2002-10-15 QUESTIONS WITHOUT NOTICE              5
#>  6 house_2002-10-15_D6  house_2002-10-15 AUDITOR-GENERAL'S REPORTS             6
#>  7 house_2002-10-15_D7  house_2002-10-15 PAPERS                                7
#>  8 house_2002-10-15_D8  house_2002-10-15 INDONESIA: TERRORIST ATTA…            8
#>  9 house_2002-10-15_D9  house_2002-10-15 MAIN COMMITTEE                        9
#> 10 house_2002-10-15_D10 house_2002-10-15 MATTERS OF PUBLIC IMPORTA…           10
#> # ℹ 12 more rows
db_disconnect()
```
