# T-4.4 Q12: rendered SQL for representative filter calls

    Code
      dbplyr::sql_render(filter_args(db_tbl("members"), list(PHID = NULL,
        StateAbbrev = c("Vic", "Tas"), Gender = "Female", DateOfBirth = in_range(
          "1940-01-01", "1960-12-31"), DisplayName = matches_pattern("%o'brien%"))))
    Output
      <SQL> SELECT *
      FROM members
      WHERE
        (StateAbbrev IN ('Vic', 'Tas')) AND
        (Gender = 'Female') AND
        (DateOfBirth >= '1940-01-01'::date) AND
        (DateOfBirth <= '1960-12-31'::date) AND
        (DisplayName ILIKE '%o''brien%')

---

    Code
      dbplyr::sql_render(filter_active_during(db_tbl("parl_service"), in_range(1990,
        1995), "DateStart", "DateEnd"))
    Output
      <SQL> SELECT *
      FROM parl_service
      WHERE
        (DateStart <= '1995-12-31'::date) AND
        ((DateEnd IS NULL) OR DateEnd >= '1990-01-01'::date)

