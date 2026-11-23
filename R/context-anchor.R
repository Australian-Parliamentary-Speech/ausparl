# Anchored cross-table queries. Values reach SQL only through dbplyr escaping, collection goes
# through the size guard, interjections are excluded by default, and columns the database does not
# store are computed in the query; stored data is never altered.
# A member profile, and three activity aggregates with a fixed grain. The activity functions share
# one turn base (`turn_base()`) and one definition of each metric (`activity_metrics()`), so a
# metric means the same thing in every function.

#' Profile a member
#'
#' Collects everything the database records about one member, from the nine per-member tables.
#' Each element is exactly what the matching getter returns for the member's PHID, so the profile
#' adds no new query logic.
#'
#' @param PHID A single member PHID. Look one up with [find_member()].
#' @return A named list of nine tibbles: `members` ([get_members()]), `parl_service`
#'   ([get_parl_service()]), `party_service` ([get_party_service()]), `ministry_records`
#'   ([get_ministry_records()]), `shadow_ministry_records`
#'   ([get_shadow_ministry_records()]), `committee_members` ([get_committee_members()]),
#'   `occupations` ([get_occupations()]), `qualifications` ([get_qualifications()]) and
#'   `schools` ([get_schools()]). A table with nothing recorded for the member is a zero-row
#'   tibble.
#' @seealso [find_member()], [member_activity()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' howard <- member_profile("ZD4")
#' names(howard)
#' howard$parl_service
#' db_disconnect()
member_profile <- function(PHID) {
  call <- rlang::current_env()
  if (!rlang::is_string(PHID)) {
    abort_input(c(
      "{.arg PHID} must be a single member PHID.",
      "x" = "It is {.obj_type_friendly {PHID}}.",
      "i" = "Profile one member at a time; look a PHID up with {.code find_member()}."
    ), call = call)
  }
  check_phids(PHID, "PHID", call)
  check_known_phids(PHID, call)
  lapply(profile_getters(), function(getter) getter(PHID = PHID))
}

