# Add the speaker's party at the time of each turn

Adds the party the speaker belonged to on the sitting date of each turn,
from the `v_party_at_time` view.

## Usage

``` r
add_party(x)
```

## Arguments

- x:

  Turns: a data frame or tibble with a character `action_id` column, or
  a lazy table on the package connection (see the Input and output
  section).

## Value

`x` with the party columns added: a tibble for a data frame, a lazy
table for a lazy table.

## Details

Three columns are added: `party_at_time` (the party name),
`party_id_at_time` and `party_abbrev_at_time` (the party's `Abbrev` in
`parties`). Stored values are returned unchanged.

[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
output already has `party_at_time` and `party_id_at_time`, so only
`party_abbrev_at_time` is added to it.

## Input and output

`x` is a result with one row per turn and a character `action_id`
column, such as the output of
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md),
[`search_speeches_by_terms()`](https://australian-parliamentary-speech.github.io/ausparl/reference/search_speeches_by_terms.md)
or
[`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md).
It is either a data frame (or tibble), or a lazy table on the package
connection, such as one returned with `collect = FALSE`.

- A lazy table gets a lazy left join, and nothing is read until you
  [`collect()`](https://dplyr.tidyverse.org/reference/compute.html) it.

- A data frame is joined inside DuckDB and returned as a tibble, with
  the same rows in the same order, its columns first and the added
  columns after them.

Rows are never dropped or repeated. A turn without a `PHID` (a presiding
officer, or a speaker who is not one member; see
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)),
or whose `action_id` is not in the database, is kept with `NA` in the
added columns. A column that is already in `x` is not added again: only
the missing ones are added, and a message names the ones skipped. If all
of them are present, `x` is returned unchanged.

## See also

[`add_government_status()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_government_status.md),
[`get_parties()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parties.md)

## Examples

``` r
db_connect(sample = TRUE)
turns <- get_sitting_timeline(date = "1918-09-19", chamber = "senate")
add_party(turns)
#> # A tibble: 104 × 14
#>    sitting_id    date       chamber   seq action_id debate_title subdebate_title
#>    <chr>         <date>     <chr>   <int> <chr>     <chr>        <chr>          
#>  1 senate_1918-… 1918-09-19 senate      1 senate_1… N/A          N/A            
#>  2 senate_1918-… 1918-09-19 senate      2 senate_1… ASSENT TO B… N/A            
#>  3 senate_1918-… 1918-09-19 senate      3 senate_1… ASSENT TO B… N/A            
#>  4 senate_1918-… 1918-09-19 senate      4 senate_1… QUESTIONS    POSTMASTER-GEN…
#>  5 senate_1918-… 1918-09-19 senate      5 senate_1… QUESTIONS    POSTMASTER-GEN…
#>  6 senate_1918-… 1918-09-19 senate      6 senate_1… QUESTIONS    RETURNED SOLDI…
#>  7 senate_1918-… 1918-09-19 senate      7 senate_1… QUESTIONS    RETURNED SOLDI…
#>  8 senate_1918-… 1918-09-19 senate      8 senate_1… QUESTIONS    RETURNED SOLDI…
#>  9 senate_1918-… 1918-09-19 senate      9 senate_1… PAPERS       N/A            
#> 10 senate_1918-… 1918-09-19 senate     10 senate_1… PAPERS       N/A            
#> # ℹ 94 more rows
#> # ℹ 7 more variables: action_type <chr>, PHID <chr>, speaker_name <chr>,
#> #   content <chr>, party_id_at_time <int>, party_at_time <chr>,
#> #   party_abbrev_at_time <chr>
db_disconnect()
```
