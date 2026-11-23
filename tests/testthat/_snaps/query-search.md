# T-4.4 R12: rendered SQL for one representative call

    Code
      dbplyr::sql_render(search_speeches_by_terms(c("Foreign Affairs", "LGBTIQ+"),
      party = "ALP", from = 1996, to = 2002, chamber = "House", include_text = FALSE,
      collect = FALSE))
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
        has_quote,
        score,
        TRY_CAST(len(regexp_extract_all("content", '\bForeign\s+Affairs\b', 0, 'i')) + len(regexp_extract_all("content", '\bLGBTIQ\+', 0, 'i')) AS INTEGER) AS n_hits
      FROM (
        SELECT
          LHS.action_id AS action_id,
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
          has_quote,
          "content",
          score
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
            "content",
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
            (sittings.date <= '2002-12-31'::date) AND
            (v_speech.is_speech OR v_speech.is_question OR v_speech.is_answer) AND
            (NOT(COALESCE(v_speech.is_interjection, FALSE))) AND
            ((v_speech.resolution IS NULL) OR v_speech.resolution != 'sentinel') AND
            (v_party_at_time.party_id_at_time = 1)
        ) AS LHS
        INNER JOIN (
        SELECT action_id, score
        FROM (
          SELECT action_id,
                 fts_main_actions.match_bm25(action_id, 'foreign affairs lgbtiq', conjunctive := 1)
                   AS score
          FROM actions
          WHERE TRUE AND year >= 1996 AND year <= 2002
        ) AS fts
        WHERE score IS NOT NULL
        ) AS RHS
          ON (LHS.action_id = RHS.action_id)
        WHERE (regexp_matches(LHS."content", '\bForeign\s+Affairs\b', 'i') AND regexp_matches(LHS."content", '\bLGBTIQ\+', 'i'))
      ) AS q01

