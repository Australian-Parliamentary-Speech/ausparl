# Activity per party

Counts turns by the speaker's party at the time, by parliament and
chamber.

## Usage

``` r
party_activity(
  party_id = NULL,
  parliament_id = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- party_id:

  Filter on `party_id_at_time`: whole numbers or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).
  List the parties with
  [`get_parties()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parties.md).

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

A tibble with one row per party at the time, parliament and chamber,
ordered by `parliament_id`, `chamber` and `party_at_time`, and columns
`party_id_at_time`, `party_at_time`, `parliament_id`, `chamber`,
`n_members`, `n_turns`, `n_speeches`, `n_interjections` and `n_words`.
Zero rows if nothing matches; a lazy table (in no set order) if
`collect = FALSE`.

## Details

The metrics `n_turns`, `n_speeches` and `n_words` are defined as in
[`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md);
`n_interjections` is its `n_interjections_made`. `n_members` counts the
*speaking* members: the distinct PHIDs with at least one turn for that
party in that parliament and chamber.

**Party.** Each turn is assigned the party its speaker belonged to on
the sitting date (`v_party_at_time`), so a member who changed party is
counted under each party for the turns made in it. Turns without a party
at the time (presiding officers, speakers with no PHID, and members with
no party recorded for the date) are not counted. Party lineage is not
followed.

## See also

[`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md),
[`parliament_summary()`](https://australian-parliamentary-speech.github.io/ausparl/reference/parliament_summary.md),
[`add_party()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_party.md)

## Examples

``` r
db_connect(sample = TRUE)
party_activity()
#> # A tibble: 36 × 9
#>    party_id_at_time party_at_time        parliament_id chamber n_members n_turns
#>               <int> <chr>                        <int> <chr>       <dbl>   <dbl>
#>  1                1 Australian Labor Pa…             1 house          10      24
#>  2               27 Free Trade                       1 house           2       5
#>  3               48 Protectionist Party              1 house           9      55
#>  4                1 Australian Labor Pa…             7 senate          7      25
#>  5               39 Nationalist Party                7 senate          6      25
#>  6               13 Australian Democrats            33 senate          1       1
#>  7                1 Australian Labor Pa…            33 senate         14      47
#>  8                4 Liberal Party of Au…            33 senate         11      19
#>  9               60 National Party of A…            33 senate          2       2
#> 10                1 Australian Labor Pa…            36 house          22      51
#> # ℹ 26 more rows
#> # ℹ 3 more variables: n_speeches <dbl>, n_interjections <dbl>, n_words <dbl>
party_activity(party_id = 1, chamber = "house")
#> # A tibble: 4 × 9
#>   party_id_at_time party_at_time         parliament_id chamber n_members n_turns
#>              <int> <chr>                         <int> <chr>       <dbl>   <dbl>
#> 1                1 Australian Labor Par…             1 house          10      24
#> 2                1 Australian Labor Par…            36 house          22      51
#> 3                1 Australian Labor Par…            40 house          22      28
#> 4                1 Australian Labor Par…            47 house          37      75
#> # ℹ 3 more variables: n_speeches <dbl>, n_interjections <dbl>, n_words <dbl>
db_disconnect()
```
