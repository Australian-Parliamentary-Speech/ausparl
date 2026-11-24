# Filter by a case-insensitive pattern

Builds a pattern filter for any filter argument of an ausparl function
that holds text. The column is matched with SQL `ILIKE`, ignoring case:
`%` matches any run of characters and `_` any single character.

## Usage

``` r
matches_pattern(pattern)
```

## Arguments

- pattern:

  A single, non-empty string, such as `"%deakin%"`.

## Value

An `ausparl_like` object, to pass as a filter argument.

## See also

[`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)

## Examples

``` r
matches_pattern("%deakin%")
#> $pattern
#> [1] "%deakin%"
#> 
#> attr(,"class")
#> [1] "ausparl_like"
```
