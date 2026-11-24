# Database version and size

Reports which database the connection points at: schema version, build
time, the version of the pipeline that built it, whether full-text
search is available, and basic row counts. Use it to check versions and
to record the exact build you used.

## Usage

``` r
db_info(con = db_con())
```

## Arguments

- con:

  A DBI connection; defaults to the package connection.

## Value

A one-row tibble.

## Examples

``` r
db_connect(sample = TRUE)
db_info()
#> # A tibble: 1 × 8
#>   schema_version built_at            builder_version path          fts_available
#>   <chr>          <dttm>              <chr>           <chr>         <lgl>        
#> 1 7.0.0          2026-11-23 13:40:39 0.0.0.9000      /home/runner… TRUE         
#> # ℹ 3 more variables: n_sittings <int>, n_actions <int>, n_members <int>
db_disconnect()
```
