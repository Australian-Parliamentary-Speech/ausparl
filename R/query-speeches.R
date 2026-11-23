# Member lookup and turn-level speech queries. Identified interjections are excluded unless
# "interjection" is requested. `speech_query()` is the shared builder that term search also
# reuses: it validates the shared filter arguments, runs the PHID and party lookups, and returns
# the lazy turn table before column selection and collection.

speech_types <- c(
  speech = "is_speech", question = "is_question", answer = "is_answer",
  interjection = "is_interjection"
)
speech_type_default <- c("speech", "question", "answer")

speech_flag_cols <- c(
  "is_speech", "is_question", "is_answer", "is_interjection", "is_non_speech", "is_petition",
  "is_motion_no_speech", "has_quote"
)
speech_cols <- c(
  "action_id", "sitting_id", "date", "chamber", "chamber_venue", "parliament_id",
  "PHID", "name_raw", "party_id_at_time", "party_at_time", speech_flag_cols
)

#' Find members by name
#'
#' Looks members up by name and returns their PHIDs, the member ids every other function takes.
#'
#' `name` is split on whitespace, and every piece must occur somewhere in `members.DisplayName`,
#' ignoring case and in any order. `DisplayName` is stored as, for example,
#' `"HOWARD, the Hon. John Winston, AC"`, so `"john howard"`, `"Howard John"` and `"howard"` all
#' find it. Characters such as `%` and `_` are matched literally.
#'
#' `chamber` and `active_during` keep only people with a period of parliamentary service
#' (`parl_service`) in that chamber and overlapping that period. Service as a Member is the
#' House and as a Senator the Senate. With neither filter, members without any recorded service
#' are kept too.
#'
#' @param name A single string: one or more name pieces separated by spaces.
#' @param chamber `"house"` and/or `"senate"`, in any case.
#' @param active_during A year, a `Date`, a `"YYYY-MM-DD"` string, or [in_range()]: keep people
#'   whose service overlaps it. A service with no end date counts as ongoing.
#' @return A tibble with one row per matching member, ordered by `DisplayName`, with columns
#'   `PHID`, `DisplayName`, `Gender`, `DateOfBirth`, `State`, `chambers` (the chambers the person
#'   ever served in, such as `"house, senate"`), `first_service` (the earliest service start) and
#'   `last_service` (the latest service end, `NA` while any service is ongoing or has no end
#'   date). The three service columns describe all of the person's service, whatever the filters.
#'   Zero rows if nobody matches; that is not an error.
#' @seealso [get_speeches()], [get_members()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' find_member("john howard")
#' find_member("peter", chamber = "house", active_during = 2012)
#' db_disconnect()
find_member <- function(name, chamber = NULL, active_during = NULL) {
  call <- rlang::current_env()
  tokens <- name_tokens(name, call)
  chamber <- normalise_chamber(chamber, call = call)
  check_getter_args(list(), 0L, active_during = active_during, call = call)
  tbl <- find_member_query(tokens, chamber, active_during, call)
  out <- collect_result(tbl, call = call)
  out[order(out$DisplayName, out$PHID, method = "radix"), , drop = FALSE]
}

# The lazy member lookup, from validated arguments.
find_member_query <- function(tokens, chamber, active_during, call) {
  members <- db_tbl("members")
  for (token in tokens) {
    pattern <- paste0("%", escape_like(token), "%")
    match <- rlang::call2("ilike_escape", rlang::sym("DisplayName"), pattern, "\\")
    members <- dplyr::filter(members, !!match)
  }

  service <- service_tbl()
  if (!is.null(chamber) || !is.null(active_during)) {
    active <- filter_args(service, list(chamber = chamber), call = call)
    active <- filter_active_during(active, active_during, "DateStart", "DateEnd", call = call)
    members <- dplyr::semi_join(members, active, by = "PHID")
  }

  members |>
    dplyr::left_join(service_summary(service), by = "PHID") |>
    dplyr::select(
      "PHID", "DisplayName", "Gender", "DateOfBirth", "State", "chambers", "first_service",
      "last_service"
    )
}

