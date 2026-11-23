# Build inst/extdata/ausparl-sample.duckdb from the full Hansard database.
#
# Developer-machine only: needs the full database, named by AUSPARL_DB, and the DuckDB fts
# extension. The source is attached READ_ONLY and never written.
#
# Run from the package root:  Rscript data-raw/make-sample-db.R

source_db <- Sys.getenv("AUSPARL_DB")
if (!nzchar(source_db)) {
  stop(
    "AUSPARL_DB is not set. Point it at the full hansard.duckdb, e.g.\n",
    "  AUSPARL_DB=/path/to/hansard.duckdb Rscript data-raw/make-sample-db.R",
    call. = FALSE
  )
}
out_db <- "inst/extdata/ausparl-sample.duckdb"
eras <- c("v2.0", "v2.1", "v2.2", "legacy-html")
min_actions <- 100L # keep each day realistic; below this a "day" is a stub

if (!file.exists(source_db)) {
  stop("AUSPARL_DB points at '", source_db, "', which does not exist.", call. = FALSE)
}
stopifnot(dir.exists("inst/extdata"))
if (file.exists(out_db)) file.remove(out_db)

ext_dir <- tools::R_user_dir("ausparl", "cache")
dir.create(ext_dir, recursive = TRUE, showWarnings = FALSE)
# In-memory session; the output is ATTACHed with 16 KB blocks (default 256 KB) because the
# sample is many small tables and block padding otherwise dominates the file size.
con <- DBI::dbConnect(duckdb::duckdb(config = list(extension_directory = ext_dir)))
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

q <- function(sql) DBI::dbGetQuery(con, sql)
x <- function(sql) invisible(DBI::dbExecute(con, sql))

x(sprintf("ATTACH '%s' AS out (BLOCK_SIZE 16384)", normalizePath(out_db, mustWork = FALSE)))
x(sprintf("ATTACH '%s' AS src (READ_ONLY)", normalizePath(source_db)))

