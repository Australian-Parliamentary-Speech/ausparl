# Get speeches and other turns

Returns turns (actions) from the `v_speech` view, the substantive turns
of debate, filtered by research criteria. Each row is one turn, with its
sitting, its speaker and the speaker's party at the time.

## Usage

``` r
get_speeches(
  member = NULL,
  party = NULL,
  parliament_id = NULL,
  chamber = NULL,
  chamber_venue = NULL,
  from = NULL,
  to = NULL,
  type = c("speech", "question", "answer"),
  include_presiding = FALSE,
  include_text = TRUE,
  columns = NULL,
  collect = TRUE,
  limit = NULL
)
```

## Arguments

- member:

  Character vector of member PHIDs. A PHID that matches no member is an
  error; look one up with
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md).

- party:

  Party ids (numbers) or party names or abbreviations (strings); see
  Details.

- parliament_id:

  Filter on the sitting's `parliament_id`: a vector of values or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- chamber:

  `"house"` and/or `"senate"`, in any case.

- chamber_venue:

  Filter on the turn's `chamber_venue`: a vector of values or
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

- from, to:

  Sitting-date bounds, inclusive: a year (covering the whole year), a
  `Date`, or a `"YYYY-MM-DD"` string. `NULL` leaves that end open.

- type:

  Turn types to return: any of `"speech"`, `"question"`, `"answer"` and
  `"interjection"`. Defaults to all but `"interjection"`.

- include_presiding:

  If `TRUE`, also return presiding-officer turns.

- include_text:

  If `TRUE` (the default), add the `content` column. Results with
  `content` are held to the lower size ceiling,
  `getOption("ausparl.max_rows_text")`.

- columns:

  Character vector of columns to return; `NULL` returns all.

- collect:

  If `TRUE` (the default), return a tibble; if `FALSE`, a lazy table for
  further dplyr work.

- limit:

  Maximum number of rows to return, or `NULL` for no limit.

## Value

A tibble with one row per turn and columns `action_id`, `sitting_id`,
`date`, `chamber`, `chamber_venue`, `parliament_id`, `PHID`, `name_raw`,
`party_id_at_time`, `party_at_time`, `is_speech`, `is_question`,
`is_answer`, `is_interjection`, `is_non_speech`, `is_petition`,
`is_motion_no_speech`, `has_quote`, and `content` when
`include_text = TRUE`. Rows are not in any set order. Zero rows if
nothing matches; a lazy table if `collect = FALSE`.

## Details

**Turn types.** `type` is resolved over flag columns, never
`action_type`: `"speech"` keeps rows with `is_speech`, `"question"`
`is_question`, `"answer"` `is_answer` and `"interjection"`
`is_interjection`, combined with OR. A row with `is_interjection = TRUE`
is left out unless `"interjection"` is in `type`, even when another
requested flag is also set. So by default no interjections are returned;
`type = "interjection"` returns only interjections.

**Quoted passages.** `v_speech` also holds `action_type = "quote"` rows:
a passage read into the record. None of the four type flags is set on
them, so they are never returned here; read them with
[`get_actions()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_actions.md)
(`action_type = "quote"`). A quote that names no reader has a missing
(`NA`) `resolution`.

**Presiding officers and speakers who are not one member.** Turns by the
presiding officer (`resolution = "sentinel"` in `actions`) have no PHID
and are left out unless `include_presiding = TRUE`. These turns also
have no PHID, and are kept with `PHID` and the party columns `NA`:

- `resolution = "unmatched"`: a named speaker who could not be matched
  to a member.

- `"unknown"`: the source records the speaker as unknown.

- `"collective"`: a group speaking together, such as the Opposition or
  "Honourable members".

- `"non_member"`: a speaker who is not a member, such as the
  Governor-General or a visitor.

A `member` filter drops all of these.

**Party.** `party_at_time` is the speaker's party on the sitting date,
and `party_id_at_time` its `party_id`. `party` filters on the party at
the time, by id or name, resolved in this order, ignoring case:

1.  A number is a `party_id`.

2.  A string matching a party's `Abbrev` or `Name` exactly selects that
    party. If it matches several (for example `"LIB"`), it is an error
    listing their ids; pass the id instead.

3.  Otherwise a string that occurs in exactly one party's `Name` selects
    that party. If it occurs in several (for example `"Labor"`) it is an
    error listing them, and if in none, an error saying so.

Party lineage is not followed: `"ALP"` is party 1 only, not its splinter
parties. Stored values are returned unchanged.

## See also

[`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md),
[`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md),
[`get_interjections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_interjections.md)