#' Activity per member
#'
#' Counts each member's turns in `v_speech`, by parliament and chamber.
#'
#' **Metrics.** The three activity functions share these definitions:
#' * `n_turns`: all turns in `v_speech`, including interjections. Quotes (`action_type` is
#'   `"quote"`: passages read out, such as a letter or a petition) are not turns and are not
#'   counted by any metric.
#' * `n_speeches`: turns with `is_speech`, `is_question` or `is_answer` set, and not
#'   `is_interjection`. This is the default of [get_speeches()], so `n_speeches` equals the
#'   number of rows it returns for the same member and parliament.
#' * `n_questions`, `n_answers`: turns with `is_question` (or `is_answer`) set that are not
#'   interjections.
#' * `n_interjections_made`: turns with `is_interjection` set.
#' * `n_interjections_received`: interjections in `v_interjection_target` whose target turn
#'   (the turn interrupted) was made by the member, counted in the target turn's parliament and
#'   chamber.
#' * `n_words`: words summed over the `n_speeches` turns. A word is a run of non-whitespace
#'   characters: the turn's `content` is trimmed and split on `\s+`. The count is computed when
#'   the query runs, because the database has no word-count column. Stored content is counted
#'   as it is, so a turn whose content is `"N/A"` counts one word.
#'
#' **Grain and filters.** `parliament_id` and `chamber` are the sitting's, from `sittings`.
#' `chamber_venue` filters the turns (for received interjections, the target turns). Turns
#' without a PHID are not counted: presiding officers, and unmatched, unknown, collective and
#' non-member speakers (see [get_speeches()]).
#'
#' @param PHID Character vector of member PHIDs. A PHID that matches no member is an error; look
#'   one up with [find_member()].
#' @param parliament_id Filter on the sitting's `parliament_id`: whole numbers or [in_range()].
#' @param chamber `"house"` and/or `"senate"`, in any case.
#' @param chamber_venue Filter on the turn's `chamber_venue`: whole numbers or [in_range()].
#' @inheritParams get_interjections
#' @return A tibble with one row per member, parliament and chamber in which the member had at
#'   least one turn or received an interjection, ordered by those three, and columns `PHID`,
#'   `parliament_id`, `chamber`, `n_turns`, `n_speeches`, `n_questions`, `n_answers`,
#'   `n_interjections_made`, `n_interjections_received` and `n_words`. Zero rows if nothing
#'   matches; a lazy table (in no set order) if `collect = FALSE`.
#' @seealso [party_activity()], [parliament_summary()], [get_speeches()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' member_activity()
#' member_activity(PHID = "ZD4", columns = c("parliament_id", "n_speeches", "n_words"))
#' db_disconnect()
member_activity <- function(PHID = NULL, parliament_id = NULL, chamber = NULL,
                            chamber_venue = NULL, columns = NULL, collect = TRUE,
                            limit = NULL) {
  call <- rlang::current_env()
  filters <- activity_args(
    parliament_id, chamber, chamber_venue,
    collect = collect, limit = limit, call = call
  )
  check_phids(PHID, "PHID", call)
  check_known_phids(PHID, call)
  filters$PHID <- PHID

  keys <- c("PHID", "parliament_id", "chamber")
  metrics <- c(
    "n_turns", "n_speeches", "n_questions", "n_answers", "n_interjections_made", "n_words"
  )
  made <- turn_base(filters, call) |>
    dplyr::filter(!is.na(!!rlang::sym("PHID"))) |>
    activity_metrics(keys, metrics)
  received <- received_base(filters, call) |>
    dplyr::group_by(!!!rlang::syms(keys)) |>
    dplyr::summarise(n_interjections_received = dplyr::n(), .groups = "drop")

  tbl <- dplyr::full_join(made, received, by = keys) |>
    zero_fill(c(metrics, "n_interjections_received")) |>
    dplyr::select(dplyr::all_of(c(
      keys, setdiff(metrics, "n_words"), "n_interjections_received", "n_words"
    )))
  finish_activity(tbl, keys, columns, collect, limit, call)
}

#' Activity per party
#'
#' Counts turns by the speaker's party at the time, by parliament and chamber.
#'
#' The metrics `n_turns`, `n_speeches` and `n_words` are defined as in [member_activity()];
#' `n_interjections` is its `n_interjections_made`. `n_members` counts the *speaking* members:
#' the distinct PHIDs with at least one turn for that party in that parliament and chamber.
#'
#' **Party.** Each turn is assigned the party its speaker belonged to on the sitting date
#' (`v_party_at_time`), so a member who changed party is counted under each party for the turns
#' made in it.
#' Turns without a party at the time (presiding officers, speakers with no PHID, and
#' members with no party recorded for the date) are not counted.
#' Party lineage is not followed.
#'
#' @param party_id Filter on `party_id_at_time`: whole numbers or [in_range()]. List the parties
#'   with [get_parties()].
#' @inheritParams member_activity
#' @return A tibble with one row per party at the time, parliament and chamber, ordered by
#'   `parliament_id`, `chamber` and `party_at_time`, and columns `party_id_at_time`,
#'   `party_at_time`, `parliament_id`, `chamber`, `n_members`, `n_turns`, `n_speeches`,
#'   `n_interjections` and `n_words`. Zero rows if nothing matches; a lazy table (in no set
#'   order) if `collect = FALSE`.
#' @seealso [member_activity()], [parliament_summary()], [add_party()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' party_activity()
#' party_activity(party_id = 1, chamber = "house")
#' db_disconnect()
party_activity <- function(party_id = NULL, parliament_id = NULL, chamber = NULL,
                           chamber_venue = NULL, columns = NULL, collect = TRUE,
                           limit = NULL) {
  call <- rlang::current_env()
  filters <- activity_args(
    parliament_id, chamber, chamber_venue,
    collect = collect, limit = limit, call = call
  )
  check_whole_filter(party_id, "party_id", call)

  keys <- c("party_id_at_time", "party_at_time", "parliament_id", "chamber")
  tbl <- turn_base(filters, call) |>
    join_party_at_time() |>
    dplyr::filter(!is.na(!!rlang::sym("party_at_time"))) |>
    filter_args(list(party_id_at_time = party_id), call = call) |>
    activity_metrics(keys, c("n_members", "n_turns", "n_speeches", "n_interjections", "n_words"))
  finish_activity(
    tbl, c("parliament_id", "chamber", "party_at_time"), columns, collect, limit, call
  )
}

