# Get turns

Reads the `actions` table, or the `v_actions_display` view with
`display = TRUE`: one row per turn (action). Turns by exact column
values, e.g. all question turns in 1977. Interjections are included: no
turn-type filter is applied unless you pass one.

## Usage

``` r
get_actions(
  action_id = NULL,
  subdebate_id = NULL,
  action_type = NULL,
  is_interjection = NULL,
  page_no = NULL,
  source_path = NULL,
  speaker_no = NULL,
  turn_no = NULL,
  nonspeech_type = NULL,
  presiding_phid = NULL,
  has_quote = NULL,
  is_petition = NULL,
  is_motion_no_speech = NULL,
  is_speech = NULL,
  is_question = NULL,
  is_answer = NULL,
  is_non_speech = NULL,
  sitting_id = NULL,
  time_of_day = NULL,
  PHID = NULL,
  resolution = NULL,
  reason = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  year = NULL,
  ...,
  display = FALSE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- action_id:

  Filter on column `action_id` (`VARCHAR`).

- subdebate_id:

  Filter on column `subdebate_id` (`VARCHAR`).

- action_type:

  Filter on column `action_type` (`VARCHAR`).

- is_interjection:

  Filter on column `is_interjection` (`BOOLEAN`).

- page_no:

  Filter on column `page_no` (`INTEGER`).

- source_path:

  Filter on column `source_path` (`VARCHAR`).

- speaker_no:

  Filter on column `speaker_no` (`INTEGER`).

- turn_no:

  Filter on column `turn_no` (`INTEGER`).

- nonspeech_type:

  Filter on column `nonspeech_type` (`VARCHAR`).

- presiding_phid:

  Filter on column `presiding_phid` (`VARCHAR`).

- has_quote:

  Filter on column `has_quote` (`BOOLEAN`).

- is_petition:

  Filter on column `is_petition` (`BOOLEAN`).

- is_motion_no_speech:

  Filter on column `is_motion_no_speech` (`BOOLEAN`).

- is_speech:

  Filter on column `is_speech` (`BOOLEAN`).

- is_question:

  Filter on column `is_question` (`BOOLEAN`).

- is_answer:

  Filter on column `is_answer` (`BOOLEAN`).

- is_non_speech:

  Filter on column `is_non_speech` (`BOOLEAN`).

- sitting_id:

  Filter on column `sitting_id` (`VARCHAR`).

- time_of_day:

  Filter on column `time_of_day` (`TIME`).

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- resolution:

  Filter on column `resolution` (`VARCHAR`).

- reason:

  Filter on column `reason` (`VARCHAR`).

- chamber:

  Filter on `chamber` (`VARCHAR`): `"house"` and/or `"senate"`, in any
  case.

- chamber_venue:

  Filter on column `chamber_venue` (`TINYINT`).

- year:

  Filter on column `year` (`SMALLINT`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- display:

  If `TRUE`, read the `v_actions_display` view, which adds display
  columns to the table's own. Filters still apply.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per turn (action) and every column of `actions`
(or of `v_actions_display`) (zero rows if nothing matches), or a lazy
table if `collect = FALSE`.

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
get_actions(action_type = "question", year = in_range(1990, 2000))
#> # A tibble: 12 × 31
#>    action_id            subdebate_id action_type is_interjection content page_no
#>    <chr>                <chr>        <chr>       <lgl>           <chr>     <int>
#>  1 house_1990-09-17_R11 house_1990-… question    FALSE           "My qu…    1933
#>  2 house_1990-09-17_R18 house_1990-… question    FALSE           "Can t…    1933
#>  3 house_1990-09-17_R20 house_1990-… question    FALSE           "My qu…    1935
#>  4 house_1990-09-17_R24 house_1990-… question    FALSE           "My qu…    1935
#>  5 house_1990-09-17_R26 house_1990-… question    FALSE           "My qu…    1936
#>  6 house_1990-09-17_R31 house_1990-… question    FALSE           "My qu…    1937
#>  7 house_1990-09-17_R33 house_1990-… question    FALSE           "I ref…    1938
#>  8 house_1990-09-17_R39 house_1990-… question    FALSE           "Can t…    1939
#>  9 house_1990-09-17_R43 house_1990-… question    FALSE           "I ref…    1940
#> 10 house_1990-09-17_R47 house_1990-… question    FALSE           "Can t…    1942
#> 11 house_1990-09-17_R7  house_1990-… question    FALSE           "I ref…    1931
#> 12 house_1990-09-17_R9  house_1990-… question    FALSE           "Can t…    1932
#> # ℹ 25 more variables: source_path <chr>, speaker_no <int>, turn_no <int>,
#> #   nonspeech_type <chr>, presiding_phid <chr>, has_quote <lgl>,
#> #   is_petition <lgl>, is_motion_no_speech <lgl>, is_speech <lgl>,
#> #   is_question <lgl>, is_answer <lgl>, is_non_speech <lgl>, sitting_id <chr>,
#> #   time_of_day <drtn>, page_no_raw <chr>, PHID <chr>, resolution <chr>,
#> #   reason <chr>, name_raw <chr>, party_raw <chr>, role_raw <chr>,
#> #   electorate_raw <chr>, chamber <chr>, chamber_venue <int>, year <int>
db_disconnect()
```
