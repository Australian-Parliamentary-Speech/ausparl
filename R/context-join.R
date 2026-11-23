# Date-scoped context joins. Values reach SQL only through dbplyr escaping; collection is guarded.
# Each add_*() helper makes one left join on `action_id` from a turn-level result to one
# source keyed by `action_id`, and returns the same kind of object it was given: a lazy tbl stays
# lazy; a local data frame is joined inside DuckDB and comes back as a tibble with its rows in
# their original order. Columns already in `x` are not added again.

#' Add member details to turns
#'
#' Adds columns from the `members` table, for the member who made each turn. The member is the
#' turn's `PHID` in `actions`, so `x` needs only `action_id`.
#'
#' Member details are not date-scoped: `members` holds one row per person.
#'
#' @section Input and output:
#' `x` is a result with one row per turn and a character `action_id` column, such as the output
#' of [get_speeches()], [search_speeches_by_terms()] or [get_sitting_timeline()]. It is
#' either a data frame (or tibble), or a lazy table on the package connection, such as one
#' returned with `collect = FALSE`.
#'
#' * A lazy table gets a lazy left join, and nothing is read until you `collect()` it.
#' * A data frame is joined inside DuckDB and returned as a tibble, with the same rows in the
#'   same order, its columns first and the added columns after them.
#'
#' Rows are never dropped or repeated. A turn without a `PHID` (a presiding officer, or a
#' speaker who is not one member; see [get_speeches()]), or whose `action_id` is not in the
#' database, is kept with `NA` in the added columns. A column that is already in `x` is not added
#' again: only the missing ones are added, and a message names the ones skipped. If all of them
#' are present, `x` is returned unchanged.
#'
#' @param x Turns: a data frame or tibble with a character `action_id` column, or a lazy table
#'   on the package connection (see the Input and output section).
#' @param cols Columns of `members` to add. Defaults to `DisplayName`, `Gender` and `State`.
#' @return `x` with the requested columns added: a tibble for a data frame, a lazy table for a
#'   lazy table.
#' @seealso [add_party()], [add_electorate()], [add_age()], [add_role()],
#'   [add_government_status()], [add_debate()], [get_members()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' turns <- get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5)
#' add_member(turns)
#' add_member(turns, cols = c("DisplayName", "DateOfBirth"))
#' db_disconnect()
add_member <- function(x, cols = c("DisplayName", "Gender", "State")) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  members <- db_tbl("members")
  cols <- check_member_cols(cols, colnames(members), call)
  add_context(x, kind, member_source(members, cols), cols, call)
}

#' Add the speaker's party at the time of each turn
#'
#' Adds the party the speaker belonged to on the sitting date of each turn, from the
#' `v_party_at_time` view.
#'
#' Three columns are added: `party_at_time` (the party name), `party_id_at_time` and
#' `party_abbrev_at_time` (the party's `Abbrev` in `parties`). Stored values are returned
#' unchanged.
#'
#' [get_speeches()] output already has `party_at_time` and `party_id_at_time`, so only
#' `party_abbrev_at_time` is added to it.
#'
#' @inheritSection add_member Input and output
#' @inheritParams add_member
#' @return `x` with the party columns added: a tibble for a data frame, a lazy table for a lazy
#'   table.
#' @seealso [add_government_status()], [get_parties()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' turns <- get_sitting_timeline(date = "1918-09-19", chamber = "senate")
#' add_party(turns)
#' db_disconnect()
add_party <- function(x) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  add_context(x, kind, party_context_tbl(), party_cols, call)
}

#' Add the speaker's electorate at the time of each turn
#'
#' Adds `electorate_at_time`, the division or state the speaker represented on the sitting date
#' of each turn, from the `v_electorate_at_time` view.
#'
#' @inheritSection add_member Input and output
#' @inheritParams add_member
#' @return `x` with `electorate_at_time` added: a tibble for a data frame, a lazy table for a
#'   lazy table.
#' @seealso [add_member()], [get_electorates()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' add_electorate(get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5))
#' db_disconnect()
add_electorate <- function(x) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  add_context(x, kind, db_tbl("v_electorate_at_time"), "electorate_at_time", call)
}

