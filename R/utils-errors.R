# Shared error constructors: typed rlang conditions whose messages say what was wrong and how to
# fix it.
# Every package error carries one of four classes plus the parent class "ausparl_error".
# Messages use cli markup, interpolated in the caller's environment.

abort_ausparl <- function(message, class, call, envir) {
  cli::cli_abort(message, class = c(class, "ausparl_error"), call = call, .envir = envir)
}

abort_input <- function(message, call = rlang::caller_env(), envir = parent.frame()) {
  abort_ausparl(message, "ausparl_input_error", call, envir)
}

abort_ambiguous <- function(message, call = rlang::caller_env(), envir = parent.frame()) {
  abort_ausparl(message, "ausparl_ambiguous_input", call, envir)
}

abort_not_found <- function(message, call = rlang::caller_env(), envir = parent.frame()) {
  abort_ausparl(message, "ausparl_not_found", call, envir)
}

abort_db <- function(message, call = rlang::caller_env(), envir = parent.frame()) {
  abort_ausparl(message, "ausparl_db_error", call, envir)
}
