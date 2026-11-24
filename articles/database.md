# The Hansard database

This vignette describes the database that ausparl queries: what it
contains, how its tables fit together, the identifiers that link them,
and the conventions behind its columns. It is a reference to keep open
while you work; for a worked analysis see
[`vignette("ausparl")`](https://australian-parliamentary-speech.github.io/ausparl/articles/ausparl.md).

Every example here runs on the small sample database bundled with the
package (eight sitting days), so the numbers are small. The full
database has the same tables, views and columns.

``` r

library(ausparl)
library(dplyr)
db_connect(sample = TRUE)
```

## What is in the database

The database is one DuckDB file, `hansard.duckdb`, built from two
sources:

- **Hansard**, the official record of debates in the House of
  Representatives and the Senate, from 1901. Each sitting day’s
  transcript is parsed into its debates, subdebates and the individual
  contributions (*actions*) within them, and each speaker is matched to
  a member.
- **The Parliamentary Handbook** of the Commonwealth of Australia, which
  supplies the members and their service, parties, ministries and shadow
  ministries, committees, presiding officers, electorates, elections,
  parliaments and biographical detail.

[`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md)
reports which build you are connected to. Quote its `schema_version` and
`built_at` in your methods, so that others can reproduce your numbers.

``` r

db_info() |>
  select(schema_version, built_at, n_sittings, n_actions, n_members)
#> # A tibble: 1 × 5
#>   schema_version built_at            n_sittings n_actions n_members
#>   <chr>          <dttm>                   <int>     <int>     <int>
#> 1 7.0.0          2026-11-23 13:40:39          8      1488       303
```

## How the tables fit together

The transcript tables nest, from the sitting day down to the single
contribution:

    sittings        one row per sitting day of one chamber
     └ debates      one row per debate within a sitting
        └ subdebates  one row per topic within a debate (subdebates can nest)
           └ actions  one row per contribution: a speech, question, answer,
                      interjection, quote or procedural note

The Handbook tables hang off two keys: `PHID`, which identifies a
member, and the date. A turn is linked to the member who made it through
`actions.PHID`, and to what was true of that member on the day (their
party, role, electorate) through the sitting date.

    members ── PHID ──┬── parl_service          seats held, with dates
                      ├── party_service         party memberships, with dates
                      ├── ministry_records      ministerial appointments
                      ├── shadow_ministry_records
                      ├── committee_members
                      ├── presiding_officers
                      └── occupations, qualifications, schools

## Identifiers

| Identifier | Identifies | Form | Example |
|----|----|----|----|
| `sitting_id` | a sitting day of one chamber | `<chamber>_<date>` | `house_2002-10-15` |
| `debate_id` | a debate within a sitting | sitting id + `_D<n>` | `house_2002-10-15_D3` |
| `subdebate_id` | a subdebate within a debate | debate id + `_S<n>` | `house_2002-10-15_D3_S1` |
| `action_id` | one action (contribution) | sitting id + `_R<n>` | `house_2002-10-15_R12` |
| `PHID` | a member | Parliamentary Handbook id | `ZD4` (John Howard) |
| `parliament_id` | a parliament | its number | `40` (2002-2004) |
| `party_id` | a party | integer | see [`get_parties()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parties.md) |
| `electorate_id` | an electorate | integer | see [`get_electorates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_electorates.md) |

Look a member’s `PHID` up from their name with
[`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md):

``` r

find_member("howard")
#> # A tibble: 2 × 8
#>   PHID  DisplayName           Gender DateOfBirth State chambers first_service last_service
#>   <chr> <chr>                 <chr>  <date>      <chr> <chr>    <date>        <date>      
#> 1 CT4   COSTELLO, the Hon. P… Male   1957-08-14  Vict… house    1990-03-24    2009-10-19  
#> 2 ZD4   HOWARD, the Hon. Joh… Male   1939-07-26  New … house    1974-05-18    2007-11-24
```

The sittings in the sample:

``` r

get_sittings()
#> # A tibble: 8 × 4
#>   sitting_id        chamber date       parliament_id
#>   <chr>             <chr>   <date>             <int>
#> 1 house_1902-10-10  house   1902-10-10             1
#> 2 house_1990-09-17  house   1990-09-17            36
#> 3 house_2002-10-15  house   2002-10-15            40
#> 4 house_2024-02-29  house   2024-02-29            47
#> 5 senate_1918-09-19 senate  1918-09-19             7
#> 6 senate_1983-05-10 senate  1983-05-10            33
#> 7 senate_2002-09-17 senate  2002-09-17            40
#> 8 senate_2019-11-26 senate  2019-11-26            46
```

A sitting’s debates and subdebates:

``` r

get_debates(sitting_id = "house_2002-10-15") |> head()
#> # A tibble: 6 × 4
#>   debate_id           sitting_id       title                     debate_order
#>   <chr>               <chr>            <chr>                            <int>
#> 1 house_2002-10-15_D1 house_2002-10-15 N/A                                  1
#> 2 house_2002-10-15_D2 house_2002-10-15 MINISTERIAL ARRANGEMENTS             2
#> 3 house_2002-10-15_D3 house_2002-10-15 QUESTIONS WITHOUT NOTICE             3
#> 4 house_2002-10-15_D4 house_2002-10-15 DISTINGUISHED VISITORS               4
#> 5 house_2002-10-15_D5 house_2002-10-15 QUESTIONS WITHOUT NOTICE             5
#> 6 house_2002-10-15_D6 house_2002-10-15 AUDITOR-GENERAL'S REPORTS            6
get_subdebates(debate_id = matches_pattern("house_2002-10-15_D%")) |> head()
#> # A tibble: 6 × 5
#>   subdebate_id            debate_id            title   subdebate_order parent_subdebate_id
#>   <chr>                   <chr>                <chr>             <int> <chr>              
#> 1 house_2002-10-15_D1_S1  house_2002-10-15_D1  N/A                   1 NA                 
#> 2 house_2002-10-15_D10_S1 house_2002-10-15_D10 Indone…               1 NA                 
#> 3 house_2002-10-15_D11_S1 house_2002-10-15_D11 N/A                   1 NA                 
#> 4 house_2002-10-15_D12_S1 house_2002-10-15_D12 Select…               1 NA                 
#> 5 house_2002-10-15_D12_S2 house_2002-10-15_D12 Family…               2 NA                 
#> 6 house_2002-10-15_D13_S1 house_2002-10-15_D13 N/A                   1 NA
```

## Actions and turns

`actions` is the core table: one row per contribution, with its text in
`content`. Each action has one `action_type`:

``` r

get_actions(columns = "action_type", collect = FALSE) |>
  count(action_type) |>
  collect()
#> # A tibble: 6 × 2
#>   action_type                 n
#>   <chr>                   <dbl>
#> 1 unresolved_interjection    16
#> 2 speech                    566
#> 3 answer                    229
#> 4 quote                      20
#> 5 procedural                488
#> 6 question                  169
```

- `speech`, `question` and `answer`: a member’s own contribution.
- `quote`: a passage read into the record, such as a letter or petition:
  not the speaker’s own words.
- `procedural`: a non-speech entry, such as “Mr Speaker took the chair”.
- `unresolved_interjection`: an interjection whose speaker the source
  does not identify.

Logical flags refine the type. `is_speech`, `is_question` and
`is_answer` mark a member’s substantive contributions, `is_interjection`
marks interjections (including resolved ones, which have
`action_type = "speech"`), and `has_quote` marks actions that contain
quoted material.
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
uses these flags: by default it returns speeches, questions and answers,
and leaves interjections out.

A speech interrupted by interjections, or continued across pages, is
several actions. Actions that belong to one uninterrupted contribution
share a `turn_no`, and
[`get_speech_turns()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speech_turns.md)
merges them into a single row per turn:

``` r

get_actions(
  sitting_id = "house_2002-10-15", is_non_speech = FALSE,
  columns = c("action_id", "turn_no", "PHID", "action_type", "is_interjection")
) |>
  arrange(turn_no) |>
  head(8)
#> # A tibble: 8 × 5
#>   action_id           turn_no PHID  action_type is_interjection
#>   <chr>                 <int> <chr> <chr>       <lgl>          
#> 1 house_2002-10-15_R2       1 ZD4   speech      FALSE          
#> 2 house_2002-10-15_R3       2 DT4   question    FALSE          
#> 3 house_2002-10-15_R4       3 ZD4   answer      FALSE          
#> 4 house_2002-10-15_R5       4 MH4   question    FALSE          
#> 5 house_2002-10-15_R6       5 7V5   answer      FALSE          
#> 6 house_2002-10-15_R7       6 4I4   question    FALSE          
#> 7 house_2002-10-15_R8       7 ZD4   answer      FALSE          
#> 8 house_2002-10-15_R9       8 AK6   question    FALSE

get_speech_turns(sitting_id = "house_2002-10-15", include_text = FALSE) |>
  select(turn_no, n_actions, PHID, party_at_time, is_quote) |>
  head()
#> # A tibble: 6 × 5
#>   turn_no n_actions PHID  party_at_time              is_quote
#>     <int>     <dbl> <chr> <chr>                      <lgl>   
#> 1       1         1 ZD4   Liberal Party of Australia FALSE   
#> 2       2         1 DT4   Australian Labor Party     FALSE   
#> 3       3         1 ZD4   Liberal Party of Australia FALSE   
#> 4       4         1 MH4   Liberal Party of Australia FALSE   
#> 5       5         1 7V5   Liberal Party of Australia FALSE   
#> 6       6         1 4I4   Australian Labor Party     FALSE
```

[`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md)
gives a sitting in document order, with the debate and subdebate titles,
and
[`get_interjections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_interjections.md)
pairs each interjection with the turn it interrupted.

``` r

get_sitting_timeline(sitting_id = "senate_2019-11-26", include_text = FALSE) |>
  filter(action_type != "procedural") |>
  select(seq, debate_title, action_type, speaker_name) |>
  head(8)
#> # A tibble: 8 × 4
#>     seq debate_title action_type speaker_name                             
#>   <int> <chr>        <chr>       <chr>                                    
#> 1    16 COMMITTEES   speech      NA                                       
#> 2    22 BILLS        speech      STEELE-JOHN, Jordon Alexander            
#> 3    24 BILLS        speech      BIRMINGHAM, the Hon. Simon John          
#> 4    25 BILLS        speech      GALLAGHER, the Hon. Katherine (Katy) Ruth
#> 5    26 BILLS        speech      STEELE-JOHN, Jordon Alexander            
#> 6    27 BILLS        speech      BIRMINGHAM, the Hon. Simon John          
#> 7    28 BILLS        speech      STEELE-JOHN, Jordon Alexander            
#> 8    29 BILLS        speech      LAMBIE, Jacquiline (Jacqui) Louise

get_interjections(chamber = "senate") |>
  select(date, interjector_name, target_name) |>
  head()
#> # A tibble: 6 × 3
#>   date       interjector_name                  target_name                                
#>   <date>     <chr>                             <chr>                                      
#> 1 1918-09-19 O'KEEFE, the Hon. David John, CMG PEARCE, the Rt. Hon. Sir George Foster, KC…
#> 2 1918-09-19 O'KEEFE, the Hon. David John, CMG PEARCE, the Rt. Hon. Sir George Foster, KC…
#> 3 1918-09-19 O'KEEFE, the Hon. David John, CMG PEARCE, the Rt. Hon. Sir George Foster, KC…
#> 4 1918-09-19 FERRICKS, Myles Aloysius          PEARCE, the Rt. Hon. Sir George Foster, KC…
#> 5 1918-09-19 GARDINER, the Hon. Albert         THOMAS, the Hon. Josiah                    
#> 6 1918-09-19 THOMAS, the Hon. Josiah           GARDINER, the Hon. Albert
```

## Who spoke

Each action records the speaker as printed (`name_raw`, `party_raw`,
`role_raw`, `electorate_raw`) and, where they could be matched, the
member’s `PHID`. The `resolution` column says how the speaker was
matched:

| `resolution` | Meaning | `PHID` |
|----|----|----|
| `resolved` | matched to one member | set |
| `sentinel` | the presiding officer (Speaker, President or their deputy) in the chair | `NA` |
| `collective` | a group, such as “Honourable members” or “Opposition members” | `NA` |
| `unknown` | the source records the speaker as unknown | `NA` |
| `unmatched` | a named speaker who could not be matched to a member | `NA` |
| `ambiguous` | a name that fits more than one member | `NA` |
| `non_member` | someone who is not a member, such as the Governor-General | `NA` |
| `NA` | no speaker: procedural entries, and quotes that name no reader | `NA` |

``` r

get_actions(columns = "resolution", collect = FALSE) |>
  count(resolution) |>
  collect()
#> # A tibble: 5 × 2
#>   resolution     n
#>   <chr>      <dbl>
#> 1 resolved     877
#> 2 collective    15
#> 3 NA           495
#> 4 unknown       17
#> 5 sentinel      84
```

Presiding-officer turns are left out of
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
unless `include_presiding = TRUE`, and a `member` filter keeps only
resolved turns.

## Context on the day

A member’s party, role and electorate change over time, so the database
holds them as dated periods (`party_service`, `ministry_records`,
`parl_service` and others). Views named `v_<thing>_at_time` resolve them
for each action on its sitting date, and the `add_*()` functions join
those views onto any result with an `action_id`:

| Function | Adds | From |
|----|----|----|
| [`add_party()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_party.md) | the speaker’s party and its abbreviation | `v_party_at_time` |
| [`add_role()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_role.md) | minister, shadow minister or backbencher | `v_role_at_time` |
| [`add_government_status()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_government_status.md) | whether the speaker’s party was in government | `v_government_status_at_time` |
| [`add_electorate()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_electorate.md) | the division or state the speaker represented | `v_electorate_at_time` |
| [`add_age()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_age.md) | age in years | `v_age_at_time` |
| [`add_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_member.md) | name, gender, state (not dated) | `members` |
| [`add_debate()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_debate.md) | debate and subdebate titles | `debates`, `subdebates` |

``` r

get_speeches(from = "2002-10-15", to = "2002-10-15", chamber = "house",
             include_text = FALSE, limit = 5) |>
  add_party() |>
  add_government_status() |>
  select(action_id, PHID, party_abbrev_at_time, government_status_at_time)
#> Skipping party_id_at_time and party_at_time: already in `x`.
#> # A tibble: 5 × 4
#>   action_id             PHID  party_abbrev_at_time government_status_at_time
#>   <chr>                 <chr> <chr>                <chr>                    
#> 1 house_2002-10-15_R10  SU5   NPA                  government               
#> 2 house_2002-10-15_R100 K26   ALP                  opposition               
#> 3 house_2002-10-15_R103 9V5   LIB                  government               
#> 4 house_2002-10-15_R105 9V5   LIB                  government               
#> 5 house_2002-10-15_R108 009CW ALP                  opposition
```

Turns without a `PHID` get `NA` in every added column.

## Handbook tables and their conventions

The Handbook tables keep the Handbook’s own column names (`DateStart`,
`DisplayName`, `MemberOrSenator`), so they read like the source. A few
conventions apply across them:

- **`_raw` columns** keep a value as it was in the source, beside a
  cleaned version: for example `DateEnd_raw` beside `DateEnd`, or
  `name_raw` beside `PHID`. Use the cleaned column for analysis and the
  raw one to check it.
- **`handbook_flag`** marks rows where the Handbook itself looks wrong
  or inconsistent, such as overlapping terms. Flagged rows are kept, not
  corrected.
- **`*_status` and `date_uncertain`** describe how an end date was
  derived, or that a date is not known exactly.
- **An end date of `NA`** means the period is ongoing (or its end is not
  recorded).
- **Display views.** Several getters take `display = TRUE`, which reads
  a `v_<table>_display` view that adds readable columns, such as the
  member’s `DisplayName` or the party colour.
- **`active_during`.** Getters for dated tables take `active_during`,
  which keeps the periods overlapping a year, a date or an
  [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md).

``` r

get_party_service(PHID = "ZD4", display = TRUE)
#> # A tibble: 1 × 9
#>   PHID  DateStart  DateEnd    Party      handbook_flag date_uncertain party_id DisplayName
#>   <chr> <date>     <date>     <chr>      <chr>         <lgl>             <int> <chr>      
#> 1 ZD4   1974-05-18 2007-11-24 Liberal P… NA            FALSE                 4 HOWARD, th…
#> # ℹ 1 more variable: PartyColour <chr>
get_ministry_records(PHID = "ZD4", active_during = 1996, display = TRUE) |>
  distinct(DisplayName, Role, Prep, Entity, RDateStart, RDateEnd)
#> # A tibble: 2 × 6
#>   DisplayName                       Role             Prep  Entity RDateStart RDateEnd  
#>   <chr>                             <chr>            <chr> <chr>  <date>     <date>    
#> 1 HOWARD, the Hon. John Winston, AC Prime Minister   ""    ""     1996-03-11 2007-12-03
#> 2 HOWARD, the Hon. John Winston, AC Cabinet Minister ""    ""     1996-03-11 2007-12-03
```

Parties that merged, split or renamed are linked in `party_lineage`, and
the spellings of party names found in the transcripts are mapped to
`party_id` in `party_alias`. Neither has a getter; read them with
[`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md):

``` r

db_tbl("party_lineage") |> collect()
#> # A tibble: 9 × 5
#>   party_id related_party_id relation       from_date  note                                
#>      <int>            <int> <chr>          <date>     <chr>                               
#> 1       11               81 grouped_rename NA         Pauline Hanson's One Nation (11) an…
#> 2       27               17 grouped_rename 1906-01-01 Free Trade renamed Anti-Socialist; …
#> 3        6               65 grouped_rename NA         Nick Xenophon Team renamed Centre A…
#> 4       14               24 grouped_rename NA         Australian Labor Party (Anti-Commun…
#> 5       52                4 not_grouped    1945-02-21 Liberal Party of Australia (1944) i…
#> 6        9               57 not_grouped    2017-04-01 Family First merged into the Austra…
#> 7       50               24 not_grouped    1962-10-01 Queensland Labor Party became the D…
#> 8       49               74 not_grouped    NA         Palmer United Party vs United Austr…
#> 9       37               22 label_only     NA         Victorian Liberal and Country Party…
```

## All tables and views

``` r

DBI::dbGetQuery(db_con(), "
  SELECT table_name AS name,
         CASE table_type WHEN 'VIEW' THEN 'view' ELSE 'table' END AS type
  FROM information_schema.tables
  WHERE table_schema = 'main'
  ORDER BY type, name
")
#>                                 name  type
#> 1                            actions table
#> 2                  committee_members table
#> 3                            debates table
#> 4                          elections table
#> 5                        electorates table
#> 6                            members table
#> 7                         ministries table
#> 8                   ministry_records table
#> 9                        occupations table
#> 10                      parl_service table
#> 11                       parliaments table
#> 12                      parse_errors table
#> 13                           parties table
#> 14                       party_alias table
#> 15                     party_lineage table
#> 16                     party_service table
#> 17                presiding_officers table
#> 18                        provenance table
#> 19                    qualifications table
#> 20                    schema_version table
#> 21                           schools table
#> 22           shadow_ministry_records table
#> 23                          sittings table
#> 24                        subdebates table
#> 25                 v_actions_display  view
#> 26                     v_age_at_time  view
#> 27       v_committee_members_display  view
#> 28              v_electorate_at_time  view
#> 29       v_government_status_at_time  view
#> 30             v_interjection_target  view
#> 31                 v_members_display  view
#> 32        v_ministry_records_display  view
#> 33            v_parl_service_display  view
#> 34                   v_party_at_time  view
#> 35           v_party_service_display  view
#> 36                    v_role_at_time  view
#> 37 v_shadow_ministry_records_display  view
#> 38                v_sitting_timeline  view
#> 39                          v_speech  view
#> 40                    v_speech_turns  view
#> 41            v_speech_turns_context  view
```

| Table | One row per | Getter |
|----|----|----|
| `sittings` | sitting day | [`get_sittings()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sittings.md) |
| `debates` | debate | [`get_debates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_debates.md) |
| `subdebates` | subdebate | [`get_subdebates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_subdebates.md) |
| `actions` | action (contribution) | [`get_actions()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_actions.md) |
| `provenance` | source file | [`get_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_provenance.md) |
| `members` | member | [`get_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_members.md) |
| `parliaments` | parliament | [`get_parliaments()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parliaments.md) |
| `parties` | party | [`get_parties()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parties.md) |
| `electorates` | electorate | [`get_electorates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_electorates.md) |
| `elections` | election | [`get_elections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_elections.md) |
| `parl_service` | period of service in a seat | [`get_parl_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parl_service.md) |
| `party_service` | period of party membership | [`get_party_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_party_service.md) |
| `ministries` | ministry and governing party | [`get_ministries()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministries.md) |
| `ministry_records` | ministerial appointment | [`get_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministry_records.md) |
| `shadow_ministry_records` | shadow ministerial appointment | [`get_shadow_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_shadow_ministry_records.md) |
| `committee_members` | committee membership | [`get_committee_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_committee_members.md) |
| `presiding_officers` | presiding office held | [`get_presiding_officers()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_presiding_officers.md) |
| `occupations`, `qualifications`, `schools` | member and item | [`get_occupations()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_occupations.md), [`get_qualifications()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_qualifications.md), [`get_schools()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_schools.md) |
| `party_alias`, `party_lineage` | party name spelling; party relation | [`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md) |
| `schema_version` | the build (one row) | [`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md) |
| `parse_errors` | transcript that could not be parsed | [`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md) |

The columns of any table or view are listed by
`colnames(db_tbl("<name>"))`, and every getter’s help page lists its
columns as filter arguments.

## Provenance

Every sitting can be traced to the transcript file it was parsed from,
with the file’s SHA-256 checksum and the parser generation that read it.
[`result_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/result_provenance.md)
does this for any result:

``` r

get_speeches(from = "1902-10-10", to = "1902-10-10", include_text = FALSE, limit = 3) |>
  result_provenance()
#> # A tibble: 1 × 8
#>   path    sha256 schema_generation parsed_at           input_row_count output_action_count
#>   <chr>   <chr>  <chr>             <dttm>                        <int>               <int>
#> 1 ../dat… 5261c… v2.1              2026-11-23 10:31:39             105                 102
#> # ℹ 2 more variables: sitting_id <chr>, source <chr>
```

``` r

db_disconnect()
```
