# Connect to the Hansard database

Opens the package's single read-only connection to the Australian
Hansard DuckDB database. Any connection already open is closed first.
The database file is never written to.

## Usage

``` r
db_connect(path = NULL, sample = FALSE)
```

## Arguments

- path:

  Path to a `hansard.duckdb` file.

- sample:

  If `TRUE`, use the small sample database bundled with the package.

## Value

The DBI connection, invisibly.

## Details

The file is chosen as follows. An explicit `path` or `sample = TRUE` is
used as given (passing both is an error). With neither, the first of
these that exists is opened:

1.  the file named by the `AUSPARL_DB` environment variable;

2.  the copy installed by
    [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
    in the user data directory, for the database version this release of
    ausparl pins;

3.  the full database opened earlier in this R session (never the
    bundled sample);

4.  `hansard.duckdb` in the working directory, then in its `dataset/`
    folder, as `db_download(dir = ".")` and
    `db_download(dir = "dataset")` leave it.

A message says which file was opened in cases 2 to 4. `db_connect()`
never downloads anything itself.

On connect the DuckDB full-text-search extension (`fts`) is loaded. If
it is not installed yet, it is installed once into
`tools::R_user_dir("ausparl", "cache")`, which needs network access.
Installation never happens during tests or `R CMD check`, and is
switched off with `options(ausparl.auto_install_fts = FALSE)`. Without
`fts` every other function works; full-text search reports how to
install it.

DuckDB's memory use is capped by the `ausparl.memory_limit` option,
default `"3GB"`. Accepted values are a size with a unit, such as
`"500MB"`, `"1.5GB"` or `"2GiB"`; anything else is an error and the
current connection stays open. The cap bounds query execution itself,
not just the results returned to R: a large query spills to disk rather
than exceeding it, so expect peak R process memory of roughly the cap
plus twice the result. Spill files go to an `ausparl-duckdb` directory
under [`tempdir()`](https://rdrr.io/r/base/tempfile.html), never beside
the database file, and are removed when the R session ends. Change the
option, then call `db_connect()` again to apply it.

## See also

[`db_disconnect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_disconnect.md),
[`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md),
[`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)

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
