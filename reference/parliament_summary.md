# Summary per parliament

Summarises each parliament and chamber that has sitting days in the
database.

## Usage

``` r
parliament_summary(
  parliament_id = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- parliament_id:

  Filter on the sitting's `parliament_id`: whole numbers or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- chamber:

  `"house"` and/or `"senate"`, in any case.

- chamber_venue:

  Filter on the turn's `chamber_venue`: whole numbers or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per parliament and chamber, ordered by them, and
columns `parliament_id`, `chamber`, `n_sitting_days`, `n_members`,
`n_turns` and `mean_words_per_speech`. Zero rows if nothing matches; a
lazy table (in no set order) if `collect = FALSE`.

## Details

- `n_sitting_days`: the sitting days in `sittings`.

- `n_members`: the *serving* members, the distinct PHIDs with a period
  of service (`parl_service`) in the chamber that overlaps the
  parliament. Service as a Member is the House and as a Senator the
  Senate. The parliament runs from `DateOpening` (or `DateElection`
  where that is missing) to `ParliamentEnd` (or `DateDissolution` where
  that is missing); with neither end date it is ongoing. A service with
  no end date is ongoing.

- `n_turns`: all turns in `v_speech`, including presiding-officer and
  unmatched turns, but not quotes (passages read out), as in
  [`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md).

- `mean_words_per_speech`: words over speeches, with `n_words` and
  `n_speeches` defined as in
  [`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md)
  (`n_words` is computed when the query runs), over all speakers. `NA`
  where there are no speeches.

`chamber_venue` filters the turns only; sitting days and members are not
affected by it.

## See also

[`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md),
[`party_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/party_activity.md),
[`get_parliaments()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parliaments.md)

## Examples

``` r
db_connect(sample = TRUE)
parliament_summary()
#> # A tibble: 8 × 6
#>   parliament_id chamber n_sitting_days n_members n_turns mean_words_per_speech
#>           <int> <chr>            <dbl>     <dbl>   <dbl>                 <dbl>
#> 1             1 house                1        22      85                  77.4
#> 2             7 senate               1        14      51                 139. 
#> 3            33 senate               1        30      74                 143. 
#> 4            36 house                1        51     114                 699. 
#> 5            40 house                1        62     102                 711. 
#> 6            40 senate               1        53     150                 474. 
#> 7            46 senate               1        44     246                 304. 
#> 8            47 house                1        67     158                 269. 
parliament_summary(parliament_id = in_range(30, 48), chamber = "senate")
#> # A tibble: 3 × 6
#>   parliament_id chamber n_sitting_days n_members n_turns mean_words_per_speech
#>           <int> <chr>            <dbl>     <dbl>   <dbl>                 <dbl>
#> 1            33 senate               1        30      74                  143.
#> 2            40 senate               1        53     150                  474.
#> 3            46 senate               1        44     246                  304.
db_disconnect()
```
