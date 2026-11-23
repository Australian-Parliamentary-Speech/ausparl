# Precomputes the main vignette.
#
# Knits vignettes/ausparl.Rmd.orig against the full database named by AUSPARL_DB and writes
# vignettes/ausparl.Rmd, with outputs embedded and figures saved next to it as
# vignettes/ausparl-*.png. The generated file has no live chunks, so R CMD check and CRAN
# never touch the database. Run with `make vignette`, alone: a full-database knit must not run
# alongside other R processes, or memory runs out.
#
# Rebuild after a database release or a change to a function signature.

db <- Sys.getenv("AUSPARL_DB")
if (!nzchar(db)) {
  stop(
    "AUSPARL_DB is not set. Point it at a full hansard.duckdb, e.g.\n",
    "  AUSPARL_DB=/path/to/hansard.duckdb make vignette",
    call. = FALSE
  )
}
if (!file.exists(db)) {
  stop("AUSPARL_DB points at '", db, "', which does not exist.", call. = FALSE)
}
for (pkg in c("knitr", "ggplot2", "quanteda")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("The vignette build needs the '", pkg, "' package. Install it first.", call. = FALSE)
  }
}

pkgload::load_all(quiet = TRUE)

vignette_dir <- normalizePath("vignettes", mustWork = TRUE)
source_file <- "ausparl.Rmd.orig"
output_file <- "ausparl.Rmd"
fig_prefix <- "ausparl-"

# Figures from an earlier build are removed so that renamed chunks leave no orphans behind.
old_figs <- list.files(vignette_dir, pattern = "^ausparl-.*\\.png$", full.names = TRUE)
unlink(old_figs)

# Knit from inside vignettes/ so the relative fig.path puts the figures there and the
# generated Markdown refers to them by bare file name.
old_wd <- setwd(vignette_dir)
on.exit(setwd(old_wd), add = TRUE)
options(width = 80)
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.path = fig_prefix,
  fig.width = 7,
  fig.height = 4,
  dpi = 96
)

started <- Sys.time()
invisible(knitr::knit(source_file, output_file, quiet = TRUE, envir = new.env()))
elapsed <- round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1)

out <- readLines(output_file, warn = FALSE)
if (any(grepl("^```\\{r", out))) {
  stop("The generated ", output_file, " still has live chunks.", call. = FALSE)
}
local_paths <- unique(c(db, dirname(db), normalizePath(old_wd), path.expand("~")))
leaked <- vapply(local_paths, function(p) any(grepl(p, out, fixed = TRUE)), logical(1))
if (any(leaked)) {
  stop(
    "The generated ", output_file, " contains a local path: ",
    paste(local_paths[leaked], collapse = ", "),
    ". Hide it in ", source_file, " and rebuild.",
    call. = FALSE
  )
}

figs <- list.files(".", pattern = "^ausparl-.*\\.png$")
message(
  "Wrote vignettes/", output_file, " and ", length(figs), " figure(s) in ", elapsed, " s: ",
  paste(figs, collapse = ", ")
)
