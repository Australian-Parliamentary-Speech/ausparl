#' ausparl: Query the Australian Parliamentary Hansard Database
#'
#' @description
#' ausparl gives basic, reproducible query access to the Australian Parliamentary Hansard: the
#' record of debates in the House of Representatives and the Senate since 1901, held in a
#' pre-built DuckDB database and linked to members, parties, ministries and electorates from the
#' Parliamentary Handbook. Queries run inside the database and only their results come back into
#' R; the database is opened read-only and never loaded into memory.
#'
#' Start with `vignette("ausparl")` for a worked analysis, and `vignette("database")` for a guide
#' to the tables, identifiers and conventions of the database.
#'
#' @section Getting the database:
#' The full database (about 9.5 GB) is not installed with the package. [db_download()] fetches
#' the version this release pins from Zenodo and checks it, and [db_connect()] then opens it with
#' no arguments. A small sample database of eight sitting days is bundled for examples and tests:
#' `db_connect(sample = TRUE)`.
#'
#' [db_connect()] chooses the file in this order: an explicit `path` (or `sample = TRUE`), then
#' the `AUSPARL_DB` environment variable, then the copy installed by [db_download()]. Query
#' functions connect on first use if no connection is open.
#'
#' @section Functions by task:
#' * **Connection:** [db_download()], [db_connect()], [db_disconnect()], [db_info()],
#'   [db_con()], [db_tbl()].
#' * **Speeches and search:** [get_speeches()] (one row per action),
#'   [get_speech_turns()] (consecutive actions by one speaker merged into a turn),
#'   [search_speeches_by_terms()] (full-text search with hit counts),
#'   [get_sitting_timeline()] (a sitting in document order) and [get_interjections()] (who
#'   interrupted whom).
#' * **Members:** [find_member()] to look up a `PHID` by name, and [member_profile()] for
#'   everything recorded about one member.
#' * **Activity summaries:** [member_activity()], [party_activity()], [parliament_summary()].
#' * **Context on the day of a turn:** [add_party()], [add_role()], [add_government_status()],
#'   [add_electorate()], [add_age()], [add_member()], [add_debate()].
#' * **Tables:** one getter per table: [get_sittings()], [get_debates()], [get_subdebates()],
#'   [get_actions()], [get_members()], [get_parliaments()], [get_parties()],
#'   [get_party_service()], [get_parl_service()], [get_electorates()], [get_elections()],
#'   [get_ministries()], [get_ministry_records()], [get_shadow_ministry_records()],
#'   [get_committee_members()], [get_presiding_officers()], [get_occupations()],
#'   [get_qualifications()], [get_schools()] and [get_provenance()]. Any other table or view is
#'   available with [db_tbl()].
#' * **Filter helpers:** [in_range()] and [matches_pattern()], accepted by most filter
#'   arguments.
#' * **Outputs:** [as_corpus()] hands text to quanteda, and [result_provenance()] lists the
#'   source files behind a result.
#'
#' @section Common arguments:
#' Most query functions share three arguments:
#' * `collect`: `TRUE` (the default) returns a tibble; `FALSE` returns a lazy dplyr table that
#'   you can keep filtering, joining and summarising inside DuckDB before calling
#'   [dplyr::collect()].
#' * `limit`: the maximum number of rows to return, or `NULL` for no limit.
#' * `columns`: the columns to return, or `NULL` for all.
#'
#' Chamber arguments take `"house"` and/or `"senate"`, in any case. Date bounds (`from`, `to`)
#' take a year (covering the whole year), a `Date` or a `"YYYY-MM-DD"` string, and are inclusive.
#'
#' @section Package options:
#' * `ausparl.memory_limit`: the cap on DuckDB's memory use, a size such as `"1.5GB"`. Default
#'   `"3GB"`. Takes effect at the next [db_connect()].
#' * `ausparl.max_rows`: the most rows a result without speech text may collect into R; a larger
#'   result is an error that suggests `collect = FALSE`. Default 2,000,000. `Inf` switches the
#'   check off.
#' * `ausparl.max_rows_text`: the same ceiling for results that include the speech text
#'   (`content`). Default 800,000.
#' * `ausparl.auto_install_fts`: whether [db_connect()] may install DuckDB's full-text-search
#'   extension when it is missing (a one-off download). Default `TRUE`.
#'
#' @section Environment variables:
#' * `AUSPARL_DB`: path to a `hansard.duckdb` file, used by [db_connect()] when no `path` is
#'   given. Set it in `~/.Renviron` to use the same copy in every session.
#' * `R_USER_DATA_DIR`: moves the user data directory in which [db_download()] installs the
#'   database by default (see [tools::R_user_dir()]).
#'
#' @section Versions and citation:
#' Each ausparl release pins exactly one database version, recorded in the package
#' `DESCRIPTION` (`Config/ausparl/data_version`) and archived on Zenodo. [db_info()] reports the
#' version and build time of the database you are connected to; quote them in your methods. To
#' cite the package, run `citation("ausparl")`.
#'
"_PACKAGE"

# ggplot2 is imported so that installing ausparl also installs it for the plots in the
# examples, vignette and worked example; the package code itself draws nothing.
#' @importFrom ggplot2 ggplot
NULL
