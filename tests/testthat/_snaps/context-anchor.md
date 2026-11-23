# T-4.4 A8: rendered SQL for one representative call per activity function

    Code
      render(member_activity(PHID = "ZD4", parliament_id = 38, collect = FALSE))
    Output
      <SQL> SELECT
        PHID,
        parliament_id,
        chamber,
        COALESCE(n_turns, 0.0) AS n_turns,
        COALESCE(n_speeches, 0.0) AS n_speeches,
        COALESCE(n_questions, 0.0) AS n_questions,
        COALESCE(n_answers, 0.0) AS n_answers,
        COALESCE(n_interjections_made, 0.0) AS n_interjections_made,
        COALESCE(n_interjections_received, 0.0) AS n_interjections_received,
        COALESCE(n_words, 0.0) AS n_words
      FROM (
        SELECT
          COALESCE(LHS.PHID, RHS.PHID) AS PHID,
          COALESCE(LHS.parliament_id, RHS.parliament_id) AS parliament_id,
          COALESCE(LHS.chamber, RHS.chamber) AS chamber,
          n_turns,
          n_speeches,
          n_questions,
          n_answers,
          n_interjections_made,
          n_words,
          n_interjections_received
        FROM (
          SELECT
            PHID,
            parliament_id,
            chamber,
            COUNT(*) AS n_turns,
            SUM(CASE WHEN m_speech THEN 1 WHEN NOT m_speech THEN 0 END) AS n_speeches,
            SUM(CASE WHEN m_question THEN 1 WHEN NOT m_question THEN 0 END) AS n_questions,
            SUM(CASE WHEN m_answer THEN 1 WHEN NOT m_answer THEN 0 END) AS n_answers,
            SUM(CASE WHEN m_interjection THEN 1 WHEN NOT m_interjection THEN 0 END) AS n_interjections_made,
            SUM(m_words) AS n_words
          FROM (
            SELECT
              action_id,
              PHID,
              parliament_id,
              chamber,
              m_interjection,
              m_speech,
              m_question,
              m_answer,
              CASE WHEN m_speech THEN (COALESCE(len(regexp_extract_all("content", '\S+')), 0)) WHEN NOT m_speech THEN 0 END AS m_words
            FROM (
              SELECT
                *,
                m_flagged AND NOT(m_interjection) AS m_speech,
                COALESCE(is_question, FALSE) AND NOT(m_interjection) AS m_question,
                COALESCE(is_answer, FALSE) AND NOT(m_interjection) AS m_answer
              FROM (
                SELECT
                  *,
                  COALESCE(is_interjection, FALSE) AS m_interjection,
                  COALESCE(is_speech, FALSE) OR COALESCE(is_question, FALSE) OR COALESCE(is_answer, FALSE) AS m_flagged
                FROM (
                  SELECT LHS.*, parliament_id, chamber
                  FROM (
                    SELECT
                      action_id,
                      sitting_id,
                      chamber_venue,
                      PHID,
                      is_speech,
                      is_question,
                      is_answer,
                      is_interjection,
                      "content"
                    FROM v_speech
                    WHERE ((action_type IS NULL) OR action_type != 'quote')
                  ) AS LHS
                  INNER JOIN sittings
                    ON (LHS.sitting_id = sittings.sitting_id)
                  WHERE (sittings.parliament_id = 38.0) AND (LHS.PHID = 'ZD4')
                ) AS q01
              ) AS q01
            ) AS q01
            WHERE (NOT((PHID IS NULL)))
          ) AS q01
          GROUP BY PHID, parliament_id, chamber
        ) AS LHS
        FULL JOIN (
          SELECT PHID, parliament_id, chamber, COUNT(*) AS n_interjections_received
          FROM (
            SELECT
              v_interjection_target.*,
              actions.sitting_id AS sitting_id,
              chamber_venue,
              PHID,
              parliament_id,
              sittings.chamber AS chamber
            FROM v_interjection_target
            INNER JOIN actions
              ON (v_interjection_target.target_action_id = actions.action_id)
            INNER JOIN sittings
              ON (actions.sitting_id = sittings.sitting_id)
            WHERE
              (sittings.parliament_id = 38.0) AND
              (actions.PHID = 'ZD4') AND
              (NOT((actions.PHID IS NULL)))
          ) AS q01
          GROUP BY PHID, parliament_id, chamber
        ) AS RHS
          ON (
            LHS.PHID = RHS.PHID AND
            LHS.parliament_id = RHS.parliament_id AND
            LHS.chamber = RHS.chamber
          )
      ) AS q01

