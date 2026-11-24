# Get members

Reads the `members` table, or the `v_members_display` view with
`display = TRUE`: one row per member. Biographical attributes: gender,
birth date, state. `display = TRUE` adds the latest party and
electorate.

## Usage

``` r
get_members(
  PHID = NULL,
  DisplayName = NULL,
  Gender = NULL,
  DateOfBirth = NULL,
  State = NULL,
  StateAbbrev = NULL,
  SenateState = NULL,
  ...,
  display = FALSE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- DisplayName:

  Filter on column `DisplayName` (`VARCHAR`).

- Gender:

  Filter on column `Gender` (`VARCHAR`).

- DateOfBirth:

  Filter on column `DateOfBirth` (`DATE`).

- State:

  Filter on column `State` (`VARCHAR`).

- StateAbbrev:

  Filter on column `StateAbbrev` (`VARCHAR`).

- SenateState:

  Filter on column `SenateState` (`VARCHAR`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- display:

  If `TRUE`, read the `v_members_display` view, which adds display
  columns to the table's own. Filters still apply.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per member and every column of `members` (or of
`v_members_display`) (zero rows if nothing matches), or a lazy table if
`collect = FALSE`.

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
get_members(Gender = "Female", StateAbbrev = c("Vic", "Tas"))
#> # A tibble: 27 × 8
#>    PHID   DisplayName           Gender DateOfBirth State StateAbbrev SenateState
#>    <chr>  <chr>                 <chr>  <date>      <chr> <chr>       <chr>      
#>  1 009CW  CORCORAN, Ann Kathle… Female 1951-09-21  Vict… Vic         ""         
#>  2 00AMR  KING, the Hon. Cathe… Female 1966-06-02  Vict… Vic         ""         
#>  3 124514 McKENZIE, Zoe Anne    Female 1972-10-02  Vict… Vic         ""         
#>  4 1M6    ALLISON, Lynette (Ly… Female 1946-10-21  Vict… Vic         "Victoria" 
#>  5 231199 URQUHART, Anne Eliza… Female 1957-10-18  Tasm… Tas         "Tasmania" 
#>  6 249710 CHESTERS, Lisa Marie  Female 1980-02-11  Vict… Vic         ""         
#>  7 250026 LAMBIE, Jacquiline (… Female 1971-02-26  Tasm… Tas         "Tasmania" 
#>  8 252157 WALSH, the Hon. Dr J… Female 1971-05-16  Vict… Vic         "Victoria" 
#>  9 263547 COKER, Elizabeth (Li… Female 1962-06-11  Vict… Vic         ""         
#> 10 264449 CHANDLER, Claire      Female 1990-06-01  Tasm… Tas         "Tasmania" 
#> # ℹ 17 more rows
#> # ℹ 1 more variable: DateOfBirth_raw <date>
db_disconnect()
```
