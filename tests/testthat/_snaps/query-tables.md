# T-4.4 G13: rendered SQL for one representative call per getter

    Code
      render(get_sittings(chamber = "House", collect = FALSE))
    Output
      <SQL> SELECT *
      FROM sittings
      WHERE (chamber = 'house')

---

    Code
      render(get_debates(sitting_id = "house_1996-05-02", collect = FALSE))
    Output
      <SQL> SELECT *
      FROM debates
      WHERE (sitting_id = 'house_1996-05-02')

---

    Code
      render(get_subdebates(title = matches_pattern("%question%"), collect = FALSE))
    Output
      <SQL> SELECT *
      FROM subdebates
      WHERE (title ILIKE '%question%')

---

    Code
      render(get_actions(action_type = c("question", "answer"), year = in_range(1990,
        2000), display = TRUE, collect = FALSE))
    Output
      <SQL> SELECT *
      FROM v_actions_display
      WHERE
        (action_type IN ('question', 'answer')) AND
        ("year" >= 1990.0) AND
        ("year" <= 2000.0)

---

    Code
      render(get_provenance(source = "csv", collect = FALSE))
    Output
      <SQL> SELECT *
      FROM provenance
      WHERE ("source" = 'csv')

---

    Code
      render(get_members(Gender = "Female", StateAbbrev = c("Vic", "Tas"), collect = FALSE))
    Output
      <SQL> SELECT *
      FROM members
      WHERE (Gender = 'Female') AND (StateAbbrev IN ('Vic', 'Tas'))

---

    Code
      render(get_parliaments(parliament_id = in_range(38, 40), collect = FALSE))
    Output
      <SQL> SELECT *
      FROM parliaments
      WHERE (parliament_id >= 38.0) AND (parliament_id <= 40.0)

---

    Code
      render(get_parties(Abbrev = c("ALP", "LP"), collect = FALSE))
    Output
      <SQL> SELECT *
      FROM parties
      WHERE (Abbrev IN ('ALP', 'LP'))

---

    Code
      render(get_electorates(StateAbbrev = "Tas", collect = FALSE))
    Output
      <SQL> SELECT *
      FROM electorates
      WHERE (StateAbbrev = 'Tas')

---

    Code
      render(get_parl_service(MemberOrSenator = "Senator", active_during = 1996,
        collect = FALSE))
    Output
      <SQL> SELECT *
      FROM parl_service
      WHERE
        (MemberOrSenator = 'Senator') AND
        (DateStart <= '1996-12-31'::date) AND
        ((DateEnd IS NULL) OR DateEnd >= '1996-01-01'::date)

---

    Code
      render(get_party_service(party_id = 1, active_during = in_range(1990, 1995),
      display = TRUE, collect = FALSE))
    Output
      <SQL> SELECT *
      FROM v_party_service_display
      WHERE
        (party_id = 1.0) AND
        (DateStart <= '1995-12-31'::date) AND
        ((DateEnd IS NULL) OR DateEnd >= '1990-01-01'::date)

---

    Code
      render(get_ministries(active_during = 1975, collect = FALSE))
    Output
      <SQL> SELECT *
      FROM ministries
      WHERE
        (DateStart <= '1975-12-31'::date) AND
        ((DateEnd IS NULL) OR DateEnd >= '1975-01-01'::date)

---

    Code
      render(get_ministry_records(Role = matches_pattern("%treasurer%"),
      active_during = 2000, collect = FALSE))
    Output
      <SQL> SELECT *
      FROM ministry_records
      WHERE
        ("Role" ILIKE '%treasurer%') AND
        (RDateStart <= '2000-12-31'::date) AND
        ((RDateEnd IS NULL) OR RDateEnd >= '2000-01-01'::date)

---

    Code
      render(get_shadow_ministry_records(active_during = 2000, collect = FALSE))
    Output
      <SQL> SELECT *
      FROM shadow_ministry_records
      WHERE
        (RDateStart <= '2000-12-31'::date) AND
        ((RDateEnd IS NULL) OR RDateEnd >= '2000-01-01'::date)

---

    Code
      render(get_committee_members(PHID = "008W7", active_during = 2001, display = TRUE,
        columns = c("PHID", "DisplayName"), collect = FALSE))
    Output
      <SQL> SELECT PHID, DisplayName
      FROM v_committee_members_display
      WHERE
        (PHID = '008W7') AND
        (start_date <= '2001-12-31'::date) AND
        ((end_date IS NULL) OR end_date >= '2001-01-01'::date)

---

    Code
      render(get_presiding_officers(Chamber = "Senate", active_during = 2000,
        collect = FALSE))
    Output
      <SQL> SELECT *
      FROM presiding_officers
      WHERE
        (Chamber = 'Senate') AND
        (DateStart <= '2000-12-31'::date) AND
        ((DateEnd IS NULL) OR DateEnd >= '2000-01-01'::date)

---

    Code
      render(get_elections(Byelection = FALSE, Year = in_range(1990, 2000), collect = FALSE))
    Output
      <SQL> SELECT *
      FROM elections
      WHERE ("Year" >= 1990.0) AND ("Year" <= 2000.0) AND (Byelection = FALSE)

---

    Code
      render(get_occupations(Occupation = matches_pattern("%barrister%"), collect = FALSE))
    Output
      <SQL> SELECT *
      FROM occupations
      WHERE (Occupation ILIKE '%barrister%')

---

    Code
      render(get_qualifications(PHID = "008W7", collect = FALSE))
    Output
      <SQL> SELECT *
      FROM qualifications
      WHERE (PHID = '008W7')

---

    Code
      render(get_schools(limit = 5, collect = FALSE))
    Output
      <SQL> SELECT *
      FROM schools
      LIMIT 5

