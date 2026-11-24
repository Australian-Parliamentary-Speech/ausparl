# Changelog

## ausparl (development version)

- `db_download(background = TRUE)` downloads the database in the
  background, so you can keep working: as a background job in RStudio,
  or in a separate R process elsewhere.
- [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  keeps a lock file next to the partial download, so a second download
  into the same place cannot corrupt it. Calling
  [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  while one runs reports its progress.
- In a background job,
  [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  shows curl’s progress bar, which it otherwise shows only in
  interactive sessions.
- [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  no longer deletes the download when its checksum cannot be computed
  (the file is missing or unreadable, for example because a second
  download into the same place removed it). It keeps the partial file
  and says how to resume. It also says that the checksum step takes
  about a minute.

## ausparl 0.1.1

- Added authors: Pat Leslie, Marija Taflaga, Kenneth Benoit, Rohan
  Alexander and Keith Dowding, alongside Guangnan Zhu. Pat Leslie is now
  the maintainer.
- Tests pass with duckdb 2.x, which keeps one database instance per
  file: the raw test connection opens its own copy of the sample.
  [`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
  explains the error duckdb 2.x gives when another connection holds the
  file with different settings.
- Added `CITATION.cff` and a suggested citation in the README.
- The worked example in `example/` shows how to connect:
  `db_connect(sample = TRUE)` for the bundled sample, or
  `db_connect(path = )` for a full copy.
- New vignette,
  [`vignette("database")`](https://australian-parliamentary-speech.github.io/ausparl/articles/database.md):
  a guide to the tables, identifiers, turn types, speaker resolution,
  date-scoped context views and provenance of the Hansard database. It
  runs on the bundled sample database.
- The package help page,
  [`?ausparl`](https://australian-parliamentary-speech.github.io/ausparl/reference/ausparl-package.md),
  now gives an overview of the functions by task, the common arguments,
  the package options and the environment variables.
- `citation("ausparl")` lists all authors and the pinned database
  version and its DOI.
- Added a pkgdown configuration for a documentation website.

## ausparl 0.1.0

- First release: read-only query access to the Australian Hansard DuckDB
  database, with
  [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  for the pinned database version (7.0.0-20261123), table getters,
  speech and turn queries, full-text search, date-scoped context joins,
  activity summaries,
  [`as_corpus()`](https://australian-parliamentary-speech.github.io/ausparl/reference/as_corpus.md)
  for quanteda and
  [`result_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/result_provenance.md).
