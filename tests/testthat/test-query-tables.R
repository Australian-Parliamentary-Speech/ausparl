# Tests for the generated single-table getters in R/query-tables.R (G1-G15).
# Sample DB only; no network.

local_sample_ap <- function(env = parent.frame()) {
  db_connect(sample = TRUE)
  withr::defer(db_disconnect(), envir = env)
}

# Asserts a result has the same rows as direct SQL, in any order.
expect_same_rows <- function(got, sql) {
  sort_rows <- function(d) {
    d <- as.data.frame(d)
    d <- d[do.call(order, unname(as.list(d))), , drop = FALSE]
    rownames(d) <- NULL
    d
  }
  expect_equal(sort_rows(got), sort_rows(DBI::dbGetQuery(db_con(), sql)))
  invisible(got)
}

col_classes <- function(d) vapply(d, function(x) class(x)[1], character(1))

getter <- function(table) getExportedValue("ausparl", paste0("get_", table))

# The spec the getters must follow: active_during date columns, display views, table set.
active_cols <- list(
  parl_service = c("DateStart", "DateEnd"),
  party_service = c("DateStart", "DateEnd"),
  ministries = c("DateStart", "DateEnd"),
  ministry_records = c("RDateStart", "RDateEnd"),
  shadow_ministry_records = c("RDateStart", "RDateEnd"),
  committee_members = c("start_date", "end_date"),
  presiding_officers = c("DateStart", "DateEnd")
)
display_tables <- c(
  "actions", "members", "parl_service", "party_service", "ministry_records",
  "shadow_ministry_records", "committee_members"
)
getter_tables <- c(
  "sittings", "debates", "subdebates", "actions", "provenance", "members", "parliaments",
  "parties", "electorates", "parl_service", "party_service", "ministries", "ministry_records",
  "shadow_ministry_records", "committee_members", "presiding_officers", "elections", "occupations",
  "qualifications", "schools"
)

# ---- G1 generator -------------------------------------------------------------------------------

test_that("T-4.1 G1: regenerating reproduces R/query-tables.R byte-for-byte", {
  root <- test_path("..", "..")
  generator <- file.path(root, "data-raw", "generate-getters.R")
  skip_if_not(file.exists(generator), "data-raw/ is not available (e.g. under R CMD check)")
  committed <- file.path(root, "R", "query-tables.R")
  skip_if_not(file.exists(committed), "R/query-tables.R is not available")

  env <- new.env()
  sys.source(generator, envir = env)
  generated <- charToRaw(env$generate_getters(root))
  expect_identical(generated, readBin(committed, "raw", n = file.size(committed)))
})

# ---- G2 exports and formals ---------------------------------------------------------------------

