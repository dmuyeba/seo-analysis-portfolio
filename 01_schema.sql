-- =============================================================================
-- SEO Analytics Portfolio | Daniel Muyeba
-- =============================================================================
-- FILE: 01_schema.sql
-- PURPOSE: Raw staging table that mirrors the source data export exactly.
--          All cleaning and transformation happens downstream in views —
--          this table is intentionally kept close to the source format.
--
-- COMPATIBLE WITH: PostgreSQL 13+ and SQLite 3.35+
--   PostgreSQL-only syntax is noted inline where used.
--   SQLite users: replace NUMERIC(x,y) with REAL, and drop CHECK constraints
--   if your SQLite version is < 3.25.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- DROP & RECREATE (safe for re-runs)
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS stg_page_performance;


-- -----------------------------------------------------------------------------
-- STAGING TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE stg_page_performance (

    -- Surrogate primary key
    -- PostgreSQL: use SERIAL or GENERATED ALWAYS AS IDENTITY
    -- SQLite:     INTEGER PRIMARY KEY auto-increments
    page_id         INTEGER PRIMARY KEY,

    -- -------------------------------------------------------------------------
    -- SEARCH PERFORMANCE SIGNALS
    -- Source: Google Search Console / rank tracker export
    -- -------------------------------------------------------------------------

    -- Total organic clicks in the measurement period
    clicks          INTEGER     NOT NULL DEFAULT 0,

    -- Total impressions (times the page appeared in SERPs)
    impressions     INTEGER     NOT NULL DEFAULT 0,

    -- Average ranking position (lower = better; 1.0 = top of page 1)
    -- Stored as REAL because GSC averages produce decimals (e.g. 8.6)
    position        REAL        CHECK (position > 0),

    -- -------------------------------------------------------------------------
    -- USER ENGAGEMENT SIGNALS
    -- Source: Google Analytics 4 / web analytics platform
    -- NULL = page not present in analytics export (crawl-only rows)
    -- -------------------------------------------------------------------------

    -- Proportion of sessions that left without further interaction (0–1)
    bounce_rate     REAL        CHECK (bounce_rate BETWEEN 0 AND 1),

    -- Average number of pages viewed per session originating from this page
    view_depth      REAL        CHECK (view_depth >= 0),

    -- Average time on page — stored as HH:MM:SS text (matches source format)
    -- Convert to seconds in views where arithmetic is needed
    time_spent      TEXT,

    -- Crawl bot visits in the period — proxy for crawl budget consumption
    robots_visits   INTEGER     DEFAULT 0,

    -- Share of sessions from mobile devices (0–1)
    mobility        REAL        CHECK (mobility BETWEEN 0 AND 1),

    -- -------------------------------------------------------------------------
    -- PAGE TAXONOMY
    -- -------------------------------------------------------------------------

    -- Page type category: 'product', 'catalog', 'brands', or NULL (uncategorised)
    segment         TEXT        CHECK (segment IN ('product', 'catalog', 'brands')),

    -- -------------------------------------------------------------------------
    -- ON-PAGE CONTENT SIGNALS
    -- Source: Screaming Frog / crawler export
    -- NULL = page not crawled (analytics-only rows)
    -- -------------------------------------------------------------------------

    -- Character length of the <title> tag
    title_length            INTEGER     CHECK (title_length >= 0),

    -- Character length of the meta description
    meta_description_length INTEGER     CHECK (meta_description_length >= 0),

    -- Character length of the primary H1
    h1_length               INTEGER     CHECK (h1_length >= 0),

    -- Total word count of the page body
    word_count              INTEGER     CHECK (word_count >= 0),

    -- Number of sentences on the page (readability signal)
    sentence_count          INTEGER     CHECK (sentence_count >= 0),

    -- -------------------------------------------------------------------------
    -- TECHNICAL SEO SIGNALS
    -- -------------------------------------------------------------------------

    -- URL depth: number of subdirectory levels (e.g. /a/b/c/ = depth 3)
    folder_depth    INTEGER     CHECK (folder_depth >= 0),

    -- Internal link equity score (0–99; proprietary or calculated metric)
    link_score      REAL        CHECK (link_score BETWEEN 0 AND 99),

    -- Number of internal links pointing TO this page
    inlinks         INTEGER     CHECK (inlinks >= 0),

    -- Number of internal links FROM this page to other pages
    outlinks        INTEGER     CHECK (outlinks >= 0),

    -- Server response time in seconds (Core Web Vitals proxy — TTFB adjacent)
    response_time   REAL        CHECK (response_time >= 0)

);


-- -----------------------------------------------------------------------------
-- INDEXES
-- Covering the columns most commonly used in WHERE / GROUP BY clauses
-- -----------------------------------------------------------------------------

-- Segment filter is used in almost every analytical query
CREATE INDEX IF NOT EXISTS idx_stg_segment
    ON stg_page_performance (segment);

-- Position bucketing queries
CREATE INDEX IF NOT EXISTS idx_stg_position
    ON stg_page_performance (position);

-- Click/impression range filters
CREATE INDEX IF NOT EXISTS idx_stg_clicks_impressions
    ON stg_page_performance (clicks, impressions);

-- Internal linking analysis
CREATE INDEX IF NOT EXISTS idx_stg_inlinks
    ON stg_page_performance (inlinks);


-- =============================================================================
-- LOAD INSTRUCTIONS
-- =============================================================================
--
-- OPTION A — SQLite (quickest for local dev / portfolio demo):
--
--   sqlite3 seo_portfolio.db < 01_schema.sql
--
--   Then import from CSV:
--   .mode csv
--   .separator ";"
--   .import data/data.csv stg_page_performance
--
--   Note: SQLite's .import treats row 1 as data if the table already exists
--   and has no header awareness — use the Python loader instead (see README).
--
-- OPTION B — PostgreSQL:
--
--   psql -d seo_portfolio -f 01_schema.sql
--
--   Then use COPY or the Python loader:
--   COPY stg_page_performance(clicks, impressions, ...)
--   FROM '/path/to/data.csv'
--   WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '');
--
-- OPTION C — Python loader (recommended; handles type coercion automatically):
--   See scripts/load_data.py in the repo root.
--
-- =============================================================================
