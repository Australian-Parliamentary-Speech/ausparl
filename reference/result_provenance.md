# Source files behind a result

Looks up the `provenance` rows, one per source file, for the sittings in
`x`: the file `path`, its `sha256` checksum, the parser generation and
when it was parsed. Use it to trace a result back to the exact files it
was built from.

## Usage

``` r
result_provenance(x, columns = NULL, collect = TRUE, limit = NULL)
```

## Arguments

- x:

  A character vector of `sitting_id`s, or a data frame or lazy table
  with a character `sitting_id` column.

- columns:

  Character vector of `provenance` columns to return; `NULL` returns
  all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per source file and the columns of `provenance`
(`path`, `sha256`, `schema_generation`, `parsed_at`, `input_row_count`,
`output_action_count`, `sitting_id`, `source`); zero rows if no sitting
matches. A lazy table if `collect = FALSE`.

## Details

`x` is either a character vector of `sitting_id`s, or any result with a
`sitting_id` column, such as the output of
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
or
[`search_speeches_by_terms()`](https://australian-parliamentary-speech.github.io/ausparl/reference/search_speeches_by_terms.md).
A result may be a data frame (or tibble) or a lazy table on the package
connection, such as one returned with `collect = FALSE`; a lazy table is
matched inside DuckDB, without reading it into R. Each distinct sitting
is looked up once, and `NA` sitting ids in a result are ignored.

A sitting with no `provenance` row gives no row; it is not an error.
Stored values are returned unchanged.

## See also

[`get_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_provenance.md)
to filter `provenance` by any column

## Examples

``` r
db_connect(sample = TRUE)
result_provenance("house_2002-10-15")
#> # A tibble: 1 × 8
#>   path              sha256 schema_generation parsed_at           input_row_count
#>   <chr>             <chr>  <chr>             <dttm>                        <int>
#> 1 ../dataset/zenod… 4d5a0… v2.0              2026-11-23 10:54:42             317
#> # ℹ 3 more variables: output_action_count <int>, sitting_id <chr>, source <chr>
speeches <- get_speeches(from = 2002, to = 2002, include_text = FALSE)
result_provenance(speeches)
#> # A tibble: 2 × 8
#>   path              sha256 schema_generation parsed_at           input_row_count
#>   <chr>             <chr>  <chr>             <dttm>                        <int>
#> 1 ../dataset/zenod… 4d5a0… v2.0              2026-11-23 10:54:42             317
#> 2 ../dataset/zenod… 35654… v2.0              2026-11-23 11:20:21             328
#> # ℹ 3 more variables: output_action_count <int>, sitting_id <chr>, source <chr>
db_disconnect()
```