test_that("T-4.1 G2: 20 getters are exported with formals following the column rule", {
  # Hand-written get_ queries from other features are not generated getters.
  handwritten <- c(
    "get_interjections", "get_sitting_timeline", "get_speeches", "get_speech_turns"
  )
  exported <- setdiff(grep("^get_", getNamespaceExports("ausparl"), value = TRUE), handwritten)
  expect_setequal(exported, paste0("get_", getter_tables))
  for (absent in c("parse_errors", "party_alias", "schema_version")) {
    expect_false(paste0("get_", absent) %in% exported)
  }

  con <- local_sample_con()
  catalog <- DBI::dbGetQuery(con, "
    SELECT table_name, column_name FROM information_schema.columns
    WHERE table_schema = 'main' ORDER BY table_name, ordinal_position
  ")
  for (table in getter_tables) {
    cols <- catalog$column_name[catalog$table_name == table]
    filters <- cols[cols != "content" & !grepl("_raw$", cols)]
    expected <- c(
      filters, "...",
      if (table %in% names(active_cols)) "active_during",
      if (table %in% display_tables) "display",
      "columns", "collect", "limit"
    )
    f <- formals(getter(table))
    expect_identical(names(f), expected, label = table)
    for (col in filters) expect_null(f[[col]], label = paste(table, col))
    if (table %in% display_tables) expect_false(f$display)
    expect_true(f$collect)
  }
})

# ---- G3 unfiltered results ----------------------------------------------------------------------

test_that("T-4.1 G3: unfiltered results equal direct SQL and are tibbles", {
  local_sample_ap()
  for (table in getter_tables) {
    got <- getter(table)()
    expect_s3_class(got, "tbl_df")
    expect_identical(names(got), DBI::dbListFields(db_con(), table), label = table)
    expect_same_rows(got, paste("SELECT * FROM", table))
  }
})

test_that("T-4.1 G3: getters compose with the pipe, stay lazy, and honour columns/limit", {
  local_sample_ap()
  lazy <- get_sittings(chamber = "senate", collect = FALSE)
  expect_s3_class(lazy, "tbl_lazy")
  piped <- lazy |>
    dplyr::filter(parliament_id > 38) |>
    dplyr::collect()
  expect_same_rows(piped, "SELECT * FROM sittings WHERE chamber = 'senate' AND parliament_id > 38")
  expect_identical(
    get_sittings() |> dplyr::filter(chamber == "house") |> nrow(),
    4L
  )
  expect_identical(nrow(get_actions(limit = 5)), 5L)
  expect_identical(names(get_members(columns = c("PHID", "Gender"))), c("PHID", "Gender"))
})

# ---- G4 filters ---------------------------------------------------------------------------------

test_that("T-4.2 G4: a filter on each getter equals direct SQL (vector, range, like)", {
  local_sample_ap()
  cases <- list(
    list(
      get_sittings(parliament_id = in_range(38, 40)),
      "SELECT * FROM sittings WHERE parliament_id BETWEEN 38 AND 40"
    ),
    list(
      get_debates(sitting_id = "house_1990-09-17"),
      "SELECT * FROM debates WHERE sitting_id = 'house_1990-09-17'"
    ),
    list(
      get_subdebates(title = matches_pattern("%IMMIGRATION%")),
      "SELECT * FROM subdebates WHERE title ILIKE '%immigration%'"
    ),
    list(
      get_actions(action_type = c("question", "answer"), year = in_range(1990, 2000)),
      "SELECT * FROM actions WHERE action_type IN ('question', 'answer')
       AND year BETWEEN 1990 AND 2000"
    ),
    list(
      get_provenance(source = "csv"),
      "SELECT * FROM provenance WHERE source = 'csv'"
    ),
    list(
      get_members(Gender = "Female", StateAbbrev = c("Vic", "Tas")),
      "SELECT * FROM members WHERE Gender = 'Female' AND StateAbbrev IN ('Vic', 'Tas')"
    ),
    list(
      get_parliaments(DateOpening = in_range("1990-01-01", "2000-12-31")),
      "SELECT * FROM parliaments
       WHERE DateOpening BETWEEN DATE '1990-01-01' AND DATE '2000-12-31'"
    ),
    list(
      get_parties(Abbrev = c("ALP", "LP")),
      "SELECT * FROM parties WHERE Abbrev IN ('ALP', 'LP')"
    ),
    list(
      get_electorates(Electorate = matches_pattern("%ade%")),
      "SELECT * FROM electorates WHERE Electorate ILIKE '%ade%'"
    ),
    list(
      get_parl_service(MemberOrSenator = "Senator"),
      "SELECT * FROM parl_service WHERE MemberOrSenator = 'Senator'"
    ),
    list(
      get_party_service(party_id = 1),
      "SELECT * FROM party_service WHERE party_id = 1"
    ),
    list(
      get_ministries(MinistryNumber = in_range(from = 60)),
      "SELECT * FROM ministries WHERE MinistryNumber >= 60"
    ),
    list(
      get_ministry_records(Role = matches_pattern("%treasurer%")),
      "SELECT * FROM ministry_records WHERE Role ILIKE '%treasurer%'"
    ),
    list(
      get_shadow_ministry_records(SMID = in_range(to = 20)),
      "SELECT * FROM shadow_ministry_records WHERE SMID <= 20"
    ),
    list(
      get_committee_members(end_date_status = "recorded", PHID = "ZD4"),
      "SELECT * FROM committee_members WHERE end_date_status = 'recorded' AND PHID = 'ZD4'"
    ),
    list(
      get_presiding_officers(Office = matches_pattern("%speaker%"), Chamber = "House"),
      "SELECT * FROM presiding_officers WHERE Office ILIKE '%speaker%' AND Chamber = 'House'"
    ),
    list(
      get_elections(Byelection = FALSE, Year = in_range(1990, 2000)),
      "SELECT * FROM elections WHERE NOT Byelection AND Year BETWEEN 1990 AND 2000"
    ),
    list(
      get_occupations(Occupation = matches_pattern("%barrister%")),
      "SELECT * FROM occupations WHERE Occupation ILIKE '%barrister%'"
    ),
    list(
      get_qualifications(PHID = c("008W7", "009MD")),
      "SELECT * FROM qualifications WHERE PHID IN ('008W7', '009MD')"
    ),
    list(
      get_schools(secondary_school = matches_pattern("%grammar%")),
      "SELECT * FROM schools WHERE secondary_school ILIKE '%grammar%'"
    )
  )
  expect_length(cases, 20)
  for (case in cases) {
    got <- expect_same_rows(case[[1]], case[[2]])
    expect_gt(nrow(got), 0)
  }
})

# ---- G5 active_during ---------------------------------------------------------------------------

test_that("T-4.2 G5: active_during on all 7 tables equals direct SQL", {
  local_sample_ap()
  overlap_sql <- function(table, from, to) {
    cols <- active_cols[[table]]
    sprintf(
      "SELECT * FROM %s WHERE %s <= DATE '%s' AND (%s IS NULL OR %s >= DATE '%s')",
      table, cols[1], to, cols[2], cols[2], from
    )
  }
  for (table in names(active_cols)) {
    year <- expect_same_rows(
      getter(table)(active_during = 2000),
      overlap_sql(table, "2000-01-01", "2000-12-31")
    )
    expect_gt(nrow(year), 0)
    day <- expect_same_rows(
      getter(table)(active_during = "2000-07-01"),
      overlap_sql(table, "2000-07-01", "2000-07-01")
    )
    span <- expect_same_rows(
      getter(table)(active_during = in_range(1990, 1995)),
      overlap_sql(table, "1990-01-01", "1995-12-31")
    )
    expect_lte(nrow(day), nrow(year))
    expect_gt(nrow(span), 0)
  }
  # Combined with a column filter, and an open-ended range keeps ongoing (NULL end) rows.
  expect_same_rows(
    get_parl_service(MemberOrSenator = "Senator", active_during = in_range(from = 2024)),
    "SELECT * FROM parl_service WHERE MemberOrSenator = 'Senator'
     AND (DateEnd IS NULL OR DateEnd >= DATE '2024-01-01')"
  )
})

# ---- G6 display ---------------------------------------------------------------------------------

test_that("T-4.2 G6: display = TRUE reads v_*_display and filters still apply", {
  local_sample_ap()
  for (table in display_tables) {
    view <- paste0("v_", table, "_display")
    lazy <- getter(table)(display = TRUE, collect = FALSE)
    expect_match(dbplyr::sql_render(lazy), view, fixed = TRUE)
    got <- getter(table)(display = TRUE)
    expect_identical(names(got), DBI::dbListFields(db_con(), view), label = view)
    expect_identical(nrow(got), nrow(getter(table)()), label = view)

    filtered <- expect_same_rows(
      getter(table)(PHID = "ZD4", display = TRUE),
      sprintf("SELECT * FROM %s WHERE PHID = 'ZD4'", view)
    )
    expect_gt(nrow(filtered), 0)
  }
  expect_same_rows(
    get_actions(chamber = "Senate", is_question = TRUE, display = TRUE),
    "SELECT * FROM v_actions_display WHERE chamber = 'senate' AND is_question"
  )
  expect_same_rows(
    get_party_service(active_during = 1990, display = TRUE),
    "SELECT * FROM v_party_service_display WHERE DateStart <= DATE '1990-12-31'
     AND (DateEnd IS NULL OR DateEnd >= DATE '1990-01-01')"
  )
})

# ---- G7 chamber ---------------------------------------------------------------------------------

test_that("T-4.2 G7: chamber is matched case-insensitively and returned lowercase", {
  local_sample_ap()
  house <- expect_same_rows(
    get_sittings(chamber = "HOUSE"),
    "SELECT * FROM sittings WHERE chamber = 'house'"
  )
  expect_identical(unique(house$chamber), "house")
  expect_identical(nrow(get_sittings(chamber = c("House", "SENATE"))), 8L)

  senate <- expect_same_rows(
    get_actions(chamber = "Senate"),
    "SELECT * FROM actions WHERE chamber = 'senate'"
  )
  expect_identical(unique(senate$chamber), "senate")
  expect_error(get_sittings(chamber = "reps"), class = "ausparl_input_error")
  expect_error(get_actions(chamber = 1), class = "ausparl_input_error")
})

# ---- G8 / G9 neutrality and grain ---------------------------------------------------------------

test_that("T-4.1 G8: get_actions() returns every sample row, interjections included", {
  local_sample_ap()
  actions <- get_actions()
  expect_identical(nrow(actions), 1488L)
  n_interjections <- DBI::dbGetQuery(
    db_con(), "SELECT count(*) AS n FROM actions WHERE is_interjection"
  )$n
  expect_gt(n_interjections, 0)
  expect_identical(sum(actions$is_interjection), as.integer(n_interjections))
  expect_identical(nrow(get_actions(display = TRUE)), 1488L)
})

test_that("T-4.1 G9: get_schools() makes no one-row-per-PHID assumption", {
  local_sample_ap()
  expect_same_rows(get_schools(), "SELECT * FROM schools")

  # The sample has one school per member, so add a second school for one member in a copy.
  path <- local_sample_copy(
    "INSERT INTO schools SELECT PHID, 'Second School' FROM schools ORDER BY PHID LIMIT 1"
  )
  db_connect(path = path)
  phid <- DBI::dbGetQuery(db_con(), "SELECT min(PHID) AS p FROM schools")$p
  two <- get_schools(PHID = phid)
  expect_identical(nrow(two), 2L)
  expect_setequal(two$PHID, phid)
  expect_identical(nrow(get_schools()), 93L)
})

# ---- G10 grain ----------------------------------------------------------------------------------

test_that("T-4.1 G10: keyed tables have unique keys", {
  local_sample_ap()
  keys <- list(
    sittings = "sitting_id", debates = "debate_id", subdebates = "subdebate_id",
    actions = "action_id", provenance = "path", members = "PHID",
    parliaments = "parliament_id", parties = "party_id", electorates = "electorate_id",
    ministries = c("MinistryNumber", "party_id"), ministry_records = "ministry_record_id",
    shadow_ministry_records = "shadow_ministry_record_id",
    committee_members = "committee_member_id", presiding_officers = "presiding_officer_id",
    elections = "Id"
  )
  for (table in names(keys)) {
    expect_unique_key(getter(table)(collect = FALSE), keys[[table]])
  }
  expect_unique_key(get_members(display = TRUE, collect = FALSE), "PHID")
  expect_unique_key(get_actions(display = TRUE, collect = FALSE), "action_id")
})

# ---- G11 input errors ---------------------------------------------------------------------------

test_that("T-4.2 G11: bad arguments raise ausparl_input_error before any query is built", {
  local_mocked_bindings(db_tbl = function(...) stop("a query was built"))
  bad <- list(
    function() get_sittings(limit = 0),
    function() get_sittings(limit = 1.5),
    function() get_sittings(limit = "10"),
    function() get_sittings(collect = NA),
    function() get_members(PHID = NA),
    function() get_members(PHID = c("008W7", NA)),
    function() get_members(PHID = list("008W7")),
    function() get_members(PHID = character()),
    function() get_members(display = "yes"),
    function() get_members(display = NA),
    function() get_actions(display = c(TRUE, FALSE)),
    function() get_sittings(chamer = "house"),
    function() get_sittings(NULL, NULL, NULL, NULL, "extra"),
    function() get_parl_service(active_during = "June 1990"),
    function() get_parl_service(active_during = c(1990, 1991)),
    function() get_committee_members(active_during = in_range(1990.5))
  )
  for (f in bad) {
    err <- expect_error(f(), class = "ausparl_input_error")
    expect_s3_class(err, "ausparl_error")
  }
})

test_that("T-4.2 G11: bad columns raise ausparl_input_error", {
  local_sample_ap()
  expect_error(get_sittings(columns = "nope"), class = "ausparl_input_error")
  expect_error(get_sittings(columns = 1), class = "ausparl_input_error")
  expect_error(get_members(columns = "Party"), class = "ausparl_input_error")
  expect_identical(names(get_members(columns = "Party", display = TRUE)), "Party")
})

# ---- G12 empty results --------------------------------------------------------------------------

test_that("T-4.20 G12: an empty result is a typed zero-row tibble", {
  local_sample_ap()
  empties <- list(
    list(get_members(PHID = "no-such-phid"), get_members(limit = 1)),
    list(get_actions(PHID = "no-such-phid"), get_actions(limit = 1)),
    list(
      get_parl_service(PHID = "no-such-phid", display = TRUE),
      get_parl_service(display = TRUE, limit = 1)
    ),
    list(get_ministries(active_during = 1800), get_ministries(limit = 1)),
    list(get_sittings(date = in_range(to = "1800-01-01")), get_sittings(limit = 1))
  )
  for (pair in empties) {
    expect_s3_class(pair[[1]], "tbl_df")
    expect_identical(nrow(pair[[1]]), 0L)
    expect_identical(col_classes(pair[[1]]), col_classes(pair[[2]]))
  }
})

# ---- G13 SQL snapshots --------------------------------------------------------------------------

test_that("T-4.4 G13: rendered SQL for one representative call per getter", {
  local_sample_ap()
  render <- function(lazy) dbplyr::sql_render(lazy)
  expect_snapshot(render(get_sittings(chamber = "House", collect = FALSE)))
  expect_snapshot(render(get_debates(sitting_id = "house_1996-05-02", collect = FALSE)))
  expect_snapshot(render(get_subdebates(title = matches_pattern("%question%"), collect = FALSE)))
  expect_snapshot(render(get_actions(
    action_type = c("question", "answer"), year = in_range(1990, 2000), display = TRUE,
    collect = FALSE
  )))
  expect_snapshot(render(get_provenance(source = "csv", collect = FALSE)))
  expect_snapshot(render(get_members(
    Gender = "Female", StateAbbrev = c("Vic", "Tas"), collect = FALSE
  )))
  expect_snapshot(render(get_parliaments(parliament_id = in_range(38, 40), collect = FALSE)))
  expect_snapshot(render(get_parties(Abbrev = c("ALP", "LP"), collect = FALSE)))
  expect_snapshot(render(get_electorates(StateAbbrev = "Tas", collect = FALSE)))
  expect_snapshot(render(get_parl_service(
    MemberOrSenator = "Senator", active_during = 1996, collect = FALSE
  )))
  expect_snapshot(render(get_party_service(
    party_id = 1, active_during = in_range(1990, 1995), display = TRUE, collect = FALSE
  )))
  expect_snapshot(render(get_ministries(active_during = 1975, collect = FALSE)))
  expect_snapshot(render(get_ministry_records(
    Role = matches_pattern("%treasurer%"), active_during = 2000, collect = FALSE
  )))
  expect_snapshot(render(get_shadow_ministry_records(active_during = 2000, collect = FALSE)))
  expect_snapshot(render(get_committee_members(
    PHID = "008W7", active_during = 2001, display = TRUE, columns = c("PHID", "DisplayName"),
    collect = FALSE
  )))
  expect_snapshot(render(get_presiding_officers(
    Chamber = "Senate", active_during = 2000, collect = FALSE
  )))
  expect_snapshot(render(get_elections(
    Byelection = FALSE, Year = in_range(1990, 2000), collect = FALSE
  )))
  expect_snapshot(render(get_occupations(
    Occupation = matches_pattern("%barrister%"), collect = FALSE
  )))
  expect_snapshot(render(get_qualifications(PHID = "008W7", collect = FALSE)))
  expect_snapshot(render(get_schools(limit = 5, collect = FALSE)))
})

# ---- G15 presiding officers ---------------------------------------------------------------------

test_that("T-4.2 G15: get_presiding_officers() matches Chamber as stored, Office and dates", {
  local_sample_ap()
  all <- expect_same_rows(get_presiding_officers(), "SELECT * FROM presiding_officers")
  expect_identical(nrow(all), 214L)
  expect_setequal(unique(all$Chamber), c("House", "Senate"))

  # Chamber is an ausPH column: stored capitalised and matched exactly, with no case folding.
  senate <- expect_same_rows(
    get_presiding_officers(Chamber = "Senate"),
    "SELECT * FROM presiding_officers WHERE Chamber = 'Senate'"
  )
  expect_gt(nrow(senate), 0)
  expect_identical(unique(senate$Chamber), "Senate")
  lower <- get_presiding_officers(Chamber = "house")
  expect_s3_class(lower, "tbl_df")
  expect_identical(nrow(lower), 0L)
  expect_identical(col_classes(lower), col_classes(all))

  office <- expect_same_rows(
    get_presiding_officers(Office = "President of the Senate"),
    "SELECT * FROM presiding_officers WHERE Office = 'President of the Senate'"
  )
  expect_gt(nrow(office), 0)
  during <- expect_same_rows(
    get_presiding_officers(Chamber = "Senate", active_during = 2000),
    "SELECT * FROM presiding_officers WHERE Chamber = 'Senate'
     AND DateStart <= DATE '2000-12-31' AND (DateEnd IS NULL OR DateEnd >= DATE '2000-01-01')"
  )
  expect_gt(nrow(during), 0)
})
