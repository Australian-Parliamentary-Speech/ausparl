# Queries over the database's analysis views.
# Most views carry only ids, so their queries join them back to `actions`, `sittings` and
# `members`; v_speech_turns_context already carries its sitting and party columns.
# No turn-type default is applied: the default interjection exclusion covers action-level speech
# functions only.

#' Get interjections and their targets
#'
#' Reads the `v_interjection_target` view: one row per interjection, with the turn it interrupted.
#' The view holds only two action ids; this function joins them back to `actions`, `sittings` and
#' `members` to add the sitting, the chamber and both members.
#'
#' Every interjection in the view is returned, including those with no known interjector or no
#' target:
#' * `interjector_PHID` (and so `interjector_name`) is `NA` for presiding-officer interjections
#'   (`resolution = "sentinel"` in `actions`) and for unresolved interjections.
#' * `target_action_id` (and so `target_PHID` and `target_name`) is `NA` when no substantive turn
#'   precedes the interjection in its subdebate.
#'
#' The target is the first action of the contiguous substantive turn the interjection falls in:
#' consecutive non-interjection actions by the same member count as one turn. Names are each
#' member's current `members.DisplayName`, not their name at the time. Stored values are returned
#' unchanged.
#'
#' @param from,to Sitting-date bounds, inclusive: a year (covering the whole year), a `Date`, or a
#'   `"YYYY-MM-DD"` string. `NULL` leaves that end open.
#' @param chamber `"house"` and/or `"senate"`, in any case.
#' @param chamber_venue Filter on the interjection's `chamber_venue`: a vector of values or
#'   [in_range()].
#' @param interjector,target Character vector of member PHIDs (the interjecting member, or the
#'   member interrupted). A PHID that matches no member is an error; use `find_member()` to look
#'   one up.
#' @param columns Character vector of columns to return; `NULL` returns all.
#' @param collect If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for further
#'   dplyr work.
#' @param limit Maximum number of rows to return, or `NULL` for no limit.
#' @return A tibble with one row per interjection and columns `interjection_action_id`,
#'   `target_action_id`, `sitting_id`, `date`, `chamber`, `chamber_venue`, `interjector_PHID`,
#'   `interjector_name`, `target_PHID`, `target_name` and `interjection_type` (the interjection's
#'   `action_type`: `"speech"` or `"unresolved_interjection"`). Zero rows if nothing matches; a lazy
#'   table if `collect = FALSE`.
#' @seealso [get_sitting_timeline()], [in_range()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' get_interjections(from = 2019, to = 2019)
#' get_interjections(chamber = "Senate", columns = c("interjector_name", "target_name"))
#' db_disconnect()
get_interjections <- function(from = NULL, to = NULL, chamber = NULL, chamber_venue = NULL,
                              interjector = NULL, target = NULL,
                              columns = NULL, collect = TRUE, limit = NULL) {
  call <- rlang::current_env()
  filters <- list(chamber_venue = chamber_venue)
  check_getter_args(filters, 0L, collect = collect, limit = limit, call = call)
  bounds <- date_bounds(from, to, call = call)
  filters$chamber <- normalise_chamber(chamber, call = call)
  check_phids(interjector, "interjector", call)
  check_phids(target, "target", call)
  check_known_phids(c(interjector, target), call)

  tbl <- interjections_tbl()
  tbl <- filter_args(tbl, filters, call = call)
  tbl <- filter_args(tbl, list(interjector_PHID = interjector, target_PHID = target), call = call)
  if (!is.null(bounds$from)) {
    tbl <- dplyr::filter(tbl, !!rlang::sym("date") >= !!bounds$from)
  }
  if (!is.null(bounds$to)) {
    tbl <- dplyr::filter(tbl, !!rlang::sym("date") <= !!bounds$to)
  }
  tbl <- select_columns(tbl, columns, call = call)
  collect_result(tbl, collect = collect, limit = limit, call = call)
}