# ---- 1. Eligible sitting days -------------------------------------------------------------
x(sprintf("
  CREATE TEMP TABLE cand AS
  WITH s AS (
    SELECT s.sitting_id, s.chamber, s.date, year(s.date) AS yr, p.schema_generation AS era,
           row_number() OVER (PARTITION BY s.chamber, year(s.date) ORDER BY s.date) AS day_of_year
    FROM src.sittings s JOIN src.provenance p USING (sitting_id)
  ),
  a AS (
    SELECT sitting_id,
           count(*) AS n_actions,
           count(*) FILTER (WHERE is_question) AS n_q,
           count(*) FILTER (WHERE is_answer) AS n_a,
           count(*) FILTER (WHERE resolution = 'sentinel') AS n_sentinel,
           count(*) FILTER (WHERE action_type = 'quote' AND resolution IS NULL) AS n_quote_null
    FROM src.actions GROUP BY sitting_id
  ),
  t AS (
    SELECT a.sitting_id, count(*) AS n_targets
    FROM src.v_interjection_target it JOIN src.actions a ON a.action_id = it.interjection_action_id
    GROUP BY a.sitting_id
  )
  SELECT s.*, a.n_actions, a.n_q, a.n_a, a.n_sentinel, a.n_quote_null,
         coalesce(t.n_targets, 0) AS n_targets
  FROM s JOIN a USING (sitting_id) LEFT JOIN t USING (sitting_id)
  WHERE s.era IN (%s) AND s.day_of_year > 1 AND a.n_q > 0 AND a.n_a > 0
    AND a.n_actions >= %d
", paste0("'", eras, "'", collapse = ", "), min_actions))

# ---- 2. A party-changing PHID across two slots --------------------------------------------
# Party per (sitting, PHID) from party_service date ranges, same tiebreak as v_party_at_time.
pairs <- q("
  WITH sp AS (
    SELECT DISTINCT c.sitting_id, c.chamber, c.era, c.date, c.n_actions, a.PHID
    FROM cand c JOIN src.actions a USING (sitting_id)
    WHERE a.PHID IS NOT NULL AND c.n_targets > 0 AND c.n_sentinel > 0
  ),
  pp AS (
    SELECT sp.*, (
      SELECT ps.Party FROM src.party_service ps
      WHERE ps.PHID = sp.PHID AND ps.DateStart <= sp.date
        AND (ps.DateEnd IS NULL OR sp.date <= ps.DateEnd)
      ORDER BY ps.DateStart DESC, ps.DateEnd DESC NULLS FIRST, ps.Party ASC LIMIT 1
    ) AS party
    FROM sp
  )
  SELECT p1.PHID, p1.sitting_id AS s1, p2.sitting_id AS s2,
         p1.chamber AS c1, p1.era AS e1, p2.chamber AS c2, p2.era AS e2,
         p1.n_actions + p2.n_actions AS size
  FROM pp p1 JOIN pp p2 ON p1.PHID = p2.PHID AND p1.party <> p2.party
   AND (p1.chamber, p1.era) < (p2.chamber, p2.era)
  ORDER BY size, p1.PHID, s1, s2
  LIMIT 1
")
stopifnot(nrow(pairs) == 1)

picked <- data.frame(
  chamber = c(pairs$c1, pairs$c2), era = c(pairs$e1, pairs$e2),
  sitting_id = c(pairs$s1, pairs$s2)
)

# ---- 3. Fill the remaining chamber x era slots ---------------------------------------------
# Prefer days with a resolved interjection target and a sentinel turn; then the smallest day.
slots <- expand.grid(chamber = c("house", "senate"), era = eras, stringsAsFactors = FALSE)
for (i in seq_len(nrow(slots))) {
  sl <- slots[i, ]
  if (any(picked$chamber == sl$chamber & picked$era == sl$era)) next
  best <- q(sprintf("
    SELECT sitting_id FROM cand WHERE chamber = '%s' AND era = '%s'
    ORDER BY (n_targets > 0 AND n_sentinel > 0) DESC, n_actions, sitting_id LIMIT 1
  ", sl$chamber, sl$era))
  stopifnot(nrow(best) == 1)
  picked <- rbind(picked, data.frame(chamber = sl$chamber, era = sl$era, best))
}
stopifnot(nrow(picked) == 8)

# ---- 3b. A quote with no named reader (NULL resolution) ------------------------------------
# If no chosen day has one, one of the six filled slots (never the party-change pair) is
# re-picked: among quote-bearing candidates in those slots, prefer both features, then the
# smallest day.
has_quote <- q("SELECT sitting_id FROM cand WHERE n_quote_null > 0")$sitting_id
if (!any(picked$sitting_id %in% has_quote)) {
  DBI::dbWriteTable(con, "fill_slots", picked[-(1:2), c("chamber", "era")], temporary = TRUE)
  swap <- q("
    SELECT chamber, era, sitting_id FROM cand JOIN fill_slots USING (chamber, era)
    WHERE n_quote_null > 0
    ORDER BY (n_targets > 0 AND n_sentinel > 0) DESC, n_actions, sitting_id LIMIT 1
  ")
  stopifnot(nrow(swap) == 1)
  at <- which(picked$chamber == swap$chamber & picked$era == swap$era)
  picked$sitting_id[at] <- swap$sitting_id
}
stopifnot(any(picked$sitting_id %in% has_quote))
DBI::dbWriteTable(con, "pick", picked, temporary = TRUE)

# ---- 4. Copy spine (filtered) and reference (whole) tables ---------------------------------
spine <- c(
  sittings = "SELECT * FROM src.sittings WHERE sitting_id IN (SELECT sitting_id FROM pick)",
  debates = "SELECT * FROM src.debates WHERE sitting_id IN (SELECT sitting_id FROM pick)",
  subdebates = "SELECT * FROM src.subdebates WHERE debate_id IN
                  (SELECT debate_id FROM src.debates
                   WHERE sitting_id IN (SELECT sitting_id FROM pick))",
  actions = "SELECT * FROM src.actions WHERE sitting_id IN (SELECT sitting_id FROM pick)",
  provenance = "SELECT * FROM src.provenance WHERE sitting_id IN (SELECT sitting_id FROM pick)",
  parse_errors = "SELECT * FROM src.parse_errors WHERE path IN
                    (SELECT path FROM src.provenance
                     WHERE sitting_id IN (SELECT sitting_id FROM pick))"
)
for (nm in names(spine)) x(sprintf("CREATE TABLE out.main.%s AS %s", nm, spine[[nm]]))

# Reference tables: PHID-keyed ones keep only members who appear in the sample's turns, as
# speaker (PHID) or as presiding officer (presiding_phid); the rest (parties, parliaments,
# ministries, elections, ...) are copied whole.
x("CREATE TEMP TABLE keep_phid AS
   SELECT PHID FROM out.main.actions WHERE PHID IS NOT NULL
   UNION
   SELECT presiding_phid FROM out.main.actions WHERE presiding_phid IS NOT NULL")
base <- q("SELECT table_name FROM duckdb_tables()
           WHERE database_name = 'src' AND schema_name = 'main' AND NOT temporary
           ORDER BY table_name")$table_name
phid_tables <- q("SELECT DISTINCT table_name FROM duckdb_columns()
                  WHERE database_name = 'src' AND schema_name = 'main'
                    AND column_name = 'PHID'")$table_name
for (nm in setdiff(base, names(spine))) {
  where <- if (nm %in% phid_tables) " WHERE PHID IN (SELECT PHID FROM keep_phid)" else ""
  x(sprintf("CREATE TABLE out.main.%s AS SELECT * FROM src.main.%s%s", nm, nm, where))
}

# ---- 5. Views, verbatim --------------------------------------------------------------------
views <- q("SELECT view_name, sql FROM duckdb_views()
            WHERE database_name = 'src' AND schema_name = 'main' AND NOT internal
            ORDER BY view_name")
x("USE out")
# Views may reference each other; retry until every one is created.
pending <- views
while (nrow(pending) > 0) {
  ok <- vapply(seq_len(nrow(pending)), function(i) {
    tryCatch({
      x(pending$sql[i])
      TRUE
    }, error = function(e) FALSE)
  }, logical(1))
  if (!any(ok)) stop("Could not create views: ", paste(pending$view_name, collapse = ", "))
  pending <- pending[!ok, ]
}

x("DETACH src")

# ---- 6. Full-text index, same pragma as the full database ----------------------------------
# Tokens break on every Unicode number, punctuation, symbol and separator (and zero-width
# space), as in the full database's index.
fts_ignore <- "[\\p{N}\\p{P}\\p{S}\\p{Z}\\x{200B}]+"
x("INSTALL fts")
x("LOAD fts")
x(sprintf(
  "PRAGMA create_fts_index('actions', 'action_id', 'content', ignore='%s', overwrite=1)",
  fts_ignore
))
x("CHECKPOINT out")

# ---- 7. Report ------------------------------------------------------------------------------
print(q("SELECT s.sitting_id, s.chamber, s.date, p.schema_generation AS era, count(a.*) AS n_actions
         FROM sittings s JOIN provenance p USING (sitting_id) JOIN actions a USING (sitting_id)
         GROUP BY ALL ORDER BY chamber, date"))
print(q("SELECT 'members' AS tbl, count(*) AS n FROM members
         UNION ALL SELECT 'actions', count(*) FROM actions
         UNION ALL SELECT 'quotes with NULL resolution', count(*) FROM actions
           WHERE action_type = 'quote' AND resolution IS NULL"))
cat("Party-changing PHID:", pairs$PHID, "\n")
x("USE memory")
x("DETACH out")
cat("Size (MB):", round(file.size(out_db) / 2^20, 2), "\n")
