# ausparl (development version)

* `db_download(background = TRUE)` downloads the database in the background, so you can keep
  working: as a background job in RStudio, or in a separate R process elsewhere.
* `db_download()` keeps a lock file next to the partial download, so a second download into the
  same place cannot corrupt it. Calling `db_download()` while one runs reports its progress.
* In a background job, `db_download()` shows curl's progress bar, which it otherwise shows only
  in interactive sessions.

# ausparl 0.1.1

* Added authors: Pat Leslie, Marija Taflaga, Kenneth Benoit, Rohan Alexander and Keith
  Dowding, alongside Guangnan Zhu. Pat Leslie is now the maintainer.
* Tests pass with duckdb 2.x, which keeps one database instance per file: the raw test
  connection opens its own copy of the sample. `db_connect()` explains the error duckdb 2.x
  gives when another connection holds the file with different settings.
* Added `CITATION.cff` and a suggested citation in the README.
* The worked example in `example/` shows how to connect: `db_connect(sample = TRUE)` for the
  bundled sample, or `db_connect(path = )` for a full copy.
* New vignette, `vignette("database")`: a guide to the tables, identifiers, turn types, speaker
  resolution, date-scoped context views and provenance of the Hansard database. It runs on the
  bundled sample database.
* The package help page, `?ausparl`, now gives an overview of the functions by task, the
  common arguments, the package options and the environment variables.
* `citation("ausparl")` lists all authors and the pinned database version and its DOI.
* Added a pkgdown configuration for a documentation website.

# ausparl 0.1.0

* First release: read-only query access to the Australian Hansard DuckDB database, with
  `db_download()` for the pinned database version (7.0.0-20261123), table getters, speech and
  turn queries, full-text search, date-scoped context joins, activity summaries,
  `as_corpus()` for quanteda and `result_provenance()`.