#' Add the speaker's age at the time of each turn
#'
#' Adds `age_at_time`, the speaker's age in whole years on the sitting date of each turn, from
#' the `v_age_at_time` view. It is `NA` where the date of birth is not recorded.
#'
#' @inheritSection add_member Input and output
#' @inheritParams add_member
#' @return `x` with `age_at_time` added: a tibble for a data frame, a lazy table for a lazy
#'   table.
#' @seealso [add_member()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' add_age(get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5))
#' db_disconnect()
add_age <- function(x) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  add_context(x, kind, db_tbl("v_age_at_time"), "age_at_time", call)
}

#' Add the speaker's role at the time of each turn
#'
#' Adds `role_at_time` from the `v_role_at_time` view: `"minister"` if the speaker held a
#' ministry on the sitting date, otherwise `"shadow_minister"` if they held a shadow ministry,
#' otherwise `"backbencher"`.
#'
#' @inheritSection add_member Input and output
#' @inheritParams add_member
#' @return `x` with `role_at_time` added: a tibble for a data frame, a lazy table for a lazy
#'   table.
#' @seealso [add_government_status()], [get_ministry_records()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' add_role(get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5))
#' db_disconnect()
add_role <- function(x) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  add_context(x, kind, db_tbl("v_role_at_time"), "role_at_time", call)
}

#' Add whether the speaker's party was in government at the time of each turn
#'
#' Adds `government_status_at_time` from the `v_government_status_at_time` view:
#' `"government"` if the speaker's party on the sitting date formed a ministry in office that
#' day, otherwise `"opposition"`; `NA` when the party at the time is unknown.
#'
#' The view matches the speaker's party to the ministry's party by party name, not by id. A
#' ministry with no party recorded matches no speaker's party, so turns in its term read
#' `"opposition"`. Stored values are returned unchanged.
#'
#' @inheritSection add_member Input and output
#' @inheritParams add_member
#' @return `x` with `government_status_at_time` added: a tibble for a data frame, a lazy table
#'   for a lazy table.
#' @seealso [add_party()], [add_role()], [get_ministries()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' add_government_status(
#'   get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5)
#' )
#' db_disconnect()
add_government_status <- function(x) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  add_context(
    x, kind, db_tbl("v_government_status_at_time"), "government_status_at_time", call
  )
}

#' Add the debate and subdebate of each turn
#'
#' Adds `debate_title`, `subdebate_title` and `seq` (the turn's position in its sitting) from
#' the `v_sitting_timeline` view.
#'
#' @inheritSection add_member Input and output
#' @inheritParams add_member
#' @return `x` with the debate columns added: a tibble for a data frame, a lazy table for a lazy
#'   table.
#' @seealso [get_sitting_timeline()], [get_debates()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' add_debate(get_speeches(from = 2002, to = 2002, include_text = FALSE, limit = 5))
#' db_disconnect()
add_debate <- function(x) {
  call <- rlang::current_env()
  kind <- check_join_input(x, call)
  add_context(x, kind, db_tbl("v_sitting_timeline"), debate_cols, call)
}

# ---- internals: sources -------------------------------------------------------------------------

party_cols <- c("party_id_at_time", "party_at_time", "party_abbrev_at_time")
debate_cols <- c("debate_title", "subdebate_title", "seq")

# v_party_at_time joined to `parties` by id for the abbreviation.
party_context_tbl <- function() {
  parties <- dplyr::select(
    db_tbl("parties"),
    party_id_at_time = "party_id", party_abbrev_at_time = "Abbrev"
  )
  party <- dplyr::select(
    db_tbl("v_party_at_time"), "action_id", "party_at_time", "party_id_at_time"
  )
  dplyr::left_join(party, parties, by = "party_id_at_time")
}

# One row per action: the turn's PHID in `actions`, then the member's columns.
member_source <- function(members, cols) {
  actions <- dplyr::select(db_tbl("actions"), "action_id", "PHID")
  members <- dplyr::select(members, dplyr::all_of(unique(c("PHID", cols))))
  dplyr::left_join(actions, members, by = "PHID")
}

# ---- internals: validation ----------------------------------------------------------------------

