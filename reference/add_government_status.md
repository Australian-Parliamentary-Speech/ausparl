# Add whether the speaker's party was in government at the time of each turn

Adds `government_status_at_time` from the `v_government_status_at_time`
view: `"government"` if the speaker's party on the sitting date formed a
ministry in office that day, otherwise `"opposition"`; `NA` when the
party at the time is unknown.

## Usage

``` r
add_government_status(x)
```

## Arguments

- x:

  Turns: a data frame or tibble with a character `action_id` column, or
  a lazy table on the package connection (see the Input and output
  section).

## Value

`x` with `government_status_at_time` added: a tibble for a data frame, a
lazy table for a lazy table.

## Details

The view matches the speaker's party to the ministry's party by party
name, not by id. A ministry with no party recorded matches no speaker's
party, so turns in its term read `"opposition"`. Stored values are
returned unchanged.

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

[`add_party()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_party.md),
[`add_role()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_role.md),
[`get_ministries()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministries.md)

## Examples

``` r
db_connect(sample = TRUE)
add_government_status(
  get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5)
)
#> # A tibble: 5 × 19
#>   action_id      sitting_id date       chamber chamber_venue parliament_id PHID 
#>   <chr>          <chr>      <date>     <chr>           <int>         <int> <chr>
#> 1 house_2002-10… house_200… 2002-10-15 house               1            40 SU5  
#> 2 house_2002-10… house_200… 2002-10-15 house               1            40 K26  
#> 3 house_2002-10… house_200… 2002-10-15 house               1            40 9V5  
#> 4 house_2002-10… house_200… 2002-10-15 house               1            40 9V5  
#> 5 house_2002-10… house_200… 2002-10-15 house               1            40 009CW
#> # ℹ 12 more variables: name_raw <chr>, party_id_at_time <int>,
#> #   party_at_time <chr>, is_speech <lgl>, is_question <lgl>, is_answer <lgl>,
#> #   is_interjection <lgl>, is_non_speech <lgl>, is_petition <lgl>,
#> #   is_motion_no_speech <lgl>, has_quote <lgl>, government_status_at_time <chr>
db_disconnect()
```
