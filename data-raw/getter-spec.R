# Per-table spec for the generated single-table getters. Read by data-raw/generate-getters.R,
# which takes the columns from the database catalog and everything else from here.
#
# Fields per table (list order is the order of getters in R/query-tables.R):
#   title          roxygen title, sentence case, no full stop
#   grain          what one row is (completes "one row per ..." in the generated docs)
#   purpose        one-line query purpose
#   display        the v_<table>_display view read when display = TRUE, or NULL
#   active_during  c(start, end) columns driving active_during, or NULL
#   example        the filter arguments of the @examples call, as R source

getter_spec <- list(
  sittings = list(
    title = "Get sitting days",
    grain = "sitting day",
    purpose = "Which days sat, by chamber and parliament.",
    display = NULL,
    active_during = NULL,
    example = 'chamber = "House"'
  ),
  debates = list(
    title = "Get debates",
    grain = "debate",
    purpose = "Debate titles and their order within a sitting.",
    display = NULL,
    active_during = NULL,
    example = 'sitting_id = "house_2002-10-15"'
  ),
  subdebates = list(
    title = "Get subdebates",
    grain = "subdebate",
    purpose = "Nested topics within a debate.",
    display = NULL,
    active_during = NULL,
    example = 'title = matches_pattern("%immigration%")'
  ),
  actions = list(
    title = "Get turns",
    grain = "turn (action)",
    purpose = paste(
      "Turns by exact column values, e.g. all question turns in 1977. Interjections are",
      "included: no turn-type filter is applied unless you pass one."
    ),
    display = "v_actions_display",
    active_during = NULL,
    example = 'action_type = "question", year = in_range(1990, 2000)'
  ),
  provenance = list(
    title = "Get source-file provenance",
    grain = "source file",
    purpose = "Trace a sitting back to its source file and checksum.",
    display = NULL,
    active_during = NULL,
    example = 'source = "csv"'
  ),
  members = list(
    title = "Get members",
    grain = "member",
    purpose = paste(
      "Biographical attributes: gender, birth date, state. `display = TRUE` adds the",
      "latest party and electorate."
    ),
    display = "v_members_display",
    active_during = NULL,
    example = 'Gender = "Female", StateAbbrev = c("Vic", "Tas")'
  ),
  parliaments = list(
    title = "Get parliaments",
    grain = "parliament",
    purpose = "Parliament numbers and their dates.",
    display = NULL,
    active_during = NULL,
    example = "parliament_id = in_range(38, 40)"
  ),
  parties = list(
    title = "Get parties",
    grain = "party",
    purpose = "Look up party names, abbreviations and ids.",
    display = NULL,
    active_during = NULL,
    example = 'Abbrev = c("ALP", "LP")'
  ),
  electorates = list(
    title = "Get electorates",
    grain = "electorate",
    purpose = "Electorate names, states and the dates they existed.",
    display = NULL,
    active_during = NULL,
    example = 'StateAbbrev = "Tas"'
  ),
  parl_service = list(
    title = "Get parliamentary service periods",
    grain = "service period",
    purpose = "Who held which seat, and when.",
    display = "v_parl_service_display",
    active_during = c("DateStart", "DateEnd"),
    example = 'MemberOrSenator = "Senator", active_during = 1996'
  ),
  party_service = list(
    title = "Get party membership periods",
    grain = "party membership period",
    purpose = "Party affiliation history, and the members of a party in a period.",
    display = "v_party_service_display",
    active_during = c("DateStart", "DateEnd"),
    example = "party_id = 1, active_during = in_range(1990, 1995)"
  ),
  ministries = list(
    title = "Get ministries",
    grain = "ministry and governing party",
    purpose = "Which ministry governed in a period.",
    display = NULL,
    active_during = c("DateStart", "DateEnd"),
    example = "active_during = 1975"
  ),
  ministry_records = list(
    title = "Get ministerial appointments",
    grain = "ministerial appointment",
    purpose = "Front-bench roles and portfolios.",
    display = "v_ministry_records_display",
    active_during = c("RDateStart", "RDateEnd"),
    example = 'Role = matches_pattern("%treasurer%"), active_during = 2000'
  ),
  shadow_ministry_records = list(
    title = "Get shadow ministerial appointments",
    grain = "shadow appointment",
    purpose = "Opposition front-bench roles.",
    display = "v_shadow_ministry_records_display",
    active_during = c("RDateStart", "RDateEnd"),
    example = "active_during = 2000"
  ),
  committee_members = list(
    title = "Get committee memberships",
    grain = "committee membership",
    purpose = "Committee roles and dates.",
    display = "v_committee_members_display",
    active_during = c("start_date", "end_date"),
    example = 'committee_area = matches_pattern("%legislation%"), active_during = 2001'
  ),
  presiding_officers = list(
    title = "Get presiding-office periods",
    grain = "presiding-office period",
    purpose = paste(
      "Who held a presiding office (Speaker, President, deputies, panels), and when.",
      "`Chamber` holds \"House\" or \"Senate\" as stored (capitalised, matched exactly)."
    ),
    display = NULL,
    active_during = c("DateStart", "DateEnd"),
    example = 'Chamber = "Senate", active_during = 2000'
  ),
  elections = list(
    title = "Get elections",
    grain = "election",
    purpose = "Election dates by parliament.",
    display = NULL,
    active_during = NULL,
    example = "Byelection = FALSE, Year = in_range(1990, 2000)"
  ),
  occupations = list(
    title = "Get member occupations",
    grain = "member and occupation (a member may have several, or none)",
    purpose = "Prior occupations, e.g. lawyers.",
    display = NULL,
    active_during = NULL,
    example = 'Occupation = matches_pattern("%barrister%")'
  ),
  qualifications = list(
    title = "Get member qualifications",
    grain = "member and qualification (a member may have several, or none)",
    purpose = "Education background.",
    display = NULL,
    active_during = NULL,
    example = 'Qualification = matches_pattern("%laws%")'
  ),
  schools = list(
    title = "Get member schools",
    grain = "member and school (a member may have several, or none)",
    purpose = "Schooling background.",
    display = NULL,
    active_during = NULL,
    example = 'secondary_school = matches_pattern("%grammar%")'
  )
)
