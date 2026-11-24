# ausparl (development version)

* Added authors: Pat Leslie, Marija Taflaga, Kenneth Benoit, Rohan Alexander and Keith
  Dowding, alongside Guangnan Zhu (maintainer).
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