---

    Code
      render(party_activity(party_id = 1, chamber = "house", collect = FALSE))
    Output
      <SQL> SELECT
        party_id_at_time,
        party_at_time,
        parliament_id,
        chamber,
        COUNT(DISTINCT row(PHID)) AS n_members,
        COUNT(*) AS n_turns,
        SUM(CASE WHEN m_speech THEN 1 WHEN NOT m_speech THEN 0 END) AS n_speeches,
        SUM(CASE WHEN m_interjection THEN 1 WHEN NOT m_interjection THEN 0 END) AS n_interjections,
        SUM(m_words) AS n_words
      FROM (
        SELECT LHS.*, party_at_time, party_id_at_time
        FROM (
          SELECT
            action_id,
            PHID,
            parliament_id,
            chamber,
            m_interjection,
            m_speech,
            m_question,
            m_answer,
            CASE WHEN m_speech THEN (COALESCE(len(regexp_extract_all("content", '\S+')), 0)) WHEN NOT m_speech THEN 0 END AS m_words
          FROM (
            SELECT
              *,
              m_flagged AND NOT(m_interjection) AS m_speech,
              COALESCE(is_question, FALSE) AND NOT(m_interjection) AS m_question,
              COALESCE(is_answer, FALSE) AND NOT(m_interjection) AS m_answer
            FROM (
              SELECT
                *,
                COALESCE(is_interjection, FALSE) AS m_interjection,
                COALESCE(is_speech, FALSE) OR COALESCE(is_question, FALSE) OR COALESCE(is_answer, FALSE) AS m_flagged
              FROM (
                SELECT LHS.*, parliament_id, chamber
                FROM (
                  SELECT
                    action_id,
                    sitting_id,
                    chamber_venue,
                    PHID,
                    is_speech,
                    is_question,
                    is_answer,
                    is_interjection,
                    "content"
                  FROM v_speech
                  WHERE ((action_type IS NULL) OR action_type != 'quote')
                ) AS LHS
                INNER JOIN sittings
                  ON (LHS.sitting_id = sittings.sitting_id)
                WHERE (sittings.chamber = 'house')
              ) AS q01
            ) AS q01
          ) AS q01
        ) AS LHS
        LEFT JOIN v_party_at_time
          ON (LHS.action_id = v_party_at_time.action_id)
        WHERE
          (NOT((v_party_at_time.party_at_time IS NULL))) AND
          (v_party_at_time.party_id_at_time = 1.0)
      ) AS q01
      GROUP BY party_id_at_time, party_at_time, parliament_id, chamber

