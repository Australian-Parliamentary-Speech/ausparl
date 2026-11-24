# Convert a query result to a quanteda corpus

Hands a speech result to [quanteda](https://quanteda.io) as a corpus:
one document per row, named by `docid_field`, with text from
`text_field` and every other column as a document variable (docvar).
Docvars keep their names, values and types: dates stay `Date`s and flags
stay logical.

## Usage

``` r
as_corpus(x, text_field = "content", docid_field = "action_id")
```

## Arguments

- x:

  A tibble or data frame, or a lazy table from an ausparl function with
  `collect = FALSE`, with one row per document.

- text_field:

  Name of the character column holding the text. Results fetched with
  `include_text = FALSE` have no `content` column; fetch them with
  `include_text = TRUE`.

- docid_field:

  Name of the column holding the document names. Its values must be
  unique and not `NA`.

## Value

A quanteda `corpus` with one document per row of `x`.

## Details

`x` is usually the output of
[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
or
[`search_speeches_by_terms()`](https://australian-parliamentary-speech.github.io/ausparl/reference/search_speeches_by_terms.md),
possibly after `add_*()` helpers such as
[`add_party()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_party.md);
the added columns become docvars.

A lazy table (`collect = FALSE`) is collected first. A result with a
`content` column is held to the text size ceiling,
`getOption("ausparl.max_rows_text")`; above it the call is an error.

The text is never edited. `NA` text is passed to quanteda as it is, and
quanteda's own conversion applies (it currently becomes an empty
document, with a warning).

This function only builds the corpus; tokenising, document-feature
matrices and analysis are left to quanteda.

## See also

[`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md),
[`search_speeches_by_terms()`](https://australian-parliamentary-speech.github.io/ausparl/reference/search_speeches_by_terms.md)

## Examples

``` r
db_connect(sample = TRUE)
speeches <- get_speeches(from = 2002, to = 2002, limit = 20)
corp <- as_corpus(speeches)
corp
#> corpus of 20 documents (131,646 characters) and 17 docvars.
#> house_2002-10-15_R10 :
#> "I thank the honourable member for Gilmore for her question. ..."
#> 
#> house_2002-10-15_R100 :
#> "We have a problem of narrowness of media opinion in this cou..."
#> 
#> house_2002-10-15_R103 :
#> "Before I touch on particular aspects of the Broadcasting Ser..."
#> 
#> house_2002-10-15_R105 :
#> "That is exactly right. As the minister has pointed out, he h..."
#> 
#> house_2002-10-15_R108 :
#> "I rise to put on record my deep concern at the changes propo..."
#> 
#> house_2002-10-15_R11 :
#> "My question is to the Minister for Ageing representing the M..."
#> 
#> [ reached max_ndoc ... 14 more documents ]
head(quanteda::docvars(corp))
#>         sitting_id       date chamber chamber_venue parliament_id  PHID
#> 1 house_2002-10-15 2002-10-15   house             1            40   SU5
#> 2 house_2002-10-15 2002-10-15   house             1            40   K26
#> 3 house_2002-10-15 2002-10-15   house             1            40   9V5
#> 4 house_2002-10-15 2002-10-15   house             1            40   9V5
#> 5 house_2002-10-15 2002-10-15   house             1            40 009CW
#> 6 house_2002-10-15 2002-10-15   house             1            40   5V5
#>             name_raw party_id_at_time               party_at_time is_speech
#> 1    Vaile, Mark, MP               60 National Party of Australia     FALSE
#> 2   Latham, Mark, MP                1      Australian Labor Party      TRUE
#> 3    Pyne, Chris, MP                4  Liberal Party of Australia      TRUE
#> 4    Pyne, Chris, MP                4  Liberal Party of Australia      TRUE
#> 5  Corcoran, Ann, MP                1      Australian Labor Party      TRUE
#> 6 Smith, Stephen, MP                1      Australian Labor Party     FALSE
#>   is_question is_answer is_interjection is_non_speech is_petition
#> 1       FALSE      TRUE           FALSE         FALSE       FALSE
#> 2       FALSE     FALSE           FALSE         FALSE       FALSE
#> 3       FALSE     FALSE           FALSE         FALSE       FALSE
#> 4       FALSE     FALSE           FALSE         FALSE       FALSE
#> 5       FALSE     FALSE           FALSE         FALSE       FALSE
#> 6        TRUE     FALSE           FALSE         FALSE       FALSE
#>   is_motion_no_speech has_quote
#> 1               FALSE     FALSE
#> 2               FALSE      TRUE
#> 3               FALSE     FALSE
#> 4               FALSE      TRUE
#> 5               FALSE      TRUE
#> 6               FALSE     FALSE
db_disconnect()
```