## Examples

``` r
db_connect(sample = TRUE)
howard <- find_member("john howard")$PHID
get_speeches(member = howard, include_text = FALSE)
#> # A tibble: 5 × 18
#>   action_id      sitting_id date       chamber chamber_venue parliament_id PHID 
#>   <chr>          <chr>      <date>     <chr>           <int>         <int> <chr>
#> 1 house_2002-10… house_200… 2002-10-15 house               1            40 ZD4  
#> 2 house_2002-10… house_200… 2002-10-15 house               1            40 ZD4  
#> 3 house_2002-10… house_200… 2002-10-15 house               1            40 ZD4  
#> 4 house_2002-10… house_200… 2002-10-15 house               1            40 ZD4  
#> 5 house_2002-10… house_200… 2002-10-15 house               1            40 ZD4  
#> # ℹ 11 more variables: name_raw <chr>, party_id_at_time <int>,
#> #   party_at_time <chr>, is_speech <lgl>, is_question <lgl>, is_answer <lgl>,
#> #   is_interjection <lgl>, is_non_speech <lgl>, is_petition <lgl>,
#> #   is_motion_no_speech <lgl>, has_quote <lgl>
get_speeches(party = "ALP", from = 2002, to = 2002, columns = c("date", "name_raw"))
#> # A tibble: 70 × 2
#>    date       name_raw             
#>    <date>     <chr>                
#>  1 2002-10-15 Latham, Mark, MP     
#>  2 2002-10-15 Corcoran, Ann, MP    
#>  3 2002-10-15 Smith, Stephen, MP   
#>  4 2002-10-15 O'Connor, Brendan, MP
#>  5 2002-10-15 Hatton, Michael, MP  
#>  6 2002-10-15 Hatton, Michael, MP  
#>  7 2002-10-15 Wilkie, Kim, MP      
#>  8 2002-10-15 Snowdon, Warren, MP  
#>  9 2002-10-15 Albanese, Anthony, MP
#> 10 2002-10-15 Macklin, Jenny, MP   
#> # ℹ 60 more rows
get_speeches(type = "interjection", chamber = "senate", limit = 5)
#> # A tibble: 5 × 19
#>   action_id      sitting_id date       chamber chamber_venue parliament_id PHID 
#>   <chr>          <chr>      <date>     <chr>           <int>         <int> <chr>
#> 1 senate_1918-0… senate_19… 1918-09-19 senate              1             7 JZ9  
#> 2 senate_1918-0… senate_19… 1918-09-19 senate              1             7 JZ9  
#> 3 senate_1918-0… senate_19… 1918-09-19 senate              1             7 JZ9  
#> 4 senate_1918-0… senate_19… 1918-09-19 senate              1             7 JYT  
#> 5 senate_1918-0… senate_19… 1918-09-19 senate              1             7 KKZ  
#> # ℹ 12 more variables: name_raw <chr>, party_id_at_time <int>,
#> #   party_at_time <chr>, is_speech <lgl>, is_question <lgl>, is_answer <lgl>,
#> #   is_interjection <lgl>, is_non_speech <lgl>, is_petition <lgl>,
#> #   is_motion_no_speech <lgl>, has_quote <lgl>, content <chr>
db_disconnect()
```