#' Get speeches and other turns
#'
#' Returns turns (actions) from the `v_speech` view, the substantive turns of debate, filtered by
#' research criteria. Each row is one turn, with its sitting, its speaker and the speaker's party
#' at the time.
#'
#' **Turn types.** `type` is resolved over flag columns, never `action_type`: `"speech"` keeps
#' rows with `is_speech`, `"question"` `is_question`, `"answer"` `is_answer` and `"interjection"`
#' `is_interjection`, combined with OR. A row with `is_interjection = TRUE` is left out unless
#' `"interjection"` is in `type`, even when another requested flag is also set. So by default no
#' interjections are returned; `type = "interjection"` returns only interjections.
#'
#' **Quoted passages.** `v_speech` also holds `action_type = "quote"` rows: a passage read into
#' the record. None of the four type flags is set on them, so they are never returned here; read
#' them with [get_actions()] (`action_type = "quote"`). A quote that names no reader has a
#' missing (`NA`) `resolution`.
#'
#' **Presiding officers and speakers who are not one member.** Turns by the presiding officer
#' (`resolution = "sentinel"` in `actions`) have no PHID and are left out unless
#' `include_presiding = TRUE`. These turns also have no PHID, and are kept with `PHID` and the
#' party columns `NA`:
#' * `resolution = "unmatched"`: a named speaker who could not be matched to a member.
#' * `"unknown"`: the source records the speaker as unknown.
#' * `"collective"`: a group speaking together, such as the Opposition or "Honourable members".
#' * `"non_member"`: a speaker who is not a member, such as the Governor-General or a visitor.
#'
#' A `member` filter drops all of these.
#'
#' **Party.** `party_at_time` is the speaker's party on the sitting date, and `party_id_at_time`
#' its `party_id`. `party` filters on the party at the time,
#' by id or name, resolved in this order, ignoring case:
#' 1. A number is a `party_id`.
#' 2. A string matching a party's `Abbrev` or `Name` exactly selects that party. If it matches
#'    several (for example `"LIB"`), it is an error listing their ids; pass the id instead.
#' 3. Otherwise a string that occurs in exactly one party's `Name` selects that party. If it
#'    occurs in several (for example `"Labor"`) it is an error listing them, and if in none,
#'    an error saying so.
#'
#' Party lineage is not followed: `"ALP"` is party 1 only, not its splinter parties. Stored
#' values are returned unchanged.
#'
#' @param member Character vector of member PHIDs. A PHID that matches no member is an error;
#'   look one up with [find_member()].
#' @param party Party ids (numbers) or party names or abbreviations (strings); see Details.
#' @param parliament_id Filter on the sitting's `parliament_id`: a vector of values or
#'   [in_range()].
#' @param chamber `"house"` and/or `"senate"`, in any case.
#' @param chamber_venue Filter on the turn's `chamber_venue`: a vector of values or [in_range()].
#' @param from,to Sitting-date bounds, inclusive: a year (covering the whole year), a `Date`, or a
#'   `"YYYY-MM-DD"` string. `NULL` leaves that end open.
#' @param type Turn types to return: any of `"speech"`, `"question"`, `"answer"` and
#'   `"interjection"`. Defaults to all but `"interjection"`.
#' @param include_presiding If `TRUE`, also return presiding-officer turns.
#' @param include_text If `TRUE` (the default), add the `content` column. Results with `content`
#'   are held to the lower size ceiling, `getOption("ausparl.max_rows_text")`.
#' @inheritParams get_interjections
#' @return A tibble with one row per turn and columns `action_id`, `sitting_id`, `date`,
#'   `chamber`, `chamber_venue`, `parliament_id`, `PHID`, `name_raw`, `party_id_at_time`,
#'   `party_at_time`, `is_speech`, `is_question`, `is_answer`, `is_interjection`,
#'   `is_non_speech`, `is_petition`, `is_motion_no_speech`, `has_quote`, and `content` when
#'   `include_text = TRUE`. Rows are not in any set order. Zero rows if nothing matches; a lazy
#'   table if `collect = FALSE`.
#' @seealso [find_member()], [get_sitting_timeline()], [get_interjections()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' howard <- find_member("john howard")$PHID
#' get_speeches(member = howard, include_text = FALSE)
#' get_speeches(party = "ALP", from = 2002, to = 2002, columns = c("date", "name_raw"))
#' get_speeches(type = "interjection", chamber = "senate", limit = 5)
#' db_disconnect()
get_speeches <- function(member = NULL, party = NULL, parliament_id = NULL, chamber = NULL,
                         chamber_venue = NULL, from = NULL, to = NULL,
                         type = c("speech", "question", "answer"),
                         include_presiding = FALSE, include_text = TRUE,
                         columns = NULL, collect = TRUE, limit = NULL) {
  call <- rlang::current_env()
  check_getter_args(list(), 0L, collect = collect, limit = limit, call = call)
  tbl <- speech_query(
    member = member, party = party, parliament_id = parliament_id, chamber = chamber,
    chamber_venue = chamber_venue, from = from, to = to, type = type,
    include_presiding = include_presiding, include_text = include_text, call = call
  )
  tbl <- select_columns(tbl, columns, call = call)
  collect_result(tbl, collect = collect, limit = limit, call = call)
}

# ---- internals: the shared builder --------------------------------------------------------------

