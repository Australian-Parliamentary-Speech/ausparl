# Download the Hansard database

Downloads the full Hansard database that this version of ausparl was
released with, from its Zenodo version record. The file is about 9.5 GB.
An interrupted download resumes where it stopped when you call
`db_download()` again with the same arguments. The file is installed
only once its MD5 checksum matches the one Zenodo lists.

## Usage

``` r
db_download(force = FALSE, dir = NULL)
```

## Arguments

- force:

  If `TRUE`, download again even when a verified copy is already
  installed.

- dir:

  A directory to install the database in, as a single string. `NULL`
  (the default) uses the ausparl user data directory.

## Value

The path of the installed database file, invisibly.

## Details

**Where it goes.** By default the database is installed in the ausparl
user data directory (`tools::R_user_dir("ausparl", "data")`; set the
`R_USER_DATA_DIR` environment variable to move it), and
[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
with no arguments then opens it, unless you pass `path`, `sample = TRUE`
or set the `AUSPARL_DB` environment variable, which take precedence.

With `dir`, the database is installed directly in that directory as
`hansard.duckdb` (the directory is created if needed), for example
`db_download(dir = "dataset")` in a project folder.
[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
does not look there by itself: open that copy with
`db_connect(path = file.path(dir, "hansard.duckdb"))` or by setting
`AUSPARL_DB` to it. A verified copy of the same database version already
in `dir` is reused; a copy of another version is replaced.

[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
never downloads anything itself. Each ausparl release pins exactly one
database version, so an older ausparl never fetches a newer database it
cannot read. To use a different database version, install the ausparl
release that pins it.

## See also

[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md),
[`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# About 9.5 GB; run once per database version.
db_download()
db_connect()
db_info()
db_disconnect()

# Or into a folder of your project, then open it by path.
path <- db_download(dir = "dataset")
db_connect(path = path)
} # }
```
