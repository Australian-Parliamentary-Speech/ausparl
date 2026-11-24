# Get electorates

Reads the `electorates` table: one row per electorate. Electorate names,
states and the dates they existed.

## Usage

``` r
get_electorates(
  electorate_id = NULL,
  Electorate = NULL,
  State = NULL,
  StateAbbrev = NULL,
  Origin = NULL,
  Notes = NULL,
  Established = NULL,
  Ceased = NULL,
  ...,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- electorate_id:

  Filter on column `electorate_id` (`INTEGER`).

- Electorate:

  Filter on column `Electorate` (`VARCHAR`).

- State:

  Filter on column `State` (`VARCHAR`).

- StateAbbrev:

  Filter on column `StateAbbrev` (`VARCHAR`).

- Origin:

  Filter on column `Origin` (`VARCHAR`).

- Notes:

  Filter on column `Notes` (`VARCHAR`).

- Established:

  Filter on column `Established` (`DATE`).

- Ceased:

  Filter on column `Ceased` (`DATE`).

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

A tibble with one row per electorate and every column of `electorates`
(zero rows if nothing matches), or a lazy table if `collect = FALSE`.

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
get_electorates(StateAbbrev = "Tas")
#> # A tibble: 9 × 8
#>   electorate_id Electorate State StateAbbrev Origin Notes Established Ceased    
#>           <int> <chr>      <chr> <chr>       <chr>  <chr> <date>      <date>    
#> 1            87 Bass       Tasm… Tas         Named… ""    1903-10-02  NA        
#> 2            97 Braddon    Tasm… Tas         Named… "For… 1955-08-30  NA        
#> 3           120 Denison    Tasm… Tas         Sir W… "Ren… 1903-10-02  2017-11-14
#> 4           136 Franklin   Tasm… Tas         Named… ""    1903-10-02  NA        
#> 5           173 Lyons      Tasm… Tas         Joint… "For… 1984-09-12  NA        
#> 6           232 Tasmania   Tasm… Tas         Named… "At … 1901-01-01  1903-10-02
#> 7           255 Darwin     Tasm… Tas         Geogr… "Ren… 1903-10-02  1955-08-30
#> 8           293 Wilmot     Tasm… Tas         Sir J… "Ren… 1903-10-02  1984-09-12
#> 9          2974 Clark      Tasm… Tas         Named… "For… 2017-11-14  NA        
db_disconnect()
```