---

    Code
      render(parliament_summary(parliament_id = 38, collect = FALSE))
    Output
      <SQL> SELECT
        parliament_id,
        chamber,
        n_sitting_days,
        n_members,
        n_turns,
        CASE WHEN (n_speeches > 0.0) THEN (n_words / n_speeches) WHEN NOT (n_speeches > 0.0) THEN NULL END AS mean_words_per_speech
      FROM (
        SELECT
          parliament_id,
          chamber,
          n_sitting_days,
          COALESCE(n_members, 0.0) AS n_members,
          COALESCE(n_turns, 0.0) AS n_turns,
          COALESCE(n_speeches, 0.0) AS n_speeches,
          COALESCE(n_words, 0.0) AS n_words
        FROM (
          SELECT "...1".*, n_members, n_turns, n_speeches, n_words
          FROM (
            SELECT
              parliament_id,
              chamber,
              COUNT(DISTINCT row(sitting_id)) AS n_sitting_days
            FROM sittings
            WHERE (parliament_id = 38.0)
            GROUP BY parliament_id, chamber
          ) AS "...1"
          LEFT JOIN (
            SELECT parliament_id, chamber, COUNT(DISTINCT row(PHID)) AS n_members
            FROM (
              SELECT "...1".*, period_start, period_end, PHID, DateStart, DateEnd
              FROM (
                SELECT parliament_id, chamber
                FROM sittings
                WHERE (parliament_id = 38.0)
                GROUP BY parliament_id, chamber
              ) AS "...1"
              INNER JOIN (
                SELECT
                  parliament_id,
                  COALESCE(DateOpening, DateElection) AS period_start,
                  COALESCE(ParliamentEnd, DateDissolution) AS period_end
                FROM parliaments
              ) AS "...2"
                ON ("...1".parliament_id = "...2".parliament_id)
              INNER JOIN (
                SELECT
                  PHID,
                  CASE
      WHEN (MemberOrSenator = 'Member') THEN 'house'
      WHEN (MemberOrSenator = 'Senator') THEN 'senate'
      END AS chamber,
                  DateStart,
                  DateEnd
                FROM parl_service
              ) AS "...3"
                ON ("...1".chamber = "...3".chamber)
              WHERE
                (("...2".period_end IS NULL) OR "...3".DateStart <= "...2".period_end) AND
                (("...3".DateEnd IS NULL) OR "...3".DateEnd >= "...2".period_start)
            ) AS q01
            GROUP BY parliament_id, chamber
          ) AS "...2"
            ON (
              "...1".parliament_id = "...2".parliament_id AND
              "...1".chamber = "...2".chamber
            )
          LEFT JOIN (
            SELECT
              parliament_id,
              chamber,
              COUNT(*) AS n_turns,
              SUM(CASE WHEN m_speech THEN 1 WHEN NOT m_speech THEN 0 END) AS n_speeches,
              SUM(m_words) AS n_words
            FROM (
              SELECT
                action_id,
                PHID,
                parliament_id,
                chamber,
                m_interjection,
                m_speech,
                m_question,
                m_answer,
                CASE WHEN m_speech THEN (COALESCE(len(regexp_extract_all("content", '\S+')), 0)) WHEN NOT m_speech THEN 0 END AS m_words
              FROM (
                SELECT
                  *,
                  m_flagged AND NOT(m_interjection) AS m_speech,
                  COALESCE(is_question, FALSE) AND NOT(m_interjection) AS m_question,
                  COALESCE(is_answer, FALSE) AND NOT(m_interjection) AS m_answer
                FROM (
                  SELECT
                    *,
                    COALESCE(is_interjection, FALSE) AS m_interjection,
                    COALESCE(is_speech, FALSE) OR COALESCE(is_question, FALSE) OR COALESCE(is_answer, FALSE) AS m_flagged
                  FROM (
                    SELECT LHS.*, parliament_id, chamber
                    FROM (
                      SELECT
                        action_id,
                        sitting_id,
                        chamber_venue,
                        PHID,
                        is_speech,
                        is_question,
                        is_answer,
                        is_interjection,
                        "content"
                      FROM v_speech
                      WHERE ((action_type IS NULL) OR action_type != 'quote')
                    ) AS LHS
                    INNER JOIN sittings
                      ON (LHS.sitting_id = sittings.sitting_id)
                    WHERE (sittings.parliament_id = 38.0)
                  ) AS q01
                ) AS q01
              ) AS q01
            ) AS q01
            GROUP BY parliament_id, chamber
          ) AS "...3"
            ON (
              "...1".parliament_id = "...3".parliament_id AND
              "...1".chamber = "...3".chamber
            )
        ) AS q01
      ) AS q01

