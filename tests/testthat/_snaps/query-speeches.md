# T-4.4 S11: rendered SQL for one representative call per function

    Code
      render(get_speeches(party = "ALP", from = 1996, to = 1996, chamber = "House",
        include_text = FALSE, collect = FALSE))
    Output
      <SQL> SELECT
        action_id,
        sitting_id,
        date,
        chamber,
        chamber_venue,
        parliament_id,
        PHID,
        name_raw,
        party_id_at_time,
        party_at_time,
        is_speech,
        is_question,
        is_answer,
        is_interjection,
        is_non_speech,
        is_petition,
        is_motion_no_speech,
        has_quote
      FROM (
        SELECT
          v_speech.action_id AS action_id,
          v_speech.sitting_id AS sitting_id,
          chamber_venue,
          PHID,
          name_raw,
          resolution,
          is_speech,
          is_question,
          is_answer,
          is_interjection,
          is_non_speech,
          is_petition,
          is_motion_no_speech,
          has_quote,
          date,
          sittings.chamber AS chamber,
          parliament_id,
          party_at_time,
          party_id_at_time
        FROM v_speech
        INNER JOIN sittings
          ON (v_speech.sitting_id = sittings.sitting_id)
        LEFT JOIN v_party_at_time
          ON (v_speech.action_id = v_party_at_time.action_id)
        WHERE
          (sittings.chamber = 'house') AND
          (sittings.date >= '1996-01-01'::date) AND
          (sittings.date <= '1996-12-31'::date) AND
          (v_speech.is_speech OR v_speech.is_question OR v_speech.is_answer) AND
          (NOT(COALESCE(v_speech.is_interjection, FALSE))) AND
          ((v_speech.resolution IS NULL) OR v_speech.resolution != 'sentinel') AND
          (v_party_at_time.party_id_at_time = 1)
      ) AS q01

---

    Code
      render(find_member_query(c("john", "howard"), chamber = "house", active_during = 1996,
      call = NULL))
    Output
      <SQL> SELECT
        LHS.PHID AS PHID,
        DisplayName,
        Gender,
        DateOfBirth,
        State,
        chambers,
        first_service,
        last_service
      FROM (
        SELECT LHS.*
        FROM (
          SELECT *
          FROM members
          WHERE
            (ilike_escape(DisplayName, '%john%', '\')) AND
            (ilike_escape(DisplayName, '%howard%', '\'))
      ) AS LHS
        WHERE EXISTS (
          SELECT 1 FROM (
          SELECT
            PHID,
            MemberOrSenator,
            DateStart,
            DateEnd,
            CASE
      WHEN (MemberOrSenator = 'Member') THEN 'house'
      WHEN (MemberOrSenator = 'Senator') THEN 'senate'
      END AS chamber
          FROM parl_service
      ) AS RHS
          WHERE
            (LHS.PHID = RHS.PHID) AND
            (RHS.chamber = 'house') AND
            (RHS.DateStart <= '1996-12-31'::date) AND
            ((RHS.DateEnd IS NULL) OR RHS.DateEnd >= '1996-01-01'::date)
        )
      ) AS LHS
      LEFT JOIN (
        SELECT
          *,
          CASE
      WHEN (n_house > 0.0 AND n_senate > 0.0) THEN 'house, senate'
      WHEN (n_house > 0.0) THEN 'house'
      WHEN (n_senate > 0.0) THEN 'senate'
      END AS chambers,
          CASE WHEN (n_open > 0.0) THEN NULL WHEN NOT (n_open > 0.0) THEN max_end END AS last_service
        FROM (
          SELECT
            PHID,
            SUM(CASE WHEN (chamber = 'house') THEN 1 WHEN NOT (chamber = 'house') THEN 0 END) AS n_house,
            SUM(CASE WHEN (chamber = 'senate') THEN 1 WHEN NOT (chamber = 'senate') THEN 0 END) AS n_senate,
            SUM(CASE WHEN ((DateEnd IS NULL)) THEN 1 WHEN NOT ((DateEnd IS NULL)) THEN 0 END) AS n_open,
            MIN(DateStart) AS first_service,
            MAX(DateEnd) AS max_end
          FROM (
            SELECT
              PHID,
              MemberOrSenator,
              DateStart,
              DateEnd,
              CASE
      WHEN (MemberOrSenator = 'Member') THEN 'house'
      WHEN (MemberOrSenator = 'Senator') THEN 'senate'
      END AS chamber
            FROM parl_service
          ) AS q01
          GROUP BY PHID
        ) AS q01
      ) AS RHS
        ON (LHS.PHID = RHS.PHID)