#' Summary per parliament
#'
#' Summarises each parliament and chamber that has sitting days in the database.
#'
#' * `n_sitting_days`: the sitting days in `sittings`.
#' * `n_members`: the *serving* members, the distinct PHIDs with a period of service
#'   (`parl_service`) in the chamber that overlaps the parliament. Service as a Member is the
#'   House and as a Senator the Senate. The parliament runs from `DateOpening` (or
#'   `DateElection` where that is missing) to `ParliamentEnd` (or `DateDissolution` where that
#'   is missing); with neither end date it is ongoing. A service with no end date is ongoing.
#' * `n_turns`: all turns in `v_speech`, including presiding-officer and unmatched turns, but
#'   not quotes (passages read out), as in [member_activity()].
#' * `mean_words_per_speech`: words over speeches, with `n_words` and `n_speeches` defined as in
#'   [member_activity()] (`n_words` is computed when the query runs), over all speakers.
#'   `NA` where there are no speeches.
#'
#' `chamber_venue` filters the turns only; sitting days and members are not affected by it.
#'
#' @inheritParams member_activity
#' @return A tibble with one row per parliament and chamber, ordered by them, and columns
#'   `parliament_id`, `chamber`, `n_sitting_days`, `n_members`, `n_turns` and
#'   `mean_words_per_speech`. Zero rows if nothing matches; a lazy table (in no set order) if
#'   `collect = FALSE`.
#' @seealso [member_activity()], [party_activity()], [get_parliaments()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' parliament_summary()
#' parliament_summary(parliament_id = in_range(30, 48), chamber = "senate")
#' db_disconnect()
parliament_summary <- function(parliament_id = NULL, chamber = NULL, chamber_venue = NULL,
                               columns = NULL, collect = TRUE, limit = NULL) {
  call <- rlang::current_env()
  filters <- activity_args(
    parliament_id, chamber, chamber_venue,
    collect = collect, limit = limit, call = call
  )
  keys <- c("parliament_id", "chamber")
  sym <- rlang::sym

  sittings <- db_tbl("sittings") |>
    dplyr::select("sitting_id", "parliament_id", "chamber") |>
    filter_args(filters[c("parliament_id", "chamber")], call = call)
  days <- sittings |>
    dplyr::group_by(!!!rlang::syms(keys)) |>
    dplyr::summarise(n_sitting_days = dplyr::n_distinct(!!sym("sitting_id")), .groups = "drop")
  serving <- serving_members(days)
  turns <- activity_metrics(turn_base(filters, call), keys, c("n_turns", "n_speeches", "n_words"))

  tbl <- days |>
    dplyr::left_join(serving, by = keys) |>
    dplyr::left_join(turns, by = keys) |>
    zero_fill(c("n_members", "n_turns", "n_speeches", "n_words")) |>
    dplyr::mutate(mean_words_per_speech = dplyr::if_else(
      !!sym("n_speeches") > 0, !!sym("n_words") / !!sym("n_speeches"), NA
    )) |>
    dplyr::select(dplyr::all_of(c(
      keys, "n_sitting_days", "n_members", "n_turns", "mean_words_per_speech"
    )))
  finish_activity(tbl, keys, columns, collect, limit, call)
}

# ---- internals: the profile ---------------------------------------------------------------------

profile_getters <- function() {
  list(
    members = get_members,
    parl_service = get_parl_service,
    party_service = get_party_service,
    ministry_records = get_ministry_records,
    shadow_ministry_records = get_shadow_ministry_records,
    committee_members = get_committee_members,
    occupations = get_occupations,
    qualifications = get_qualifications,
    schools = get_schools
  )
}