#' Get the turns of a sitting in order
#'
#' Reads the `v_sitting_timeline` view: one row per action (turn), in document order. The view is
#' joined to `sittings` for the date and chamber and, when `include_text = TRUE`, to `actions` for
#' the text.
#'
#' A collected result is ordered by `sitting_id` and then `seq`, the action's position in the
#' sitting, and `limit` keeps the first rows in that order. The lazy table (`collect = FALSE`) is
#' unordered, so it can be aggregated in DuckDB (for example with `dplyr::count()`); add
#' `dplyr::arrange(sitting_id, seq)` if you need the order. `speaker_name` is the member's current
#' `members.DisplayName`, not their name at the time, and is `NA` where the action has no PHID.
#' Stored values are returned unchanged, and no turn-type filter is applied.
#'
#' @param sitting_id Filter on `sitting_id`: a vector of values or [matches_pattern()].
#' @param date Sitting date: a `Date` or `"YYYY-MM-DD"` string, a vector of them, or [in_range()]
#'   (a year bound covers the whole year).
#' @param chamber `"house"` and/or `"senate"`, in any case.
#' @param include_text If `TRUE` (the default), add the `content` column. Results with `content`
#'   are held to the lower size ceiling, `getOption("ausparl.max_rows_text")`.
#' @inheritParams get_interjections
#' @return A tibble with one row per action, ordered by `sitting_id` then `seq`, with columns
#'   `sitting_id`, `date`, `chamber`, `seq`, `action_id`, `debate_title`, `subdebate_title`,
#'   `action_type`, `PHID`, `speaker_name`, and `content` when `include_text = TRUE`. Zero rows if
#'   nothing matches. With `collect = FALSE`, an unordered lazy table with the same columns.
#' @seealso [get_interjections()], [get_sittings()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' get_sitting_timeline(sitting_id = "house_2002-10-15", include_text = FALSE)
#' get_sitting_timeline(date = in_range("2019-01-01", "2019-12-31"), limit = 5)
#' db_disconnect()
get_sitting_timeline <- function(sitting_id = NULL, date = NULL, chamber = NULL,
                                 include_text = TRUE, columns = NULL, collect = TRUE,
                                 limit = NULL) {
  call <- rlang::current_env()
  filters <- list(sitting_id = sitting_id)
  check_getter_args(filters, 0L, collect = collect, limit = limit, call = call)
  if (!rlang::is_bool(include_text)) {
    abort_input(c(
      "{.arg include_text} must be {.code TRUE} or {.code FALSE}.",
      "x" = "It is {.obj_type_friendly {include_text}}."
    ), call = call)
  }
  filters$date <- timeline_dates(date, call)
  filters$chamber <- normalise_chamber(chamber, call = call)

  tbl <- timeline_tbl(include_text)
  tbl <- filter_args(tbl, filters, call = call)
  # Order only what is collected (so `limit` keeps the first rows in timeline order): dbplyr would
  # carry an ORDER BY on the lazy table into later aggregates, which DuckDB rejects.
  if (isTRUE(collect)) {
    tbl <- dplyr::arrange(tbl, !!!rlang::syms(c("sitting_id", "seq")))
  }
  tbl <- select_columns(tbl, columns, call = call)
  collect_result(tbl, collect = collect, limit = limit, call = call)
}

