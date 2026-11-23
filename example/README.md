# example/

A worked example: a short, runnable tour of the Australian Hansard database and the ausparl
package. It takes five to ten minutes and covers:

1. connecting to the database and checking its version;
2. finding a member and their profile, including their ministerial roles;
3. how often a term is used across the years, as a chart;
4. the structure of debate: speaking turns, interjections, and government against opposition;
5. handing speeches to [quanteda](https://quanteda.io) for text analysis.

The example comes in two forms with the same code:

- `walkthrough.qmd`, a Quarto document that renders to a web page with the code, its results
  and the chart;
- `walkthrough.R`, the plain R version, for running without Quarto. It is generated from
  `walkthrough.qmd`, so edit the `.qmd` and regenerate the `.R` from the top folder of the
  repository with
  `knitr::purl("example/walkthrough.qmd", "example/walkthrough.R", documentation = 1)`.

## 1. Get the repository

Clone it with git:

```sh
git clone https://github.com/Australian-Parliamentary-Speech/ausparl.git
```

or download it as a zip file from
<https://github.com/Australian-Parliamentary-Speech/ausparl> (the green *Code* button, then
*Download ZIP*) and unzip it. The commands below run from the repository's top folder, the
one that contains `example/` and `dataset/`.

## 2. Install the package

In R (4.1 or later):

```r
install.packages("remotes")
remotes::install_github("Australian-Parliamentary-Speech/ausparl")
```

This also installs what the example uses: dplyr, ggplot2 and quanteda.

## 3. Get the database (optional)

The full database is one file of about 9.5 GB. Download it once, from the repository's top
folder:

```r
ausparl::db_download(dir = "dataset")
```

It checks the file's checksum, and if the download is interrupted, running the same line again
resumes it. The example then finds `dataset/hansard.duckdb` by itself.

Without it, the example uses the copy `db_connect()` would open (the file named by the
`AUSPARL_DB` environment variable, or one installed by `ausparl::db_download()`), and if there
is none, the small sample database bundled with the package (eight sitting days). It says so
at the top of its output; the code is the same, only the numbers are smaller.

## 4. Run it

With Quarto (<https://quarto.org>), first install the two R packages it uses to run R code
(once):

```r
install.packages(c("knitr", "rmarkdown"))
```

then, from the repository's top folder:

```sh
quarto render example/walkthrough.qmd
```

and open `example/walkthrough.html` in a browser.

Without Quarto, in R, from the repository's top folder:

```r
source("example/walkthrough.R", echo = TRUE)
```

or open `example/walkthrough.R` (or `walkthrough.qmd`) in RStudio or Positron and run it a
chunk at a time.

On the full database the whole example takes well under a minute on a recent laptop.