# ---- internals: validation ----------------------------------------------------------------------

# Validates the arguments the activity functions share, before any query is built, and returns
# the turn filters (database column names) with `chamber` normalised.
activity_args <- function(parliament_id, chamber, chamber_venue, collect, limit, call) {
  check_getter_args(list(), 0L, collect = collect, limit = limit, call = call)
  check_whole_filter(parliament_id, "parliament_id", call)
  check_whole_filter(chamber_venue, "chamber_venue", call)
  list(
    parliament_id = parliament_id,
    chamber = normalise_chamber(chamber, call = call),
    chamber_venue = chamber_venue
  )
}

# An integer-column filter: NULL, whole numbers without NA, or in_range() of numbers.
check_whole_filter <- function(x, arg, call) {
  if (is.null(x)) {
    return(invisible())
  }
  if (inherits(x, "ausparl_range")) {
    ends <- c(x$from, x$to)
    if (!inherits(x$from, "Date") && !inherits(x$to, "Date") && is.numeric(ends)) {
      return(invisible())
    }
  } else if (is.numeric(x) && length(x) > 0 && all(is.finite(x)) && all(x == trunc(x))) {
    return(invisible())
  }
  abort_input(c(
    "{.arg {arg}} must be whole numbers or a numeric {.fn in_range}.",
    "x" = "It is {.obj_type_friendly {x}}.",
    "i" = "Use {.code NULL} for no filter."
  ), call = call)
}

# ---- internals: the turn base and the shared metrics --------------------------------------------

turn_flag_cols <- c("is_speech", "is_question", "is_answer", "is_interjection")

# `v_speech` turns, except quotes (`action_type = 'quote'`, passages read out, which are not
# turns), with their sitting's `parliament_id` and `chamber`, filtered by `filters`
# (named by database column), plus one indicator column per metric:
# * m_interjection: the turn is an interjection;
# * m_speech: the B1 rule (identified interjections excluded), as in filter_type();
# * m_question / m_answer: the flag is set and the turn is not an interjection;
# * m_words: whitespace tokens of `content` for m_speech turns, else 0 (computed at query time).
# Each step is its own mutate so every boolean is a column before it is combined; dbplyr drops
# a bare `(` around an OR (see filter_type()).
turn_base <- function(filters, call) {
  sym <- rlang::sym
  flag <- function(x) rlang::expr(dplyr::coalesce(!!sym(x), FALSE))
  sittings <- dplyr::select(db_tbl("sittings"), "sitting_id", "parliament_id", "chamber")
  words <- rlang::call2("len", rlang::call2("regexp_extract_all", sym("content"), "\\S+"))

  db_tbl("v_speech") |>
    dplyr::filter(is.na(!!sym("action_type")) | !!sym("action_type") != "quote") |>
    dplyr::select(dplyr::all_of(c(
      "action_id", "sitting_id", "chamber_venue", "PHID", turn_flag_cols, "content"
    ))) |>
    dplyr::inner_join(sittings, by = "sitting_id") |>
    filter_args(filters, call = call) |>
    dplyr::mutate(
      m_interjection = !!flag("is_interjection"),
      m_flagged = !!flag("is_speech") | !!flag("is_question") | !!flag("is_answer")
    ) |>
    dplyr::mutate(
      m_speech = !!sym("m_flagged") & !(!!sym("m_interjection")),
      m_question = !!flag("is_question") & !(!!sym("m_interjection")),
      m_answer = !!flag("is_answer") & !(!!sym("m_interjection"))
    ) |>
    dplyr::mutate(m_words = dplyr::if_else(!!sym("m_speech"), dplyr::coalesce(!!words, 0L), 0L)) |>
    dplyr::select(dplyr::all_of(c(
      "action_id", "PHID", "parliament_id", "chamber", "m_interjection", "m_speech",
      "m_question", "m_answer", "m_words"
    )))
}