#' Get speech turns: consecutive actions by one speaker, merged
#'
#' Reads the `v_speech_turns_context` view: one row per turn, where a turn is the run of
#' consecutive actions in a sitting that share a `turn_no` (actions with a missing or zero
#' `turn_no`, and non-speech actions, belong to no turn). The view carries the sitting's date,
#' chamber and parliament, the turn's first action's `name_raw`, and the party at the time.
#'
#' **Turns, not actions.** [get_speeches()] and [get_actions()] return one row per action: a
#' speech broken by interjections or continued across pages is several rows there. Here it is one
#' row, `n_actions` says how many actions it merges, and `content` is their text joined with a
#' blank line (`"\n\n"`), in document order. The turn is identified by `sitting_id` and
#' `turn_no`; `first_action_id` is the id of its first action, for joining back to action-level
#' tables. No turn-type filter is applied: every turn in the view is returned, whatever its
#' actions' types.
#'
#' **Quoted passages.** Two columns describe quotations, computed over the turn's actions:
#' * `has_quote` is `TRUE` when any action in the turn is flagged as containing quoted material
#'   (`actions.has_quote`). It is coarse: the turn quotes something somewhere.
#' * `is_quote` is `TRUE` when every action in the turn is a quote (`action_type = "quote"`): the
#'   whole turn is a passage read into the record, not the speaker's own words.
#'
#' Turns that are read-out passages are kept; drop them with `dplyr::filter(!is_quote)`.
#'
#' **Speaker.** `PHID`, `name_raw` and `resolution` are those of the turn's first action.
#' Turns by the presiding officer (`resolution = "sentinel"`), and turns whose speaker is not one
#' matched member (`"collective"`, `"unknown"`, `"unmatched"`, `"ambiguous"`, `"non_member"`, or
#' a missing resolution), are all kept, with `PHID` `NA` where there is no member. A `member`
#' filter keeps only the turns of those members. `resolution` filters on the stored values and
#' cannot select a missing (`NA`) resolution: such turns are returned only when `resolution =
#' NULL`; to keep only them, use `collect = FALSE` and `dplyr::filter(is.na(resolution))`.
#'
#' **Party.** `party_at_time` is the party of the turn's first action's speaker on the sitting
#' date, not the member's current party, and `party_id_at_time` its `party_id`. `party` is
#' resolved as in [get_speeches()].
#'
#' **Order and laziness.** A collected result is ordered by `sitting_id` and then `turn_no`, and
#' `limit` keeps the first rows in that order. With `collect = FALSE` the result is an unordered
#' lazy table that works as a parameterised view: filter, join and aggregate it in DuckDB (for
#' example with `dplyr::count()`) before collecting. Stored values are returned unchanged.
#'
#' @param member Character vector of member PHIDs, matched against the turn's `PHID`. A PHID that
#'   matches no member is an error; look one up with [find_member()].
#' @param party Party ids (numbers) or party names or abbreviations (strings), matched against
#'   the party at the time; see [get_speeches()].
#' @param parliament_id Filter on the sitting's `parliament_id`: a vector of values or
#'   [in_range()].
#' @param sitting_id Filter on `sitting_id`: a vector of values or [matches_pattern()].
#' @param resolution Filter on the turn's `resolution`: a character vector of values such as
#'   `"resolved"` or `"sentinel"`, or [matches_pattern()]. `NA` is not accepted; see Details.
#' @param include_text If `TRUE` (the default), add the `content` column. Results with `content`
#'   are held to the lower size ceiling, `getOption("ausparl.max_rows_text")`.
#' @inheritParams get_speeches
#' @return A tibble with one row per turn, ordered by `sitting_id` then `turn_no`, with columns
#'   `sitting_id`, `date`, `chamber`, `parliament_id`, `turn_no`, `first_action_id`, `n_actions`,
#'   `PHID`, `name_raw`, `resolution`, `party_id_at_time`, `party_at_time`, `has_quote`,
#'   `is_quote`, and `content` when `include_text = TRUE`. Zero rows if nothing matches. With
#'   `collect = FALSE`, an unordered lazy table with the same columns.
#' @seealso [get_speeches()], [get_sitting_timeline()], [find_member()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' get_speech_turns(party = "ALP", from = 2002, to = 2002, include_text = FALSE)
#' howard <- find_member("john howard")$PHID
#' get_speech_turns(member = howard, columns = c("date", "n_actions", "is_quote"))
#' db_disconnect()
get_speech_turns <- function(member = NULL, party = NULL, parliament_id = NULL, chamber = NULL,
                             from = NULL, to = NULL, sitting_id = NULL, resolution = NULL,
                             include_text = TRUE, columns = NULL, collect = TRUE, limit = NULL) {
  call <- rlang::current_env()
  filters <- list(parliament_id = parliament_id, sitting_id = sitting_id, resolution = resolution)
  check_getter_args(filters, 0L, collect = collect, limit = limit, call = call)
  bounds <- date_bounds(from, to, call = call)
  filters$chamber <- normalise_chamber(chamber, call = call)
  check_flag(include_text, "include_text", call)
  check_phids(member, "member", call)
  party <- check_party(party, call)
  check_members_exist(member, call)
  party_ids <- resolve_party(party, call)

  tbl <- speech_turns_tbl(include_text)
  tbl <- filter_args(tbl, filters, call = call)
  tbl <- filter_args(tbl, list(PHID = member), call = call)
  if (!is.null(bounds$from)) {
    tbl <- dplyr::filter(tbl, !!rlang::sym("date") >= !!bounds$from)
  }
  if (!is.null(bounds$to)) {
    tbl <- dplyr::filter(tbl, !!rlang::sym("date") <= !!bounds$to)
  }
  if (!is.null(party_ids)) {
    tbl <- filter_args(tbl, list(party_id_at_time = party_ids), call = call)
  }
  # As in get_sitting_timeline(): order only what is collected.
  if (isTRUE(collect)) {
    tbl <- dplyr::arrange(tbl, !!!rlang::syms(c("sitting_id", "turn_no")))
  }
  tbl <- select_columns(tbl, columns, call = call)
  collect_result(tbl, collect = collect, limit = limit, call = call)
}

# ---- internals ----------------------------------------------------------------------------------

