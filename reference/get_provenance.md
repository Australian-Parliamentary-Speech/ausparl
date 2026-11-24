# Get source-file provenance

Reads the `provenance` table: one row per source file. Trace a sitting
back to its source file and checksum.

## Usage

``` r
get_provenance(
  path = NULL,
  sha256 = NULL,
  schema_generation = NULL,
  parsed_at = NULL,
  input_row_count = NULL,
  output_action_count = NULL,
  sitting_id = NULL,
  source = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- path:

  Filter on column `path` (`VARCHAR`).

- sha256:

  Filter on column `sha256` (`VARCHAR`).

- schema_generation:

  Filter on column `schema_generation` (`VARCHAR`).

- parsed_at:

  Filter on column `parsed_at` (`TIMESTAMP`).

- input_row_count:

  Filter on column `input_row_count` (`INTEGER`).

- output_action_count:

  Filter on column `output_action_count` (`INTEGER`).

- sitting_id:

  Filter on column `sitting_id` (`VARCHAR`).

- source:

  Filter on column `source` (`VARCHAR`).

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

A tibble with one row per source file and every column of `provenance`
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
get_provenance(source = "csv")
#> # A tibble: 8 × 8
#>   path              sha256 schema_generation parsed_at           input_row_count
#>   <chr>             <chr>  <chr>             <dttm>                        <int>
#> 1 ../dataset/zenod… 5261c… v2.1              2026-11-23 10:31:39             105
#> 2 ../dataset/zenod… e997b… legacy-html       2026-11-23 10:51:32             236
#> 3 ../dataset/zenod… 4d5a0… v2.0              2026-11-23 10:54:42             317
#> 4 ../dataset/zenod… f8f64… v2.2              2026-11-23 11:01:13             362
#> 5 ../dataset/zenod… e2f96… v2.1              2026-11-23 11:05:54             110
#> 6 ../dataset/zenod… c8786… legacy-html       2026-11-23 11:14:48             107
#> 7 ../dataset/zenod… 35654… v2.0              2026-11-23 11:20:21             328
#> 8 ../dataset/zenod… a1c65… v2.2              2026-11-23 11:25:21             381
#> # ℹ 3 more variables: output_action_count <int>, sitting_id <chr>, source <chr>
db_disconnect()
```
