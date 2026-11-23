# T-4.4 V9: rendered SQL for one representative call per function

    Code
      render(get_interjections(from = 1996, to = 1996, chamber = "House", collect = FALSE))
    Output
      <SQL> SELECT
        v_interjection_target.*,
        "actions...2".sitting_id AS sitting_id,
        date,
        sittings.chamber AS chamber,
        "actions...2".chamber_venue AS chamber_venue,
        "actions...2".PHID AS interjector_PHID,
        "members...5".DisplayName AS interjector_name,
        "actions...3".PHID AS target_PHID,
        "members...6".DisplayName AS target_name,
        "actions...2".action_type AS interjection_type
      FROM v_interjection_target
      INNER JOIN actions AS "actions...2"
        ON (v_interjection_target.interjection_action_id = "actions...2".action_id)
      LEFT JOIN actions AS "actions...3"
        ON (v_interjection_target.target_action_id = "actions...3".action_id)
      INNER JOIN sittings
        ON ("actions...2".sitting_id = sittings.sitting_id)
      LEFT JOIN members AS "members...5"
        ON ("actions...2".PHID = "members...5".PHID)
      LEFT JOIN members AS "members...6"
        ON ("actions...3".PHID = "members...6".PHID)
      WHERE
        (sittings.chamber = 'house') AND
        (sittings.date >= '1996-01-01'::date) AND
        (sittings.date <= '1996-12-31'::date)

---

    Code
      render(get_sitting_timeline(sitting_id = "house_1996-05-02", collect = FALSE))
    Output
      <SQL> SELECT
        v_sitting_timeline.sitting_id AS sitting_id,
        date,
        sittings.chamber AS chamber,
        seq,
        v_sitting_timeline.action_id AS action_id,
        debate_title,
        subdebate_title,
        v_sitting_timeline.action_type AS action_type,
        v_sitting_timeline.PHID AS PHID,
        speaker_name,
        "content"
      FROM v_sitting_timeline
      INNER JOIN sittings
        ON (v_sitting_timeline.sitting_id = sittings.sitting_id)
      LEFT JOIN actions
        ON (v_sitting_timeline.action_id = actions.action_id)
      WHERE (v_sitting_timeline.sitting_id = 'house_1996-05-02')

# T-4.4 V19: rendered SQL for one representative get_speech_turns() call

    Code
      dbplyr::sql_render(get_speech_turns(party = "ALP", from = 1996, to = 1996,
        include_text = FALSE, collect = FALSE))
    Output
      <SQL> SELECT
        sitting_id,
        date,
        chamber,
        parliament_id,
        turn_no,
        first_action_id,
        n_actions,
        PHID,
        name_raw,
        resolution,
        party_id_at_time,
        party_at_time,
        has_quote,
        is_quote
      FROM v_speech_turns_context
      WHERE
        (date >= '1996-01-01'::date) AND
        (date <= '1996-12-31'::date) AND
        (party_id_at_time = 1)

