# Draft: the "Getting started with ausparl" vignette

Held back from release 0.1.2 as not ready. Nothing here is built or shipped (`data-raw/` is in
`.Rbuildignore`).

To bring it back:

1. Move `ausparl.Rmd.orig` back to `vignettes/` and `test-outputs-vignette.R` back to
   `tests/testthat/`.
2. Run `make vignette` with `AUSPARL_DB` set to a full `hansard.duckdb`. That precomputes
   `vignettes/ausparl.Rmd` and its figures (`data-raw/build-vignette.R`).
3. Add `ausparl` back to the articles in `_pkgdown.yml`, and the `vignette("ausparl")` mentions
   in `R/ausparl-package.R`, `README.md` and `vignettes/database.Rmd`.
