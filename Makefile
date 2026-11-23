R ?= Rscript
PKG_VERSION := $(shell sed -n 's/^Version: //p' DESCRIPTION)
TARBALL := ausparl_$(PKG_VERSION).tar.gz
SAMPLE_DB := inst/extdata/ausparl-sample.duckdb

.PHONY: document test test-fulldb lint coverage check example-check vignette

document:
	$(R) -e 'roxygen2::roxygenise()'

test:
	$(R) -e 'testthat::test_local(stop_on_failure = TRUE)'

# Full-DB checks only; needs AUSPARL_DB. Run alone: a full-DB query can use several GB.
test-fulldb:
	@test -n "$$AUSPARL_DB" || { echo "Set AUSPARL_DB to a full hansard.duckdb"; exit 1; }
	NOT_CRAN=true $(R) -e 'testthat::test_local(filter = "fulldb", stop_on_failure = TRUE)'

# Also lints the worked example's example/walkthrough.R, except for its trailing blank line:
# knitr::purl() writes one, and the file must stay identical to a fresh purl.
lint:
	$(R) -e 'pkgload::load_all(quiet = TRUE); l <- lintr::lint_package(); print(l); \
	  e <- lintr::lint("example/walkthrough.R"); \
	  e <- e[vapply(e, function(x) x$$linter != "trailing_blank_lines_linter", logical(1))]; \
	  print(e); quit(status = length(l) + length(e) > 0)'

# NOT_CRAN=true so the FTS tests (skip_on_cran) count toward local coverage.
coverage:
	NOT_CRAN=true $(R) -e 'cov <- covr::package_coverage(); print(cov); p <- covr::percent_coverage(cov); quit(status = p < 80)'

check: document
	R CMD build .
	_R_CHECK_FORCE_SUGGESTS_=false R CMD check --as-cran --no-manual $(TARBALL)

# Precomputes vignettes/ausparl.Rmd from ausparl.Rmd.orig against the full DB; needs AUSPARL_DB.
# Run alone: a full-DB query can use several GB.
vignette:
	$(R) data-raw/build-vignette.R

# Runs the worked example in example/ as someone who downloaded the repository would, on the
# bundled sample DB: builds the tarball, installs it into a temp library, copies example/ into
# an empty temp directory (no dataset/hansard.duckdb there) and runs walkthrough.R in it with
# that library first on R_LIBS, AUSPARL_DB unset, R_ENVIRON_USER=/dev/null and R_USER_DATA_DIR
# a temp directory, so it falls back to the sample. Fails if walkthrough.R differs from a fresh
# knitr::purl() of walkthrough.qmd. If quarto is on PATH, also renders walkthrough.qmd there.
# Dependencies come from the first library path of a plain R session in this directory, which
# stays reachable. --no-init-file skips the user and project profiles, so they cannot replace
# the library paths. Any non-zero exit fails. The temp directory is removed afterwards. Run alone.
example-check:
	@set -e; \
	tmp=$$(mktemp -d); \
	trap 'rm -rf "$$tmp"' EXIT; \
	dep_lib=$$($(R) -e 'cat(.libPaths()[1])'); \
	echo "== walkthrough.R matches a fresh purl of walkthrough.qmd"; \
	purl='a <- commandArgs(TRUE); knitr::purl(a[1], a[2], documentation = 1, quiet = TRUE)'; \
	R_LIBS="$$dep_lib" $(R) --no-init-file -e "$$purl" \
	  "$(CURDIR)/example/walkthrough.qmd" "$$tmp/purled.R" > "$$tmp/purl.log" 2>&1 \
	  || { cat "$$tmp/purl.log"; exit 1; }; \
	cmp -s "$$tmp/purled.R" example/walkthrough.R || { \
	  diff "$$tmp/purled.R" example/walkthrough.R || true; \
	  echo "example/walkthrough.R is stale: regenerate it (see example/README.md)"; \
	  exit 1; }; \
	echo "== R CMD build"; \
	(cd "$$tmp" && R_LIBS="$$dep_lib" R CMD build --no-manual "$(CURDIR)") \
	  > "$$tmp/build.log" 2>&1 || { cat "$$tmp/build.log"; exit 1; }; \
	echo "== R CMD INSTALL into a temp library"; \
	mkdir "$$tmp/lib"; \
	(cd "$$tmp" && R_LIBS="$$dep_lib" R CMD INSTALL --library="$$tmp/lib" ausparl_*.tar.gz) \
	  > "$$tmp/install.log" 2>&1 || { cat "$$tmp/install.log"; exit 1; }; \
	mkdir "$$tmp/run" "$$tmp/userdata"; \
	cp -R example "$$tmp/run/example"; \
	run_env="R_ENVIRON_USER=/dev/null R_USER_DATA_DIR=$$tmp/userdata R_LIBS=$$tmp/lib:$$dep_lib"; \
	echo "== example/walkthrough.R (in an empty directory, so it runs on the sample)"; \
	(cd "$$tmp/run" && env -u AUSPARL_DB $$run_env \
	  $(R) --no-init-file -e 'source("example/walkthrough.R", echo = TRUE)'); \
	if command -v quarto > /dev/null 2>&1; then \
	  echo "== quarto render example/walkthrough.qmd"; \
	  (cd "$$tmp/run" && env -u AUSPARL_DB $$run_env R_PROFILE_USER=/dev/null \
	    quarto render example/walkthrough.qmd --quiet); \
	  [ -s "$$tmp/run/example/walkthrough.html" ] || { echo "no walkthrough.html"; exit 1; }; \
	else \
	  echo "== quarto not on PATH: render of example/walkthrough.qmd skipped"; \
	fi; \
	echo "== example-check passed"
