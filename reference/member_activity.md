# Activity per member

Counts each member's turns in `v_speech`, by parliament and chamber.

## Usage

``` r
member_activity(
  PHID = NULL,
  parliament_id = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Character vector of member PHIDs. A PHID that matches no member is an
  error; look one up with
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md).

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

A tibble with one row per member, parliament and chamber in which the
member had at least one turn or received an interjection, ordered by
those three, and columns `PHID`, `parliament_id`, `chamber`, `n_turns`,
`n_speeches`, `n_questions`, `n_answers`, `n_interjections_made`,
`n_interjections_received` and `n_words`. Zero rows if nothing matches;
a lazy table (in no set order) if `collect = FALSE`.

## Details

**Metrics.** The three activity functions share these definitions:

- `n_turns`: all turns in `v_speech`, including interjections. Quotes
  (`action_type` is `"quote"`: passages read out, such as a letter or a
  petition) are not turns and are not counted by any metric.

- `n_speeches`: turns with `is_speech`, `is_question` or `is_answer`
  set, and not `is_interjection`. This is the default of
  [`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md),
  so `n_speeches` equals the number of rows it returns for the same
  member and parliament.

- `n_questions`, `n_answers`: turns with `is_question` (or `is_answer`)
  set that are not interjections.

- `n_interjections_made`: turns with `is_interjection` set.

- `n_interjections_received`: interjections in `v_interjection_target`
  whose target turn (the turn interrupted) was made by the member,
  counted in the target turn's parliament and chamber.

- `n_words`: words summed over the `n_speeches` turns. A word is a run
  of non-whitespace characters: the turn's `content` is trimmed and
  split on `\s+`. The count is computed when the query runs, because the
  database has no word-count column. Stored content is counted as it is,
  so a turn whose content is `"N/A"` counts one word.

**Grain and filters.** `parliament_id` and `chamber` are the sitting's,
from `sittings`. `chamber_venue` filters the turns (for received
interjections, the target turns). Turns without a PHID are not counted:
presiding officers, and unmatched, unknown, collective and non-member
speakers (see
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)).

## See also

[`party_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/party_activity.md),
[`parliament_summary()`](https://australian-parliamentary-speech.github.io/ausparl/reference/parliament_summary.md),
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)

## Examples

``` r
db_connect(sample = TRUE)
member_activity()
#> # A tibble: 311 × 10
#>    PHID  parliament_id chamber n_turns n_speeches n_questions n_answers
#>    <chr>         <int> <chr>     <dbl>      <dbl>       <dbl>     <dbl>
#>  1 009CW            40 house         1          1           0         0
#>  2 009D2            40 senate        2          2           0         0
#>  3 009MD             1 house        13         13           0        12
#>  4 00AKI            47 house         8          7           5         0
#>  5 00AMN            47 house         1          1           1         0
#>  6 00AMR            40 house         1          1           0         0
#>  7 00AMR            47 house         1          1           0         1
#>  8 00AMX            40 house         1          1           0         0
#>  9 00AN2            40 house         1          1           1         0
#> 10 00AN3            40 house         1          1           0         0
#> # ℹ 301 more rows
#> # ℹ 3 more variables: n_interjections_made <dbl>,
#> #   n_interjections_received <dbl>, n_words <dbl>
member_activity(PHID = "ZD4", columns = c("parliament_id", "n_speeches", "n_words"))
#> # A tibble: 2 × 3
#>   parliament_id n_speeches n_words
#>           <int>      <dbl>   <dbl>
#> 1            36          0       0
#> 2            40          5    1606
db_disconnect()
```
