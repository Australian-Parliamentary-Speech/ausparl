# Get speech turns: consecutive actions by one speaker, merged

Reads the `v_speech_turns_context` view: one row per turn, where a turn
is the run of consecutive actions in a sitting that share a `turn_no`
(actions with a missing or zero `turn_no`, and non-speech actions,
belong to no turn). The view carries the sitting's date, chamber and
parliament, the turn's first action's `name_raw`, and the party at the
time.

## Usage

``` r
get_speech_turns(
  member = NULL,
  party = NULL,
  parliament_id = NULL,
  chamber = NULL,
  from = NULL,
  to = NULL,
  sitting_id = NULL,
  resolution = NULL,
  include_text = TRUE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- member:

  Character vector of member PHIDs, matched against the turn's `PHID`. A
  PHID that matches no member is an error; look one up with
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md).

- party:

  Party ids (numbers) or party names or abbreviations (strings), matched
  against the party at the time; see
  [`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md).

- parliament_id:

  Filter on the sitting's `parliament_id`: a vector of values or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- chamber:

  `"house"` and/or `"senate"`, in any case.

- from, to:

  Sitting-date bounds, inclusive: a year (covering the whole year), a
  `Date`, or a `"YYYY-MM-DD"` string. `NULL` leaves that end open.

- sitting_id:

  Filter on `sitting_id`: a vector of values or
  [`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md).

- resolution:

  Filter on the turn's `resolution`: a character vector of values such
  as `"resolved"` or `"sentinel"`, or
  [`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md).
  `NA` is not accepted; see Details.

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

A tibble with one row per turn, ordered by `sitting_id` then `turn_no`,
with columns `sitting_id`, `date`, `chamber`, `parliament_id`,
`turn_no`, `first_action_id`, `n_actions`, `PHID`, `name_raw`,
`resolution`, `party_id_at_time`, `party_at_time`, `has_quote`,
`is_quote`, and `content` when `include_text = TRUE`. Zero rows if
nothing matches. With `collect = FALSE`, an unordered lazy table with
the same columns.

## Details

**Turns, not actions.**
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
and
[`get_actions()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_actions.md)
return one row per action: a speech broken by interjections or continued
across pages is several rows there. Here it is one row, `n_actions` says
how many actions it merges, and `content` is their text joined with a
blank line (`"\n\n"`), in document order. The turn is identified by
`sitting_id` and `turn_no`; `first_action_id` is the id of its first
action, for joining back to action-level tables. No turn-type filter is
applied: every turn in the view is returned, whatever its actions'
types.

**Quoted passages.** Two columns describe quotations, computed over the
turn's actions:

- `has_quote` is `TRUE` when any action in the turn is flagged as
  containing quoted material (`actions.has_quote`). It is coarse: the
  turn quotes something somewhere.

- `is_quote` is `TRUE` when every action in the turn is a quote
  (`action_type = "quote"`): the whole turn is a passage read into the
  record, not the speaker's own words.

Turns that are read-out passages are kept; drop them with
`dplyr::filter(!is_quote)`.

**Speaker.** `PHID`, `name_raw` and `resolution` are those of the turn's
first action. Turns by the presiding officer
(`resolution = "sentinel"`), and turns whose speaker is not one matched
member (`"collective"`, `"unknown"`, `"unmatched"`, `"ambiguous"`,
`"non_member"`, or a missing resolution), are all kept, with `PHID` `NA`
where there is no member. A `member` filter keeps only the turns of
those members. `resolution` filters on the stored values and cannot
select a missing (`NA`) resolution: such turns are returned only when
`resolution = NULL`; to keep only them, use `collect = FALSE` and
`dplyr::filter(is.na(resolution))`.

**Party.** `party_at_time` is the party of the turn's first action's
speaker on the sitting date, not the member's current party, and
`party_id_at_time` its `party_id`. `party` is resolved as in
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md).

**Order and laziness.** A collected result is ordered by `sitting_id`
and then `turn_no`, and `limit` keeps the first rows in that order. With
`collect = FALSE` the result is an unordered lazy table that works as a
parameterised view: filter, join and aggregate it in DuckDB (for example
with
[`dplyr::count()`](https://dplyr.tidyverse.org/reference/count.html))
before collecting. Stored values are returned unchanged.

## See also

[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md),
[`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md),
[`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md)

## Examples

``` r
db_connect(sample = TRUE)
get_speech_turns(party = "ALP", from = 2002, to = 2002, include_text = FALSE)
#> # A tibble: 78 × 14
#>    sitting_id date       chamber parliament_id turn_no first_action_id n_actions
#>    <chr>      <date>     <chr>           <int>   <int> <chr>               <dbl>
#>  1 house_200… 2002-10-15 house              40       2 house_2002-10-…         1
#>  2 house_200… 2002-10-15 house              40       6 house_2002-10-…         1
#>  3 house_200… 2002-10-15 house              40      10 house_2002-10-…         1
#>  4 house_200… 2002-10-15 house              40      15 house_2002-10-…         1
#>  5 house_200… 2002-10-15 house              40      19 house_2002-10-…         1
#>  6 house_200… 2002-10-15 house              40      25 house_2002-10-…         1
#>  7 house_200… 2002-10-15 house              40      27 house_2002-10-…         1
#>  8 house_200… 2002-10-15 house              40      29 house_2002-10-…         1
#>  9 house_200… 2002-10-15 house              40      31 house_2002-10-…         1
#> 10 house_200… 2002-10-15 house              40      39 house_2002-10-…         1
#> # ℹ 68 more rows
#> # ℹ 7 more variables: PHID <chr>, name_raw <chr>, resolution <chr>,
#> #   party_id_at_time <int>, party_at_time <chr>, has_quote <lgl>,
#> #   is_quote <lgl>
howard <- find_member("john howard")$PHID
get_speech_turns(member = howard, columns = c("date", "n_actions", "is_quote"))
#> # A tibble: 8 × 3
#>   date       n_actions is_quote
#>   <date>         <dbl> <lgl>   
#> 1 1990-09-17         1 FALSE   
#> 2 1990-09-17         1 FALSE   
#> 3 2002-10-15         1 FALSE   
#> 4 2002-10-15         1 FALSE   
#> 5 2002-10-15         1 FALSE   
#> 6 2002-10-15         1 FALSE   
#> 7 2002-10-15         1 FALSE   
#> 8 2002-10-15         1 FALSE   
db_disconnect()
```