# Validates the shared turn-level arguments, runs the PHID and party lookups, and returns the
# lazy turn table with the columns of `speech_cols` (plus `content` when `include_text`).
speech_query <- function(member = NULL, party = NULL, parliament_id = NULL, chamber = NULL,
                         chamber_venue = NULL, from = NULL, to = NULL,
                         type = speech_type_default, include_presiding = FALSE,
                         include_text = TRUE, call = rlang::caller_env()) {
  # Validation, before any query.
  filters <- list(parliament_id = parliament_id, chamber_venue = chamber_venue)
  check_getter_args(filters, 0L, call = call)
  bounds <- date_bounds(from, to, call = call)
  filters$chamber <- normalise_chamber(chamber, call = call)
  type <- check_speech_type(type, call)
  check_flag(include_presiding, "include_presiding", call)
  check_flag(include_text, "include_text", call)
  check_phids(member, "member", call)
  party <- check_party(party, call)

  # Lookups, before the main query.
  check_members_exist(member, call)
  party_ids <- resolve_party(party, call)

  # The main query: turns joined to their sitting, filtered, then joined to the party at the time.
  keep <- c(
    "action_id", "sitting_id", "chamber_venue", "PHID", "name_raw", "resolution",
    speech_flag_cols, if (include_text) "content"
  )
  sittings <- dplyr::select(db_tbl("sittings"), "sitting_id", "date", "chamber", "parliament_id")
  tbl <- db_tbl("v_speech") |>
    dplyr::select(dplyr::all_of(keep)) |>
    dplyr::inner_join(sittings, by = "sitting_id")

  tbl <- filter_args(tbl, filters, call = call)
  tbl <- filter_args(tbl, list(PHID = member), call = call)
  if (!is.null(bounds$from)) {
    tbl <- dplyr::filter(tbl, !!rlang::sym("date") >= !!bounds$from)
  }
  if (!is.null(bounds$to)) {
    tbl <- dplyr::filter(tbl, !!rlang::sym("date") <= !!bounds$to)
  }
  tbl <- filter_type(tbl, type)
  if (!include_presiding) {
    resolution <- rlang::sym("resolution")
    tbl <- dplyr::filter(tbl, is.na(!!resolution) | !!resolution != "sentinel")
  }

  tbl <- join_party_at_time(tbl)
  if (!is.null(party_ids)) {
    tbl <- filter_args(tbl, list(party_id_at_time = party_ids), call = call)
  }
  dplyr::select(tbl, dplyr::all_of(c(speech_cols, if (include_text) "content")))
}

# Adds `party_at_time` and `party_id_at_time` from v_party_at_time (one row per action, keyed
# `action_id`).
join_party_at_time <- function(tbl) {
  party <- dplyr::select(
    db_tbl("v_party_at_time"), "action_id", "party_at_time", "party_id_at_time"
  )
  dplyr::left_join(tbl, party, by = "action_id")
}

# The B1 turn-type rule: the requested flags OR-ed, and no interjection unless requested. Two
# separate filters, so each is parenthesised in SQL (dbplyr drops a bare `(` around the OR).
filter_type <- function(tbl, type) {
  flags <- rlang::syms(unname(speech_types[type]))
  tbl <- dplyr::filter(tbl, !!Reduce(function(a, b) rlang::expr(!!a | !!b), flags))
  if (!"interjection" %in% type) {
    tbl <- dplyr::filter(tbl, !dplyr::coalesce(!!rlang::sym("is_interjection"), FALSE))
  }
  tbl
}

# ---- internals: validation and lookups ----------------------------------------------------------

check_flag <- function(x, arg, call) {
  if (!rlang::is_bool(x)) {
    abort_input(c(
      "{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
      "x" = "It is {.obj_type_friendly {x}}."
    ), call = call)
  }
}

check_speech_type <- function(type, call) {
  valid <- names(speech_types)
  if (!is.character(type) || length(type) == 0 || anyNA(type)) {
    abort_input(c(
      "{.arg type} must be one or more of {.val {valid}}.",
      "x" = "It is {.obj_type_friendly {type}}."
    ), call = call)
  }
  lower <- tolower(type)
  bad <- type[!lower %in% valid]
  if (length(bad)) {
    abort_input(c(
      "{.arg type} must be one or more of {.val {valid}}.",
      "x" = "Unknown type{?s}: {.val {bad}}."
    ), call = call)
  }
  unique(lower)
}

# PHIDs given must exist in `members`.
check_members_exist <- function(member, call) {
  check_known_phids(member, call)
}

