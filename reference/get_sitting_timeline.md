# Get the turns of a sitting in order

Reads the `v_sitting_timeline` view: one row per action (turn), in
document order. The view is joined to `sittings` for the date and
chamber and, when `include_text = TRUE`, to `actions` for the text.

## Usage

``` r
get_sitting_timeline(
  sitting_id = NULL,
  date = NULL,
  chamber = NULL,
  include_text = TRUE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- sitting_id:

  Filter on `sitting_id`: a vector of values or
  [`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md).

- date:

  Sitting date: a `Date` or `"YYYY-MM-DD"` string, a vector of them, or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
  (a year bound covers the whole year).

- chamber:

  `"house"` and/or `"senate"`, in any case.

- include_text:

  If `TRUE` (the default), add the `content` column. Results with
  `content` are held to the lower size ceiling,
  `getOption("ausparl.max_rows_text")`.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per action, ordered by `sitting_id` then `seq`,
with columns `sitting_id`, `date`, `chamber`, `seq`, `action_id`,
`debate_title`, `subdebate_title`, `action_type`, `PHID`,
`speaker_name`, and `content` when `include_text = TRUE`. Zero rows if
nothing matches. With `collect = FALSE`, an unordered lazy table with
the same columns.

## Details

A collected result is ordered by `sitting_id` and then `seq`, the
action's position in the sitting, and `limit` keeps the first rows in
that order. The lazy table (`collect = FALSE`) is unordered, so it can
be aggregated in DuckDB (for example with
[`dplyr::count()`](https://dplyr.tidyverse.org/reference/count.html));
add `dplyr::arrange(sitting_id, seq)` if you need the order.
`speaker_name` is the member's current `members.DisplayName`, not their
name at the time, and is `NA` where the action has no PHID. Stored
values are returned unchanged, and no turn-type filter is applied.

## See also

[`get_interjections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_interjections.md),
[`get_sittings()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sittings.md)

## Examples

``` r
db_connect(sample = TRUE)
get_sitting_timeline(sitting_id = "house_2002-10-15", include_text = FALSE)
#> # A tibble: 151 × 10
#>    sitting_id    date       chamber   seq action_id debate_title subdebate_title
#>    <chr>         <date>     <chr>   <int> <chr>     <chr>        <chr>          
#>  1 house_2002-1… 2002-10-15 house       1 house_20… N/A          N/A            
#>  2 house_2002-1… 2002-10-15 house       2 house_20… MINISTERIAL… N/A            
#>  3 house_2002-1… 2002-10-15 house       3 house_20… QUESTIONS W… Indonesia: Ter…
#>  4 house_2002-1… 2002-10-15 house       4 house_20… QUESTIONS W… Indonesia: Ter…
#>  5 house_2002-1… 2002-10-15 house       5 house_20… QUESTIONS W… Indonesia: Ter…
#>  6 house_2002-1… 2002-10-15 house       6 house_20… QUESTIONS W… Indonesia: Ter…
#>  7 house_2002-1… 2002-10-15 house       7 house_20… QUESTIONS W… Indonesia: Ter…
#>  8 house_2002-1… 2002-10-15 house       8 house_20… QUESTIONS W… Indonesia: Ter…
#>  9 house_2002-1… 2002-10-15 house       9 house_20… QUESTIONS W… Indonesia: Ter…
#> 10 house_2002-1… 2002-10-15 house      10 house_20… QUESTIONS W… Indonesia: Ter…
#> # ℹ 141 more rows
#> # ℹ 3 more variables: action_type <chr>, PHID <chr>, speaker_name <chr>
get_sitting_timeline(date = in_range("2019-01-01", "2019-12-31"), limit = 5)
#> # A tibble: 5 × 11
#>   sitting_id     date       chamber   seq action_id debate_title subdebate_title
#>   <chr>          <date>     <chr>   <int> <chr>     <chr>        <chr>          
#> 1 senate_2019-1… 2019-11-26 senate      1 senate_2… N/A          N/A            
#> 2 senate_2019-1… 2019-11-26 senate      2 senate_2… N/A          N/A            
#> 3 senate_2019-1… 2019-11-26 senate      3 senate_2… DOCUMENTS    N/A            
#> 4 senate_2019-1… 2019-11-26 senate      4 senate_2… DOCUMENTS    N/A            
#> 5 senate_2019-1… 2019-11-26 senate      5 senate_2… DOCUMENTS    N/A            
#> # ℹ 4 more variables: action_type <chr>, PHID <chr>, speaker_name <chr>,
#> #   content <chr>
db_disconnect()
```
