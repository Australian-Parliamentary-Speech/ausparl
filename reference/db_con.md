# The current database connection

Returns the package connection, opening one if needed: the last database
used in this session if there was one, otherwise the database
[`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
finds with no arguments (`AUSPARL_DB`, then the copy installed by
[`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)).
Every query function calls this, so you rarely need it directly.

## Usage

``` r
db_con()
```

## Value

A DBI connection.

## Examples

``` r
db_connect(sample = TRUE)
DBI::dbListTables(db_con())
#>  [1] "actions"                           "committee_members"                
#>  [3] "debates"                           "dict"                             
#>  [5] "docs"                              "elections"                        
#>  [7] "electorates"                       "fields"                           
#>  [9] "members"                           "ministries"                       
#> [11] "ministry_records"                  "occupations"                      
#> [13] "parl_service"                      "parliaments"                      
#> [15] "parse_errors"                      "parties"                          
#> [17] "party_alias"                       "party_lineage"                    
#> [19] "party_service"                     "presiding_officers"               
#> [21] "provenance"                        "qualifications"                   
#> [23] "schema_version"                    "schools"                          
#> [25] "shadow_ministry_records"           "sittings"                         
#> [27] "stats"                             "stopwords"                        
#> [29] "subdebates"                        "terms"                            
#> [31] "v_actions_display"                 "v_age_at_time"                    
#> [33] "v_committee_members_display"       "v_electorate_at_time"             
#> [35] "v_government_status_at_time"       "v_interjection_target"            
#> [37] "v_members_display"                 "v_ministry_records_display"       
#> [39] "v_parl_service_display"            "v_party_at_time"                  
#> [41] "v_party_service_display"           "v_role_at_time"                   
#> [43] "v_shadow_ministry_records_display" "v_sitting_timeline"               
#> [45] "v_speech"                          "v_speech_turns"                   
#> [47] "v_speech_turns_context"           
db_disconnect()
```
