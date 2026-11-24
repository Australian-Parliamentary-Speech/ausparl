# Get interjections and their targets

Reads the `v_interjection_target` view: one row per interjection, with
the turn it interrupted. The view holds only two action ids; this
function joins them back to `actions`, `sittings` and `members` to add
the sitting, the chamber and both members.

## Usage

``` r
get_interjections(
  from = NULL,
  to = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  interjector = NULL,
  target = NULL,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- from, to:

  Sitting-date bounds, inclusive: a year (covering the whole year), a
  `Date`, or a `"YYYY-MM-DD"` string. `NULL` leaves that end open.

- chamber:

  `"house"` and/or `"senate"`, in any case.

- chamber_venue:

  Filter on the interjection's `chamber_venue`: a vector of values or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- interjector, target:

  Character vector of member PHIDs (the interjecting member, or the
  member interrupted). A PHID that matches no member is an error; use
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md)
  to look one up.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per interjection and columns
`interjection_action_id`, `target_action_id`, `sitting_id`, `date`,
`chamber`, `chamber_venue`, `interjector_PHID`, `interjector_name`,
`target_PHID`, `target_name` and `interjection_type` (the interjection's
`action_type`: `"speech"` or `"unresolved_interjection"`). Zero rows if
nothing matches; a lazy table if `collect = FALSE`.

## Details

Every interjection in the view is returned, including those with no
known interjector or no target:

- `interjector_PHID` (and so `interjector_name`) is `NA` for
  presiding-officer interjections (`resolution = "sentinel"` in
  `actions`) and for unresolved interjections.

- `target_action_id` (and so `target_PHID` and `target_name`) is `NA`
  when no substantive turn precedes the interjection in its subdebate.

The target is the first action of the contiguous substantive turn the
interjection falls in: consecutive non-interjection actions by the same
member count as one turn. Names are each member's current
`members.DisplayName`, not their name at the time. Stored values are
returned unchanged.

## See also

[`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md),
[`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)

## Examples

``` r
db_connect(sample = TRUE)
get_interjections(from = 2019, to = 2019)
#> # A tibble: 34 × 11
#>    interjection_action_id target_action_id       sitting_id   date       chamber
#>    <chr>                  <chr>                  <chr>        <date>     <chr>  
#>  1 senate_2019-11-26_R108 senate_2019-11-26_R107 senate_2019… 2019-11-26 senate 
#>  2 senate_2019-11-26_R109 senate_2019-11-26_R107 senate_2019… 2019-11-26 senate 
#>  3 senate_2019-11-26_R120 senate_2019-11-26_R119 senate_2019… 2019-11-26 senate 
#>  4 senate_2019-11-26_R133 senate_2019-11-26_R132 senate_2019… 2019-11-26 senate 
#>  5 senate_2019-11-26_R134 senate_2019-11-26_R132 senate_2019… 2019-11-26 senate 
#>  6 senate_2019-11-26_R135 senate_2019-11-26_R132 senate_2019… 2019-11-26 senate 
#>  7 senate_2019-11-26_R136 senate_2019-11-26_R132 senate_2019… 2019-11-26 senate 
#>  8 senate_2019-11-26_R137 senate_2019-11-26_R132 senate_2019… 2019-11-26 senate 
#>  9 senate_2019-11-26_R149 senate_2019-11-26_R148 senate_2019… 2019-11-26 senate 
#> 10 senate_2019-11-26_R179 senate_2019-11-26_R178 senate_2019… 2019-11-26 senate 
#> # ℹ 24 more rows
#> # ℹ 6 more variables: chamber_venue <int>, interjector_PHID <chr>,
#> #   interjector_name <chr>, target_PHID <chr>, target_name <chr>,
#> #   interjection_type <chr>
get_interjections(chamber = "Senate", columns = c("interjector_name", "target_name"))
#> # A tibble: 83 × 2
#>    interjector_name                  target_name                                
#>    <chr>                             <chr>                                      
#>  1 O'KEEFE, the Hon. David John, CMG PEARCE, the Rt. Hon. Sir George Foster, KC…
#>  2 O'KEEFE, the Hon. David John, CMG PEARCE, the Rt. Hon. Sir George Foster, KC…
#>  3 O'KEEFE, the Hon. David John, CMG PEARCE, the Rt. Hon. Sir George Foster, KC…
#>  4 FERRICKS, Myles Aloysius          PEARCE, the Rt. Hon. Sir George Foster, KC…
#>  5 GARDINER, the Hon. Albert         THOMAS, the Hon. Josiah                    
#>  6 THOMAS, the Hon. Josiah           GARDINER, the Hon. Albert                  
#>  7 MILLEN, the Hon. Edward Davis     GARDINER, the Hon. Albert                  
#>  8 THOMAS, the Hon. Josiah           GARDINER, the Hon. Albert                  
#>  9 GARDINER, the Hon. Albert         O'KEEFE, the Hon. David John, CMG          
#> 10 GARDINER, the Hon. Albert         O'KEEFE, the Hon. David John, CMG          
#> # ℹ 73 more rows
db_disconnect()
```