# v_interjection_target joined to the interjection row, the target row (left: the target may be
# NULL), the sitting, and both members (left: either PHID may be NULL).
interjections_tbl <- function() {
  actions <- db_tbl("actions")
  interjection <- dplyr::select(actions,
    interjection_action_id = "action_id", "sitting_id", "chamber_venue",
    interjector_PHID = "PHID", interjection_type = "action_type"
  )
  target <- dplyr::select(actions, target_action_id = "action_id", target_PHID = "PHID")
  sittings <- dplyr::select(db_tbl("sittings"), "sitting_id", "date", "chamber")
  members <- db_tbl("members")
  interjector <- dplyr::select(members,
    interjector_PHID = "PHID", interjector_name = "DisplayName"
  )
  target_member <- dplyr::select(members, target_PHID = "PHID", target_name = "DisplayName")

  db_tbl("v_interjection_target") |>
    dplyr::inner_join(interjection, by = "interjection_action_id") |>
    dplyr::left_join(target, by = "target_action_id") |>
    dplyr::inner_join(sittings, by = "sitting_id") |>
    dplyr::left_join(interjector, by = "interjector_PHID") |>
    dplyr::left_join(target_member, by = "target_PHID") |>
    dplyr::select(
      "interjection_action_id", "target_action_id", "sitting_id", "date", "chamber",
      "chamber_venue", "interjector_PHID", "interjector_name", "target_PHID", "target_name",
      "interjection_type"
    )
}

# v_sitting_timeline joined to the sitting, and to actions for content when asked.
timeline_tbl <- function(include_text) {
  sittings <- dplyr::select(db_tbl("sittings"), "sitting_id", "date", "chamber")
  tbl <- dplyr::inner_join(db_tbl("v_sitting_timeline"), sittings, by = "sitting_id")
  cols <- c(
    "sitting_id", "date", "chamber", "seq", "action_id", "debate_title", "subdebate_title",
    "action_type", "PHID", "speaker_name"
  )
  if (include_text) {
    content <- dplyr::select(db_tbl("actions"), "action_id", "content")
    tbl <- dplyr::left_join(tbl, content, by = "action_id")
    cols <- c(cols, "content")
  }
  dplyr::select(tbl, dplyr::all_of(cols))
}

speech_turn_cols <- c(
  "sitting_id", "date", "chamber", "parliament_id", "turn_no", "first_action_id", "n_actions",
  "PHID", "name_raw", "resolution", "party_id_at_time", "party_at_time", "has_quote", "is_quote"
)

# v_speech_turns_context carries the sitting, the first action's name_raw and party at the time,
# and the per-turn quote flags.
speech_turns_tbl <- function(include_text) {
  dplyr::select(
    db_tbl("v_speech_turns_context"),
    dplyr::all_of(c(speech_turn_cols, if (include_text) "content"))
  )
}

# PHID arguments: a character vector without NA or empty strings. Ranges and patterns are refused.
check_phids <- function(x, arg, call) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x) || length(x) == 0 || anyNA(x) || !all(nzchar(x))) {
    abort_input(c(
      "{.arg {arg}} must be a character vector of member PHIDs.",
      "x" = "It is {.obj_type_friendly {x}}.",
      "i" = "Look a member's PHID up with {.code find_member()}."
    ), call = call)
  }
  invisible()
}

# Every PHID given must exist in `members`; one query, only the matched ids reach R.
check_known_phids <- function(phids, call) {
  phids <- unique(phids)
  if (length(phids) == 0) {
    return(invisible())
  }
  members <- db_tbl("members")
  known <- run_query(function() {
    members |>
      dplyr::filter(!!rlang::sym("PHID") %in% !!phids) |>
      dplyr::distinct(!!rlang::sym("PHID")) |>
      dplyr::pull("PHID")
  }, call)
  unknown <- setdiff(phids, known)
  if (length(unknown)) {
    abort_not_found(c(
      "No member has PHID {.val {unknown}}.",
      "i" = "Look a member's PHID up with {.code find_member()}."
    ), call = call)
  }
  invisible()
}

# `date` for the timeline: Dates or date strings (as Dates), or in_range() bounds as Dates.
timeline_dates <- function(date, call) {
  if (is.null(date)) {
    return(NULL)
  }
  if (inherits(date, "ausparl_range")) {
    bounds <- date_bounds(date$from, date$to, call = call)
    return(structure(bounds, class = "ausparl_range"))
  }
  if (inherits(date, "Date") && length(date) > 0 && !anyNA(date)) {
    return(date)
  }
  if (is.character(date) && length(date) > 0 && !anyNA(date)) {
    parsed <- as.Date(date, format = "%Y-%m-%d")
    if (all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date)) && !anyNA(parsed)) {
      return(parsed)
    }
  }
  abort_input(c(
    "{.arg date} must be dates ({.cls Date} or {.val YYYY-MM-DD} strings) or {.fn in_range}.",
    "x" = "It is {.obj_type_friendly {date}}.",
    "i" = "For example {.code date = \"1996-05-02\"} or {.code date = in_range(1996, 1997)}."
  ), call = call)
}