# The one definition of each activity metric, as summary expressions over turn_base() columns.
metric_exprs <- function() {
  sym <- rlang::sym
  count_of <- function(x) rlang::expr(sum(dplyr::if_else(!!sym(x), 1L, 0L), na.rm = TRUE))
  list(
    n_members = rlang::expr(dplyr::n_distinct(!!sym("PHID"))),
    n_turns = rlang::expr(dplyr::n()),
    n_speeches = count_of("m_speech"),
    n_questions = count_of("m_question"),
    n_answers = count_of("m_answer"),
    n_interjections_made = count_of("m_interjection"),
    n_interjections = count_of("m_interjection"),
    n_words = rlang::expr(sum(!!sym("m_words"), na.rm = TRUE))
  )
}

# Aggregates turn_base() rows by `keys` into the named metrics.
activity_metrics <- function(tbl, keys, metrics) {
  tbl |>
    dplyr::group_by(!!!rlang::syms(keys)) |>
    dplyr::summarise(!!!metric_exprs()[metrics], .groups = "drop")
}

# Interjections with their target turn's PHID, parliament and chamber (the target is an
# `actions` row, which may lie outside `v_speech`), filtered like the turns. Targets without a
# PHID, and interjections without a target, are dropped.
received_base <- function(filters, call) {
  targets <- dplyr::select(
    db_tbl("actions"),
    target_action_id = "action_id", "sitting_id", "chamber_venue", "PHID"
  )
  sittings <- dplyr::select(db_tbl("sittings"), "sitting_id", "parliament_id", "chamber")
  db_tbl("v_interjection_target") |>
    dplyr::inner_join(targets, by = "target_action_id") |>
    dplyr::inner_join(sittings, by = "sitting_id") |>
    filter_args(filters, call = call) |>
    dplyr::filter(!is.na(!!rlang::sym("PHID")))
}

# Serving members per parliament x chamber row of `days`: distinct PHIDs whose parl_service
# period in that chamber overlaps the parliament's period.
serving_members <- function(days) {
  sym <- rlang::sym
  periods <- db_tbl("parliaments") |>
    dplyr::transmute(
      !!sym("parliament_id"),
      period_start = dplyr::coalesce(!!sym("DateOpening"), !!sym("DateElection")),
      period_end = dplyr::coalesce(!!sym("ParliamentEnd"), !!sym("DateDissolution"))
    )
  service <- dplyr::select(service_tbl(), "PHID", "chamber", "DateStart", "DateEnd")
  days |>
    dplyr::select("parliament_id", "chamber") |>
    dplyr::inner_join(periods, by = "parliament_id") |>
    dplyr::inner_join(service, by = "chamber", relationship = "many-to-many") |>
    dplyr::filter(
      is.na(!!sym("period_end")) | !!sym("DateStart") <= !!sym("period_end"),
      is.na(!!sym("DateEnd")) | !!sym("DateEnd") >= !!sym("period_start")
    ) |>
    dplyr::group_by(!!sym("parliament_id"), !!sym("chamber")) |>
    dplyr::summarise(n_members = dplyr::n_distinct(!!sym("PHID")), .groups = "drop")
}

# Replaces NULL counts (from outer joins) with 0, keeping one numeric type.
zero_fill <- function(tbl, cols) {
  fills <- lapply(cols, function(x) rlang::expr(dplyr::coalesce(!!rlang::sym(x), 0)))
  dplyr::mutate(tbl, !!!rlang::set_names(fills, cols))
}

# Column selection, the size guard and collection; a collected result is ordered by `order_by`.
finish_activity <- function(tbl, order_by, columns, collect, limit, call) {
  tbl <- select_columns(tbl, columns, call = call)
  out <- collect_result(tbl, collect = collect, limit = limit, call = call)
  if (!collect) {
    return(out)
  }
  order_by <- intersect(order_by, names(out))
  if (length(order_by) && nrow(out) > 1) {
    idx <- do.call(order, c(unname(as.list(out[order_by])), list(method = "radix")))
    out <- out[idx, , drop = FALSE]
  }
  out
}
