# ausparl: Query the Australian Parliamentary Hansard Database

ausparl gives basic, reproducible query access to the Australian
Parliamentary Hansard: the record of debates in the House of
Representatives and the Senate since 1901, held in a pre-built DuckDB
database and linked to members, parties, ministries and electorates from
the Parliamentary Handbook. Queries run inside the database and only
their results come back into R; the database is opened read-only and
never loaded into memory.

Start with
[`vignette("database")`](https://australian-parliamentary-speech.github.io/ausparl/articles/database.md),
a guide to the tables, identifiers and conventions of the database.

## Getting the database

The full database (about 9.5 GB) is not installed with the package.
[`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
fetches the version this release pins from Zenodo and checks it, and
[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
then opens it with no arguments. A small sample database of eight
sitting days is bundled for examples and tests:
`db_connect(sample = TRUE)`.

[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
chooses the file in this order: an explicit `path` (or `sample = TRUE`),
then the `AUSPARL_DB` environment variable, then the copy installed by
[`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md),
then the full database used earlier in the session, then
`hansard.duckdb` in the working directory or its `dataset/` folder.
Query functions connect on first use if no connection is open.

## Functions by task

- **Connection:**
  [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md),
  [`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md),
  [`db_disconnect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_disconnect.md),
  [`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md),
  [`db_con()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_con.md),
  [`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md).

- **Speeches and search:**
  [`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
  (one row per action),
  [`get_speech_turns()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speech_turns.md)
  (consecutive actions by one speaker merged into a turn),
  [`search_speeches_by_terms()`](https://australian-parliamentary-speech.github.io/ausparl/reference/search_speeches_by_terms.md)
  (full-text search with hit counts),
  [`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md)
  (a sitting in document order) and
  [`get_interjections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_interjections.md)
  (who interrupted whom).

- **Members:**
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md)
  to look up a `PHID` by name, and
  [`member_profile()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_profile.md)
  for everything recorded about one member.

- **Activity summaries:**
  [`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md),
  [`party_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/party_activity.md),
  [`parliament_summary()`](https://australian-parliamentary-speech.github.io/ausparl/reference/parliament_summary.md).

- **Context on the day of a turn:**
  [`add_party()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_party.md),
  [`add_role()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_role.md),
  [`add_government_status()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_government_status.md),
  [`add_electorate()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_electorate.md),
  [`add_age()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_age.md),
  [`add_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_member.md),
  [`add_debate()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_debate.md).

- **Tables:** one getter per table:
  [`get_sittings()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sittings.md),
  [`get_debates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_debates.md),
  [`get_subdebates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_subdebates.md),
  [`get_actions()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_actions.md),
  [`get_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_members.md),
  [`get_parliaments()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parliaments.md),
  [`get_parties()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parties.md),
  [`get_party_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_party_service.md),
  [`get_parl_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parl_service.md),
  [`get_electorates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_electorates.md),
  [`get_elections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_elections.md),
  [`get_ministries()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministries.md),
  [`get_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministry_records.md),
  [`get_shadow_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_shadow_ministry_records.md),
  [`get_committee_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_committee_members.md),
  [`get_presiding_officers()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_presiding_officers.md),
  [`get_occupations()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_occupations.md),
  [`get_qualifications()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_qualifications.md),
  [`get_schools()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_schools.md)
  and
  [`get_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_provenance.md).
  Any other table or view is available with
  [`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md).

- **Filter helpers:**
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
  and
  [`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md),
  accepted by most filter arguments.

- **Outputs:**
  [`as_corpus()`](https://australian-parliamentary-speech.github.io/ausparl/reference/as_corpus.md)
  hands text to quanteda, and
  [`result_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/result_provenance.md)
  lists the source files behind a result.

## Common arguments

Most query functions share three arguments:

- `collect`: `TRUE` (the default) returns a tibble; `FALSE` returns a
  lazy dplyr table that you can keep filtering, joining and summarising
  inside DuckDB before calling
  [`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html).

- `limit`: the maximum number of rows to return, or `NULL` for no limit.

- `columns`: the columns to return, or `NULL` for all.

Chamber arguments take `"house"` and/or `"senate"`, in any case. Date
bounds (`from`, `to`) take a year (covering the whole year), a `Date` or
a `"YYYY-MM-DD"` string, and are inclusive.

## Package options

- `ausparl.memory_limit`: the cap on DuckDB's memory use, a size such as
  `"1.5GB"`. Default `"3GB"`. Takes effect at the next
  [`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md).

- `ausparl.max_rows`: the most rows a result without speech text may
  collect into R; a larger result is an error that suggests
  `collect = FALSE`. Default 2,000,000. `Inf` switches the check off.

- `ausparl.max_rows_text`: the same ceiling for results that include the
  speech text (`content`). Default 800,000.

- `ausparl.auto_install_fts`: whether
  [`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
  may install DuckDB's full-text-search extension when it is missing (a
  one-off download). Default `TRUE`.

## Environment variables

- `AUSPARL_DB`: path to a `hansard.duckdb` file, used by
  [`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
  when no `path` is given. Set it in `~/.Renviron` to use the same copy
  in every session.

- `R_USER_DATA_DIR`: moves the user data directory in which
  [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  installs the database by default (see
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)).

## Versions and citation

Each ausparl release pins exactly one database version, recorded in the
package `DESCRIPTION` (`Config/ausparl/data_version`) and archived on
Zenodo.
[`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md)
reports the version and build time of the database you are connected to;
quote them in your methods. To cite the package, run
`citation("ausparl")`.

## See also

Useful links:

- <https://github.com/Australian-Parliamentary-Speech/ausparl>

- <https://australian-parliamentary-speech.github.io/ausparl/>

- Report bugs at
  <https://github.com/Australian-Parliamentary-Speech/ausparl/issues>

## Author

**Maintainer**: Pat Leslie <patrick.leslie@anu.edu.au>
([ORCID](https://orcid.org/0000-0002-9218-8981))

Authors:

- Pat Leslie <patrick.leslie@anu.edu.au>
  ([ORCID](https://orcid.org/0000-0002-9218-8981))

- Marija Taflaga

- Kenneth Benoit

- Rohan Alexander

- Keith Dowding

- Guangnan Zhu <Guangnan.Zhu@anu.edu.au>
