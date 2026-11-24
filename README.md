# ausparl

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24491241.svg)](https://doi.org/10.5281/zenodo.24491241)

Query the Australian Hansard database from R.

## Overview

ausparl gives basic, reproducible access to the Australian Parliamentary Hansard, the record
of debates in the House of Representatives and the Senate since 1901, held in a pre-built
DuckDB database. With it you can:

- filter sittings, speeches and speaking turns by member, party, parliament, chamber and date;
- search speeches for words and phrases, with hit counts;
- add what was true of the speaker on the day (party, role, electorate, age, government or
  opposition);
- look up members: their service, parties, ministerial roles and background;
- summarise activity per member, party and parliament;
- hand results to [quanteda](https://quanteda.io) for text analysis.

Queries run inside the database and only the results come back into R. The database is opened
read-only.

## Installation

Install ausparl from GitHub with remotes:

```r
install.packages("remotes")
remotes::install_github("Australian-Parliamentary-Speech/ausparl")
```

To install a particular release, name its tag:

```r
remotes::install_github("Australian-Parliamentary-Speech/ausparl@v0.1.1")
```

This installs the package and the packages it depends on, including duckdb and quanteda.
R 4.1 or later is required. The Hansard database itself (about 9.5 GB) is separate: it is not
installed with the package, and it is never loaded into memory, because ausparl queries it on
disk.

## Getting the database

**Download it.** `db_download()` installs the database version this release of ausparl uses
(see [Versions](#versions)), checks its checksum, and resumes an interrupted download when run
again. By default it goes in your R user data directory, and `db_connect()` with no arguments
then opens it:

```r
library(ausparl)
db_download()
db_connect()
```

**Download it into a folder of your own**, such as the `dataset/` folder of a clone of this
repository, and open it by path:

```r
db_download(dir = "dataset")
db_connect(path = "dataset/hansard.duckdb")
```

**Use a copy you already have.** Pass its path, `db_connect(path = "/path/to/hansard.duckdb")`,
or set it once in `~/.Renviron` so that `db_connect()` finds it in every session:

```
AUSPARL_DB=/path/to/hansard.duckdb
```

You can open that file with `usethis::edit_r_environ()`; restart R after saving it. A `path`
you pass comes first, then `AUSPARL_DB`, then the copy `db_download()` installed in the user
data directory.

**Try it with the bundled sample** (eight sitting days, no download needed):

```r
db_connect(sample = TRUE)
```

## Example

```r
library(ausparl)
library(dplyr)
db_connect(sample = TRUE)

db_info()                                     # which database, which version

howard <- find_member("john howard")$PHID     # a member's identifier
member_profile(howard)$ministry_records       # their ministerial roles

# Speeches per parliament, counted inside the database
get_speeches(include_text = FALSE, collect = FALSE) |>
  count(parliament_id, chamber) |>
  arrange(parliament_id, chamber) |>
  collect()

# Mentions of a word by year
search_speeches_by_terms("government", include_text = FALSE, collect = FALSE) |>
  group_by(year = year(date)) |>
  summarise(n_turns = n(), n_mentions = sum(n_hits, na.rm = TRUE)) |>
  arrange(year) |>
  collect()

# A member's speeches, with their role on the day, as a quanteda corpus
get_speeches(member = howard, limit = 20) |>
  add_role() |>
  as_corpus()

db_disconnect()
```

Two vignettes go further: `vignette("ausparl")` walks through a full analysis, and
`vignette("database")` describes the database itself: its tables, identifiers, turn types,
speaker matching and provenance. The package help page, `?ausparl`, lists the functions by task
and the package options.

The documentation is also online at
<https://australian-parliamentary-speech.github.io/ausparl/>.

## Example code

The [`example/`](example) folder of this repository holds a worked example: a short, runnable
tour of the database and the package, from connecting to handing speeches to quanteda. To run
it, clone or download this repository and, from its top folder, either render
`example/walkthrough.qmd` with Quarto (`quarto render example/walkthrough.qmd`) or run the
plain R version, `source("example/walkthrough.R")`. It uses the full database in `dataset/` if
you have downloaded it there with `ausparl::db_download(dir = "dataset")`, and otherwise the
sample bundled with the package. Details are in [`example/README.md`](example/README.md).

## Main functions

Most query functions take `collect` (`TRUE` returns a tibble; `FALSE` a lazy table you can
keep filtering and summarising in the database), `limit` and `columns`. Interjections are left
out of speech results unless you ask for them.

| Area | Functions |
|---|---|
| Connection | `db_download()`, `db_connect()`, `db_disconnect()`, `db_info()`, `db_con()`, `db_tbl()` |
| Speeches and search | `get_speeches()`, `get_speech_turns()`, `search_speeches_by_terms()`, `get_sitting_timeline()`, `get_interjections()` |
| Members | `find_member()`, `member_profile()` |
| Activity summaries | `member_activity()`, `party_activity()`, `parliament_summary()` |
| Context on the day | `add_party()`, `add_role()`, `add_government_status()`, `add_electorate()`, `add_age()`, `add_member()`, `add_debate()` |
| Tables | `get_sittings()`, `get_debates()`, `get_subdebates()`, `get_actions()`, `get_members()`, `get_parliaments()`, `get_parties()`, `get_party_service()`, `get_parl_service()`, `get_electorates()`, `get_elections()`, `get_ministries()`, `get_ministry_records()`, `get_shadow_ministry_records()`, `get_committee_members()`, `get_presiding_officers()`, `get_occupations()`, `get_qualifications()`, `get_schools()`, `get_provenance()` |
| Filter helpers | `in_range()`, `matches_pattern()` |
| Outputs | `as_corpus()`, `result_provenance()` |

See `?function_name` for the arguments of each function.

## Versions

Each ausparl release uses one database version, and `db_download()` installs exactly that
version.

| ausparl | Package DOI | Database version | Database DOI |
|---|---|---|---|
| 0.1.1 | [10.5281/zenodo.24491242](https://doi.org/10.5281/zenodo.24491242) | 7.0.0-20261123 | [10.5281/zenodo.24452577](https://doi.org/10.5281/zenodo.24452577) |
| 0.1.0 | none | 7.0.0-20261123 | [10.5281/zenodo.24452577](https://doi.org/10.5281/zenodo.24452577) |

Each release from 0.1.1 is archived on Zenodo with its own DOI.
[10.5281/zenodo.24491241](https://doi.org/10.5281/zenodo.24491241) covers all versions and always resolves to the latest.

## Authors

Pat Leslie (maintainer), Marija Taflaga, Kenneth Benoit, Rohan Alexander, Keith Dowding and
Guangnan Zhu.

## Citation

If you use ausparl, please cite the version you used, and the database version it pins.
For this release:

> Leslie, P., Taflaga, M., Benoit, K., Alexander, R., Dowding, K. and Zhu, G. (2026).
> ausparl: Query the Australian Parliamentary Hansard Database. R package version 0.1.1.
> <https://doi.org/10.5281/zenodo.24491242>. Using Hansard database version 7.0.0-20261123
> (<https://doi.org/10.5281/zenodo.24452577>).

In R, `citation("ausparl")` gives the same citation for the version you have installed, with
a BibTeX entry (`toBibtex(citation("ausparl"))`). GitHub's *Cite this repository* button,
built from [`CITATION.cff`](CITATION.cff), gives it in APA and BibTeX.

For another version, find its DOI in the table under [Versions](#versions), or on
[Zenodo](https://doi.org/10.5281/zenodo.24491241). The citation records the package version
and the database version it pins, with the database's Zenodo DOI. Report the `schema_version` and `built_at` from `db_info()` as well.

## License

GPL (>= 3). The full text is in [`LICENSE.md`](LICENSE.md).

## Getting help

Report a problem or ask a question at
<https://github.com/Australian-Parliamentary-Speech/ausparl/issues>.