# Returns "lazy" or "local", or raises ausparl_input_error.
check_join_input <- function(x, call) {
  hint <- "Pass turn-level results with an {.field action_id} column, such as the output of
           {.fn get_speeches}."
  if (inherits(x, "tbl_lazy")) {
    if (!identical(dbplyr::remote_con(x), db_con())) {
      abort_input(c(
        "{.arg x} is a lazy table on another database connection.",
        "i" = "Use a lazy table on the package connection {.code db_con()}, or
               {.code collect()} it first."
      ), call = call)
    }
    if (!"action_id" %in% colnames(x)) {
      abort_input(c("{.arg x} has no {.field action_id} column.", "i" = hint), call = call)
    }
    proto <- run_query(function() dplyr::collect(utils::head(dplyr::select(x, "action_id"), 0)),
      call = call
    )
    check_action_id_type(proto$action_id, call)
    return("lazy")
  }
  if (!is.data.frame(x)) {
    abort_input(c(
      "{.arg x} must be a data frame or a lazy table, not {.obj_type_friendly {x}}.",
      "i" = hint
    ), call = call)
  }
  if (!"action_id" %in% names(x)) {
    abort_input(c("{.arg x} has no {.field action_id} column.", "i" = hint), call = call)
  }
  check_action_id_type(x[["action_id"]], call)
  "local"
}

check_action_id_type <- function(action_id, call) {
  if (!is.character(action_id)) {
    abort_input(c(
      "{.field action_id} in {.arg x} must be character, not {.obj_type_friendly {action_id}}.",
      "i" = "Action ids look like {.val house_2002-10-15_R2}."
    ), call = call)
  }
}

check_member_cols <- function(cols, valid, call) {
  if (!is.character(cols) || length(cols) == 0 || anyNA(cols)) {
    abort_input(c(
      "{.arg cols} must be a character vector of {.field members} column names.",
      "x" = "It is {.obj_type_friendly {cols}}.",
      "i" = "Valid columns: {.field {valid}}."
    ), call = call)
  }
  unknown <- setdiff(cols, valid)
  if (length(unknown)) {
    abort_input(c(
      "{.arg cols} names {cli::qty(unknown)}{?a column/columns} not in {.field members}:
       {.val {unknown}}.",
      "i" = "Valid columns: {.field {valid}}."
    ), call = call)
  }
  unique(cols)
}

# ---- internals: the shared join -----------------------------------------------------------------

# Left-joins the `cols` of `source` (keyed uniquely by `action_id`) onto `x`. Columns already in
# `x` are skipped with one message.
add_context <- function(x, kind, source, cols, call) {
  present <- intersect(cols, colnames(x))
  cols <- setdiff(cols, present)
  if (length(present)) {
    cli::cli_inform("Skipping {.field {present}}: already in {.arg x}.")
  }
  if (length(cols) == 0) {
    return(x)
  }
  source <- dplyr::select(source, dplyr::all_of(c("action_id", cols)))
  if (identical(kind, "lazy")) {
    return(dplyr::left_join(x, source, by = "action_id"))
  }
  join_local(x, source, cols, call)
}

join_seq <- new.env(parent = emptyenv())
join_seq$n <- 0L

# Registers the keys of local `x` (zero-copy) with a row index, joins them to `source` in DuckDB,
# collects the added columns and binds them to `x` in its original row order. The registration
# is always removed, even on error. No size guard: the result has as many rows as `x`.
join_local <- function(x, source, cols, call) {
  con <- db_con()
  join_seq$n <- join_seq$n + 1L
  name <- sprintf("ausparl_join_%d_%d", Sys.getpid(), join_seq$n)
  keys <- data.frame(
    action_id = x[["action_id"]], ausparl_row = seq_len(nrow(x)), stringsAsFactors = FALSE
  )
  res <- run_query(function() {
    duckdb::duckdb_register(con, name, keys)
    on.exit(duckdb::duckdb_unregister(con, name), add = TRUE)
    dplyr::tbl(con, name) |>
      dplyr::left_join(source, by = "action_id") |>
      dplyr::select(dplyr::all_of(c("ausparl_row", cols))) |>
      dplyr::collect()
  }, call = call)
  res <- res[order(res$ausparl_row), , drop = FALSE]
  out <- tibble::as_tibble(x)
  for (col in cols) {
    out[[col]] <- res[[col]]
  }
  out
}
