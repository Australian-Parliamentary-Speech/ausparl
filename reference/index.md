# Package index

## Package overview

- [`ausparl`](https://australian-parliamentary-speech.github.io/ausparl/reference/ausparl-package.md)
  [`ausparl-package`](https://australian-parliamentary-speech.github.io/ausparl/reference/ausparl-package.md)
  : ausparl: Query the Australian Parliamentary Hansard Database

## Connecting to the database

Download, open and inspect the Hansard database.

- [`db_download()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_download.md)
  : Download the Hansard database
- [`db_connect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_connect.md)
  : Connect to the Hansard database
- [`db_disconnect()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_disconnect.md)
  : Disconnect from the Hansard database
- [`db_info()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_info.md)
  : Database version and size
- [`db_con()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_con.md)
  : The current database connection
- [`db_tbl()`](https://australian-parliamentary-speech.github.io/ausparl/reference/db_tbl.md)
  : A lazy table for any table or view

## Speeches and search

Turns, speeches and interjections, and full-text search over them.

- [`get_speeches()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speeches.md)
  : Get speeches and other turns
- [`get_speech_turns()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_speech_turns.md)
  : Get speech turns: consecutive actions by one speaker, merged
- [`search_speeches_by_terms()`](https://australian-parliamentary-speech.github.io/ausparl/reference/search_speeches_by_terms.md)
  : Search speeches for words and phrases
- [`get_sitting_timeline()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sitting_timeline.md)
  : Get the turns of a sitting in order
- [`get_interjections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_interjections.md)
  : Get interjections and their targets

## Members

- [`find_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/find_member.md)
  : Find members by name
- [`member_profile()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_profile.md)
  : Profile a member

## Activity summaries

- [`member_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/member_activity.md)
  : Activity per member
- [`party_activity()`](https://australian-parliamentary-speech.github.io/ausparl/reference/party_activity.md)
  : Activity per party
- [`parliament_summary()`](https://australian-parliamentary-speech.github.io/ausparl/reference/parliament_summary.md)
  : Summary per parliament

## Context on the day of a turn

Add what was true of the speaker on the sitting date.

- [`add_age()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_age.md)
  : Add the speaker's age at the time of each turn
- [`add_debate()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_debate.md)
  : Add the debate and subdebate of each turn
- [`add_electorate()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_electorate.md)
  : Add the speaker's electorate at the time of each turn
- [`add_government_status()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_government_status.md)
  : Add whether the speaker's party was in government at the time of
  each turn
- [`add_member()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_member.md)
  : Add member details to turns
- [`add_party()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_party.md)
  : Add the speaker's party at the time of each turn
- [`add_role()`](https://australian-parliamentary-speech.github.io/ausparl/reference/add_role.md)
  : Add the speaker's role at the time of each turn

## Transcript tables

- [`get_sittings()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_sittings.md)
  : Get sitting days
- [`get_debates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_debates.md)
  : Get debates
- [`get_subdebates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_subdebates.md)
  : Get subdebates
- [`get_actions()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_actions.md)
  : Get turns
- [`get_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_provenance.md)
  : Get source-file provenance

## Parliamentary Handbook tables

- [`get_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_members.md)
  : Get members
- [`get_parliaments()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parliaments.md)
  : Get parliaments
- [`get_parties()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parties.md)
  : Get parties
- [`get_electorates()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_electorates.md)
  : Get electorates
- [`get_elections()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_elections.md)
  : Get elections
- [`get_parl_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_parl_service.md)
  : Get parliamentary service periods
- [`get_party_service()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_party_service.md)
  : Get party membership periods
- [`get_ministries()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministries.md)
  : Get ministries
- [`get_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_ministry_records.md)
  : Get ministerial appointments
- [`get_shadow_ministry_records()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_shadow_ministry_records.md)
  : Get shadow ministerial appointments
- [`get_committee_members()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_committee_members.md)
  : Get committee memberships
- [`get_presiding_officers()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_presiding_officers.md)
  : Get presiding-office periods
- [`get_occupations()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_occupations.md)
  : Get member occupations
- [`get_qualifications()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_qualifications.md)
  : Get member qualifications
- [`get_schools()`](https://australian-parliamentary-speech.github.io/ausparl/reference/get_schools.md)
  : Get member schools

## Filter helpers

- [`in_range()`](https://australian-parliamentary-speech.github.io/ausparl/reference/in_range.md)
  : Filter by an inclusive range
- [`matches_pattern()`](https://australian-parliamentary-speech.github.io/ausparl/reference/matches_pattern.md)
  : Filter by a case-insensitive pattern

## Outputs

- [`as_corpus()`](https://australian-parliamentary-speech.github.io/ausparl/reference/as_corpus.md)
  : Convert a query result to a quanteda corpus
- [`result_provenance()`](https://australian-parliamentary-speech.github.io/ausparl/reference/result_provenance.md)
  : Source files behind a result
