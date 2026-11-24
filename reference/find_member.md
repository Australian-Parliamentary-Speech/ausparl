# Find members by name

Looks members up by name and returns their PHIDs, the member ids every
other function takes.

## Usage

``` r
find_member(name, chamber = NULL, active_during = NULL)
```

## Arguments

- name:

  A single string: one or more name pieces separated by spaces.

- chamber:

  `"house"` and/or `"senate"`, in any case.

- active_during:

  A year, a `Date`, a `"YYYY-MM-DD"` string, or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md):
  keep people whose service overlaps it. A service with no end date
  counts as ongoing.

## Value

A tibble with one row per matching member, ordered by `DisplayName`,
with columns `PHID`, `DisplayName`, `Gender`, `DateOfBirth`, `State`,
`chambers` (the chambers the person ever served in, such as
`"house, senate"`), `first_service` (the earliest service start) and
`last_service` (the latest service end, `NA` while any service is
ongoing or has no end date). The three service columns describe all of
the person's service, whatever the filters. Zero rows if nobody matches;
that is not an error.

## Details

`name` is split on whitespace, and every piece must occur somewhere in
`members.DisplayName`, ignoring case and in any order. `DisplayName` is
stored as, for example, `"HOWARD, the Hon. John Winston, AC"`, so
`"john howard"`, `"Howard John"` and `"howard"` all find it. Characters
such as `%` and `_` are matched literally.

`chamber` and `active_during` keep only people with a period of
parliamentary service (`parl_service`) in that chamber and overlapping
that period. Service as a Member is the House and as a Senator the
Senate. With neither filter, members without any recorded service are
kept too.

## See also

[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md),
[`get_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_members.md)

## Examples

``` r
db_connect(sample = TRUE)
find_member("john howard")
#> # A tibble: 1 × 8
#>   PHID  DisplayName Gender DateOfBirth State chambers first_service last_service
#>   <chr> <chr>       <chr>  <date>      <chr> <chr>    <date>        <date>      
#> 1 ZD4   HOWARD, th… Male   1939-07-26  New … house    1974-05-18    2007-11-24  
find_member("peter", chamber = "house", active_during = 2012)
#> # A tibble: 1 × 8
#>   PHID  DisplayName Gender DateOfBirth State chambers first_service last_service
#>   <chr> <chr>       <chr>  <date>      <chr> <chr>    <date>        <date>      
#> 1 00AKI DUTTON, th… Male   1970-11-18  Quee… house    2001-11-10    2025-05-03  
db_disconnect()
```
