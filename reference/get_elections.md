# Get elections

Reads the `elections` table: one row per election. Election dates by
parliament.

## Usage

``` r
get_elections(
  Id = NULL,
  HandbookId = NULL,
  Division = NULL,
  DateElection = NULL,
  Year = NULL,
  FullSenateElection = NULL,
  Parliament = NULL,
  Reps = NULL,
  Senate = NULL,
  Byelection = NULL,
  SupplementaryElection = NULL,
  handbook_flag = NULL,
  parliament_id = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- Id:

  Filter on column `Id` (`INTEGER`).

- HandbookId:

  Filter on column `HandbookId` (`DOUBLE`).

- Division:

  Filter on column `Division` (`VARCHAR`).

- DateElection:

  Filter on column `DateElection` (`DATE`).

- Year:

  Filter on column `Year` (`INTEGER`).

- FullSenateElection:

  Filter on column `FullSenateElection` (`BOOLEAN`).

- Parliament:

  Filter on column `Parliament` (`VARCHAR`).

- Reps:

  Filter on column `Reps` (`BOOLEAN`).

- Senate:

  Filter on column `Senate` (`BOOLEAN`).

- Byelection:

  Filter on column `Byelection` (`BOOLEAN`).

- SupplementaryElection:

  Filter on column `SupplementaryElection` (`BOOLEAN`).

- handbook_flag:

  Filter on column `handbook_flag` (`VARCHAR`).

- parliament_id:

  Filter on column `parliament_id` (`INTEGER`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per election and every column of `elections` (zero
rows if nothing matches), or a lazy table if `collect = FALSE`.

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
get_elections(Byelection = FALSE, Year = in_range(1990, 2000))
#> # A tibble: 5 × 14
#>      Id HandbookId Division DateElection  Year FullSenateElection Parliament
#>   <int>      <dbl> <chr>    <date>       <int> <lgl>              <chr>     
#> 1   237        237 Federal  1990-03-24    1990 FALSE              P36       
#> 2   238        238 Federal  1993-03-13    1993 FALSE              P37       
#> 3  9008         NA Dickson  1993-04-17    1993 FALSE              P37       
#> 4   239        239 Federal  1996-03-02    1996 FALSE              P38       
#> 5   240        240 Federal  1998-10-03    1998 FALSE              P39       
#> # ℹ 7 more variables: Reps <lgl>, Senate <lgl>, Byelection <lgl>,
#> #   SupplementaryElection <lgl>, handbook_flag <chr>, parliament_id <int>,
#> #   DateElection_raw <date>
db_disconnect()
```
