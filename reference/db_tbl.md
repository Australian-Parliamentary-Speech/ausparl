# A lazy table for any table or view

Escape hatch to any table or view in the database, as a lazy `dplyr`
table. Nothing is read until you
[`collect()`](https://dplyr.tidyverse.org/reference/compute.html) it.

## Usage

``` r
db_tbl(name, con = db_con())
```

## Arguments

- name:

  Table or view name, e.g. `"actions"`, `"v_speech"`, or
  `"schema.table"` such as `"fts_main_actions.docs"`.

- con:

  A DBI connection; defaults to the package connection.

## Value

A lazy `tbl`.

## Examples

``` r
db_connect(sample = TRUE)
db_tbl("sittings")
#> # A query:  ?? x 4
#> # Database: DuckDB 2.0.0 [unknown@Linux 7.0.0-1016-aws:R 4.6.2//home/runner/work/_temp/Library/ausparl/extdata/ausparl-sample.duckdb]
#>   sitting_id        chamber date       parliament_id
#>   <chr>             <chr>   <date>             <int>
#> 1 house_1902-10-10  house   1902-10-10             1
#> 2 house_1990-09-17  house   1990-09-17            36
#> 3 house_2002-10-15  house   2002-10-15            40
#> 4 house_2024-02-29  house   2024-02-29            47
#> 5 senate_1918-09-19 senate  1918-09-19             7
#> 6 senate_1983-05-10 senate  1983-05-10            33
#> 7 senate_2002-09-17 senate  2002-09-17            40
#> 8 senate_2019-11-26 senate  2019-11-26            46
db_disconnect()
```
