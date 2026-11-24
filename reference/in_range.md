# Filter by an inclusive range

Builds a range filter for any filter argument of an ausparl function:
the column must lie between `from` and `to`, inclusive. Either end may
be left open (`NULL`), but not both.

## Usage

``` r
in_range(from = NULL, to = NULL)
```

## Arguments

- from:

  Lower bound, or `NULL` for no lower bound.

- to:

  Upper bound, or `NULL` for no upper bound.

## Value

An `ausparl_range` object, to pass as a filter argument.

## Details

Both ends must be of the same kind: numbers (for example years or
parliament numbers), or dates given as `Date` objects or `"YYYY-MM-DD"`
strings.

## See also

[`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md)

## Examples

``` r
in_range(1990, 1996)
#> $from
#> [1] 1990
#> 
#> $to
#> [1] 1996
#> 
#> attr(,"class")
#> [1] "ausparl_range"
in_range(from = "2020-01-01")
#> $from
#> [1] "2020-01-01"
#> 
#> $to
#> NULL
#> 
#> attr(,"class")
#> [1] "ausparl_range"
in_range(as.Date("1901-05-09"), as.Date("1901-12-31"))
#> $from
#> [1] "1901-05-09"
#> 
#> $to
#> [1] "1901-12-31"
#> 
#> attr(,"class")
#> [1] "ausparl_range"
```