# `party`: NULL, whole numbers (party ids) or non-empty strings (names or abbreviations).
check_party <- function(party, call) {
  if (is.null(party)) {
    return(NULL)
  }
  if (is.factor(party)) {
    party <- as.character(party)
  }
  ok_number <- is.numeric(party) && length(party) > 0 && all(is.finite(party)) &&
    all(party == trunc(party))
  ok_string <- is.character(party) && length(party) > 0 && !anyNA(party) &&
    all(nzchar(trimws(party)))
  if (!ok_number && !ok_string) {
    abort_input(c(
      "{.arg party} must be party ids (whole numbers) or party names or abbreviations
       (strings).",
      "x" = "It is {.obj_type_friendly {party}}.",
      "i" = "List the parties with {.code get_parties()}."
    ), call = call)
  }
  if (ok_string) trimws(party) else party
}

# Resolves each `party` value to one party_id (see get_speeches(), Details). The parties table
# is small, so it is read once and matched in R; no user value reaches SQL here.
resolve_party <- function(party, call) {
  if (is.null(party)) {
    return(NULL)
  }
  parties <- run_query(function() {
    db_tbl("parties") |>
      dplyr::select("party_id", "Name", "Abbrev") |>
      dplyr::collect()
  }, call)
  ids <- vapply(party, function(p) resolve_one_party(p, parties, call), numeric(1))
  unique(as.integer(ids))
}

resolve_one_party <- function(p, parties, call) {
  hint <- "List the parties with {.code get_parties()}."
  if (is.numeric(p)) {
    if (!p %in% parties$party_id) {
      abort_not_found(c("No party has {.field party_id} {.val {p}}.", "i" = hint), call = call)
    }
    return(p)
  }
  key <- tolower(p)
  exact <- parties[tolower(parties$Abbrev) %in% key | tolower(parties$Name) %in% key, ]
  if (nrow(exact) == 1) {
    return(exact$party_id)
  }
  if (nrow(exact) > 1) {
    abort_ambiguous_party(p, exact, call)
  }
  partial <- parties[grepl(key, tolower(parties$Name), fixed = TRUE), ]
  if (nrow(partial) == 1) {
    return(partial$party_id)
  }
  if (nrow(partial) > 1) {
    abort_ambiguous_party(p, partial, call)
  }
  abort_not_found(c("No party is named or abbreviated {.val {p}}.", "i" = hint), call = call)
}

abort_ambiguous_party <- function(p, hits, call) {
  abort_ambiguous(c(
    "{.arg party} {.val {p}} matches {nrow(hits)} parties:
     {sprintf('%s (%s, party_id %d)', hits$Name, hits$Abbrev, hits$party_id)}.",
    "i" = "Pass the {.field party_id} you mean instead, one of {.val {hits$party_id}}."
  ), call = call)
}

# ---- internals: find_member() -------------------------------------------------------------------

name_tokens <- function(name, call) {
  tokens <- if (rlang::is_string(name)) strsplit(trimws(name), "[[:space:]]+")[[1]] else character()
  tokens <- tokens[nzchar(tokens)]
  if (length(tokens) == 0) {
    abort_input(c(
      "{.arg name} must be a single string with at least one name in it.",
      "x" = "It is {.obj_type_friendly {name}}.",
      "i" = "For example {.code find_member(\"john howard\")}."
    ), call = call)
  }
  tokens
}

# Escapes LIKE wildcards so a name piece matches literally (escape character `\`).
escape_like <- function(x) {
  gsub("([\\\\%_])", "\\\\\\1", x)
}

# One row per PHID: the chambers served in, the first start and the last end (NULL while any
# service has no end date).
service_summary <- function(service) {
  chamber <- rlang::sym("chamber")
  end <- rlang::sym("DateEnd")
  service |>
    dplyr::group_by(!!rlang::sym("PHID")) |>
    dplyr::summarise(
      n_house = sum(ifelse(!!chamber == "house", 1L, 0L), na.rm = TRUE),
      n_senate = sum(ifelse(!!chamber == "senate", 1L, 0L), na.rm = TRUE),
      n_open = sum(ifelse(is.na(!!end), 1L, 0L), na.rm = TRUE),
      first_service = min(!!rlang::sym("DateStart"), na.rm = TRUE),
      max_end = max(!!end, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      chambers = dplyr::case_when(
        !!rlang::sym("n_house") > 0 & !!rlang::sym("n_senate") > 0 ~ "house, senate",
        !!rlang::sym("n_house") > 0 ~ "house",
        !!rlang::sym("n_senate") > 0 ~ "senate"
      ),
      last_service = dplyr::if_else(!!rlang::sym("n_open") > 0, NA, !!rlang::sym("max_end"))
    )
}

# parl_service with the chamber spelt as in `sittings`.
service_tbl <- function() {
  db_tbl("parl_service") |>
    dplyr::select("PHID", "MemberOrSenator", "DateStart", "DateEnd") |>
    dplyr::mutate(chamber = dplyr::case_when(
      !!rlang::sym("MemberOrSenator") == "Member" ~ "house",
      !!rlang::sym("MemberOrSenator") == "Senator" ~ "senate"
    ))
}
