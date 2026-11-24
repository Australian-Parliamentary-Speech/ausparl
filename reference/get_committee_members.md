# Get committee memberships

Reads the `committee_members` table, or the
`v_committee_members_display` view with `display = TRUE`: one row per
committee membership. Committee roles and dates.

## Usage

``` r
get_committee_members(
  PHID = NULL,
  committee_type = NULL,
  committee_area = NULL,
  start_date = NULL,
  end_date = NULL,
  end_date_status = NULL,
  committee_member_id = NULL,
  ...,
  active_during = NULL,
  display = FALSE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- PHID:

  Filter on column `PHID` (`VARCHAR`).

- committee_type:

  Filter on column `committee_type` (`VARCHAR`).

- committee_area:

  Filter on column `committee_area` (`VARCHAR`).

- start_date:

  Filter on column `start_date` (`DATE`).

- end_date:

  Filter on column `end_date` (`DATE`).

- end_date_status:

  Filter on column `end_date_status` (`VARCHAR`).

- committee_member_id:

  Filter on column `committee_member_id` (`VARCHAR`).

- ...:

  Must be empty. It forces the arguments after it to be named.

- active_during:

  Keep rows whose period overlaps this: a year, a date (`Date` or
  `"YYYY-MM-DD"`), or an
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
  of years or dates. The period runs from `start_date` to `end_date`; a
  missing `end_date` means it is ongoing. `NULL` (the default) applies
  no date filter.

- display:

  If `TRUE`, read the `v_committee_members_display` view, which adds
  display columns to the table's own. Filters still apply.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per committee membership and every column of
`committee_members` (or of `v_committee_members_display`) (zero rows if
nothing matches), or a lazy table if `collect = FALSE`.

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
get_committee_members(committee_area = matches_pattern("%legislation%"), active_during = 2001)
#> # A tibble: 53 × 8
#>    PHID  committee_type        committee_area start_date end_date   end_date_raw
#>    <chr> <chr>                 <chr>          <date>     <date>     <date>      
#>  1 009D2 Senate Standing       Scrutiny of D… 2000-10-04 2002-07-01 2002-07-01  
#>  2 009D2 Senate Legislative a… Rural and Reg… 2001-02-13 2001-02-14 2001-02-14  
#>  3 009D2 Senate Legislative a… Rural and Reg… 2001-02-16 2001-02-16 2001-02-16  
#>  4 1M6   Senate Legislative a… Community Aff… 1999-10-12 2002-09-17 2002-09-17  
#>  5 1M6   Senate Legislative a… Economics: Le… 2000-09-04 2001-10-08 2001-10-08  
#>  6 2L6   Senate Legislative a… Environment, … 1998-11-24 2002-02-11 2002-02-11  
#>  7 2M6   Senate Legislative a… Legal and Con… 1997-02-26 2002-02-11 2002-02-11  
#>  8 2M6   Senate Standing       Scrutiny of D… 1999-03-31 2002-02-11 2002-02-11  
#>  9 3I6   Senate Legislative a… Employment, W… 1998-11-24 2002-02-11 2002-02-11  
#> 10 3I6   Senate Legislative a… Environment, … 1998-11-24 2001-05-22 2001-05-22  
#> # ℹ 43 more rows
#> # ℹ 2 more variables: end_date_status <chr>, committee_member_id <chr>
db_disconnect()
```
