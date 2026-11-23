# Hand-off to quanteda (R09). Issues no SQL of its own: a lazy input is collected through
# collect_result(), so the row-probe size guard applies before anything reaches R.

#' Convert a query result to a quanteda corpus
#'
#' Hands a speech result to [quanteda](https://quanteda.io) as a corpus: one document per row,
#' named by `docid_field`, with text from `text_field` and every other column as a document
#' variable (docvar). Docvars keep their names, values and types: dates stay `Date`s and flags
#' stay logical.
#'
#' `x` is usually the output of [get_speeches()] or [search_speeches_by_terms()], possibly
#' after `add_*()` helpers such as [add_party()]; the added columns become docvars.
#'
#' A lazy table (`collect = FALSE`) is collected first. A result with a `content` column is held
#' to the text size ceiling, `getOption("ausparl.max_rows_text")`; above it the call is an error.
#'
#' The text is never edited. `NA` text is passed to quanteda as it is, and quanteda's own
#' conversion applies (it currently becomes an empty document, with a warning).
#'
#' This function only builds the corpus; tokenising, document-feature matrices and analysis are
#' left to quanteda.
#'
#' @param x A tibble or data frame, or a lazy table from an ausparl function with
#'   `collect = FALSE`, with one row per document.
#' @param text_field Name of the character column holding the text. Results fetched with
#'   `include_text = FALSE` have no `content` column; fetch them with `include_text = TRUE`.
#' @param docid_field Name of the column holding the document names. Its values must be unique
#'   and not `NA`.
#' @return A quanteda `corpus` with one document per row of `x`.
#' @seealso [get_speeches()], [search_speeches_by_terms()]
#' @export
#' @examples
#' db_connect(sample = TRUE)
#' speeches <- get_speeches(from = 2002, to = 2002, limit = 20)
#' corp <- as_corpus(speeches)
#' corp
#' head(quanteda::docvars(corp))
#' db_disconnect()
as_corpus <- function(x, text_field = "content", docid_field = "action_id") {
  call <- rlang::current_env()
  check_field_name(text_field, "text_field", call)
  check_field_name(docid_field, "docid_field", call)
  if (identical(text_field, docid_field)) {
    abort_input(c(
      "{.arg text_field} and {.arg docid_field} must name different columns.",
      "x" = "Both are {.val {text_field}}."
    ), call = call)
  }
  if (inherits(x, "tbl_lazy")) {
    x <- collect_result(x, call = call)
  } else if (!is.data.frame(x)) {
    abort_input(c(
      "{.arg x} must be a data frame, a tibble, or a lazy table from an ausparl function.",
      "x" = "It is {.obj_type_friendly {x}}."
    ), call = call)
  }
  check_text_field(x, text_field, call)
  check_docid_field(x, docid_field, call)
  quanteda::corpus(
    as.data.frame(x),
    docid_field = docid_field,
    text_field = text_field
  )
}

# ---- internals ----------------------------------------------------------------------------------

check_field_name <- function(value, arg, call) {
  if (!rlang::is_string(value) || !nzchar(value)) {
    abort_input(c(
      "{.arg {arg}} must be a single column name.",
      "x" = "It is {.obj_type_friendly {value}}."
    ), call = call)
  }
}

check_text_field <- function(x, text_field, call) {
  if (!text_field %in% names(x)) {
    hint <- if (identical(text_field, "content")) {
      c("i" = "Fetch the result with {.code include_text = TRUE} to get {.field content}.")
    } else {
      c("i" = "Columns: {.field {names(x)}}.")
    }
    abort_input(c(
      "{.arg x} has no text column {.field {text_field}}.",
      hint
    ), call = call)
  }
  if (!is.character(x[[text_field]])) {
    abort_input(c(
      "The text column {.field {text_field}} must be character.",
      "x" = "It is {.obj_type_friendly {x[[text_field]]}}.",
      "i" = "Choose a character column with {.arg text_field}."
    ), call = call)
  }
}

check_docid_field <- function(x, docid_field, call) {
  if (!docid_field %in% names(x)) {
    abort_input(c(
      "{.arg x} has no document id column {.field {docid_field}}.",
      "i" = "Columns: {.field {names(x)}}.",
      "i" = "Choose a column of unique ids with {.arg docid_field}."
    ), call = call)
  }
  ids <- x[[docid_field]]
  if (!is.atomic(ids)) {
    abort_input(c(
      "The document id column {.field {docid_field}} must be an atomic vector.",
      "x" = "It is {.obj_type_friendly {ids}}."
    ), call = call)
  }
  n_na <- sum(is.na(ids))
  if (n_na > 0) {
    abort_input(c(
      "The document id column {.field {docid_field}} must not contain {.val NA}.",
      "x" = "It has {n_na} {.val NA} value{?s}.",
      "i" = "Drop those rows, or choose another column with {.arg docid_field}."
    ), call = call)
  }
  dups <- unique(ids[duplicated(ids)])
  if (length(dups)) {
    abort_input(c(
      "The document id column {.field {docid_field}} must hold unique values.",
      "x" = "Duplicated: {.val {utils::head(dups, 5)}}{if (length(dups) > 5) ' ...' else ''}.",
      "i" = "Remove the duplicate rows, or choose another column with {.arg docid_field}."
    ), call = call)
  }
}
