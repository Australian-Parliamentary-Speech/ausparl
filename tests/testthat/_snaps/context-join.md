# T-4.4 J8: rendered SQL for one representative call per helper

    Code
      render(add_member(turns()))
    Output
      <SQL> SELECT v_speech.action_id AS action_id, DisplayName, Gender, State
      FROM v_speech
      LEFT JOIN (
        SELECT action_id, DisplayName, Gender, State
        FROM actions
        LEFT JOIN members
          ON (actions.PHID = members.PHID)
      ) AS RHS
        ON (v_speech.action_id = RHS.action_id)

---

    Code
      render(add_party(turns()))
    Output
      <SQL> SELECT
        v_speech.action_id AS action_id,
        party_id_at_time,
        party_at_time,
        party_abbrev_at_time
      FROM v_speech
      LEFT JOIN (
        SELECT
          action_id,
          party_id_at_time,
          party_at_time,
          Abbrev AS party_abbrev_at_time
        FROM v_party_at_time
        LEFT JOIN parties
          ON (v_party_at_time.party_id_at_time = parties.party_id)
      ) AS RHS
        ON (v_speech.action_id = RHS.action_id)

---

    Code
      render(add_electorate(turns()))
    Output
      <SQL> SELECT v_speech.action_id AS action_id, electorate_at_time
      FROM v_speech
      LEFT JOIN v_electorate_at_time
        ON (v_speech.action_id = v_electorate_at_time.action_id)

---

    Code
      render(add_age(turns()))
    Output
      <SQL> SELECT v_speech.action_id AS action_id, age_at_time
      FROM v_speech
      LEFT JOIN v_age_at_time
        ON (v_speech.action_id = v_age_at_time.action_id)

---

    Code
      render(add_role(turns()))
    Output
      <SQL> SELECT v_speech.action_id AS action_id, role_at_time
      FROM v_speech
      LEFT JOIN v_role_at_time
        ON (v_speech.action_id = v_role_at_time.action_id)

---

    Code
      render(add_government_status(turns()))
    Output
      <SQL> SELECT v_speech.action_id AS action_id, government_status_at_time
      FROM v_speech
      LEFT JOIN v_government_status_at_time
        ON (v_speech.action_id = v_government_status_at_time.action_id)

---

    Code
      render(add_debate(turns()))
    Output
      <SQL> SELECT v_speech.action_id AS action_id, debate_title, subdebate_title, seq
      FROM v_speech
      LEFT JOIN v_sitting_timeline
        ON (v_speech.action_id = v_sitting_timeline.action_id)

