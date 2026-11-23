# T-4.4 PC3: result_provenance() SQL

    Code
      dbplyr::sql_render(result_provenance(c("house_1996-05-02", "senate_1996-09-16"),
      collect = FALSE))
    Output
      <SQL> SELECT *
      FROM provenance
      WHERE (sitting_id IN ('house_1996-05-02', 'senate_1996-09-16'))

