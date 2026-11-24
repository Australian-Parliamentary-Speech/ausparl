# Profile a member

Collects everything the database records about one member, from the nine
per-member tables. Each element is exactly what the matching getter
returns for the member's PHID, so the profile adds no new query logic.

## Usage

``` r
member_profile(PHID)
```

## Arguments

- PHID:

  A single member PHID. Look one up with
  [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md).

## Value

A named list of nine tibbles: `members`
([`get_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_members.md)),
`parl_service`
([`get_parl_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parl_service.md)),
`party_service`
([`get_party_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_party_service.md)),
`ministry_records`
([`get_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministry_records.md)),
`shadow_ministry_records`
([`get_shadow_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_shadow_ministry_records.md)),
`committee_members`
([`get_committee_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_committee_members.md)),
`occupations`
([`get_occupations()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_occupations.md)),
`qualifications`
([`get_qualifications()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_qualifications.md))
and `schools`
([`get_schools()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_schools.md)).
A table with nothing recorded for the member is a zero-row tibble.

## See also

[`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md),
[`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md)

## Examples

``` r
db_connect(sample = TRUE)
howard <- member_profile("ZD4")
names(howard)
#> [1] "members"                 "parl_service"           
#> [3] "party_service"           "ministry_records"       
#> [5] "shadow_ministry_records" "committee_members"      
#> [7] "occupations"             "qualifications"         
#> [9] "schools"                
howard$parl_service
#> # A tibble: 13 × 11
#>    PHID  MemberOrSenator Electorate DateStart  DateEnd    Description           
#>    <chr> <chr>           <chr>      <date>     <date>     <chr>                 
#>  1 ZD4   Member          Bennelong  1974-05-18 1975-12-13 Elected to the House …
#>  2 ZD4   Member          Bennelong  1975-12-13 1977-12-10 Re-elected 1975       
#>  3 ZD4   Member          Bennelong  1977-12-10 1980-10-18 Re-elected 1977       
#>  4 ZD4   Member          Bennelong  1980-10-18 1983-03-05 Re-elected 1980       
#>  5 ZD4   Member          Bennelong  1983-03-05 1984-12-01 Re-elected 1983       
#>  6 ZD4   Member          Bennelong  1984-12-01 1987-07-11 Re-elected 1984       
#>  7 ZD4   Member          Bennelong  1987-07-11 1990-03-24 Re-elected 1987       
#>  8 ZD4   Member          Bennelong  1990-03-24 1993-03-13 Re-elected 1990       
#>  9 ZD4   Member          Bennelong  1993-03-13 1996-03-02 Re-elected 1993       
#> 10 ZD4   Member          Bennelong  1996-03-02 1998-10-03 Re-elected 1996       
#> 11 ZD4   Member          Bennelong  1998-10-03 2001-11-10 Re-elected 1998       
#> 12 ZD4   Member          Bennelong  2001-11-10 2004-10-09 Re-elected 2001       
#> 13 ZD4   Member          Bennelong  2004-10-09 2007-11-24 Re-elected 2004. Defe…
#> # ℹ 5 more variables: handbook_flag <chr>, DateStart_raw <date>,
#> #   DateEnd_raw <date>, electorate_id <int>, DateEnd_status <chr>
db_disconnect()
```
