# Get subdebates

Reads the `subdebates` table: one row per subdebate. Nested topics
within a debate.

## Usage

``` r
get_subdebates(
  subdebate_id = NULL,
  debate_id = NULL,
  title = NULL,
  subdebate_order = NULL,
  parent_subdebate_id = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- subdebate_id:

  Filter on column `subdebate_id` (`VARCHAR`).

- debate_id:

  Filter on column `debate_id` (`VARCHAR`).

- title:

  Filter on column `title` (`VARCHAR`).

- subdebate_order:

  Filter on column `subdebate_order` (`INTEGER`).

- parent_subdebate_id:

  Filter on column `parent_subdebate_id` (`VARCHAR`).

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

A tibble with one row per subdebate and every column of `subdebates`
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
get_subdebates(title = matches_pattern("%immigration%"))
#> # A tibble: 8 × 5
#>   subdebate_id             debate_id   title subdebate_order parent_subdebate_id
#>   <chr>                    <chr>       <chr>           <int> <chr>              
#> 1 house_2024-02-29_D11_S16 house_2024… Mini…              16 NA                 
#> 2 house_2024-02-29_D11_S18 house_2024… Mini…              18 NA                 
#> 3 house_2024-02-29_D9_S3   house_2024… Immi…               3 NA                 
#> 4 house_2024-02-29_D9_S5   house_2024… Immi…               5 NA                 
#> 5 house_2024-02-29_D11_S4  house_2024… Immi…               4 NA                 
#> 6 house_2024-02-29_D11_S6  house_2024… Immi…               6 NA                 
#> 7 house_2024-02-29_D11_S8  house_2024… Immi…               8 NA                 
#> 8 house_2024-02-29_D11_S12 house_2024… Immi…              12 NA                 
db_disconnect()
```
