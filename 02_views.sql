-- =============================================================================
-- SEO Analytics Portfolio | Daniel Muyeba
-- =============================================================================
-- FILE: 02_views.sql
-- PURPOSE: Reusable transformation views built on top of stg_page_performance.
--
--   View hierarchy (each layer builds on the one above):
--
--   stg_page_performance          ← raw staging table
--       └── vw_page_base          ← cleaned types, derived metrics
--               ├── vw_quick_wins             ← ranking opportunity filter
--               ├── vw_segment_summary        ← segment-level KPI rollup
--               ├── vw_position_distribution  ← SERP position bucketing
--               ├── vw_crawl_efficiency       ← crawl budget waste signals
--               └── vw_content_health         ← on-page quality flags
--
-- COMPATIBLE WITH: PostgreSQL 13+, SQLite 3.35+
--   SQLite note: FILTER (WHERE ...) on aggregates requires SQLite 3.30+.
--   Replace with CASE WHEN inside SUM() if on an older version.
-- =============================================================================


-- =============================================================================
-- LAYER 1 — BASE VIEW
-- Clean types, standardise nulls, compute fundamental derived metrics.
-- All downstream views reference this view rather than the raw table,
-- so any cleaning fix here propagates everywhere automatically.
-- =============================================================================

DROP VIEW IF EXISTS vw_page_base;

CREATE VIEW vw_page_base AS

SELECT
    page_id,

    -- ------------------------------------------------------------------
    -- Search performance (pass-through; already clean in staging)
    -- ------------------------------------------------------------------
    clicks,
    impressions,
    position,

    -- Calculated CTR — guarded against division-by-zero for zero-impression rows
    CASE
        WHEN impressions > 0 THEN ROUND(CAST(clicks AS REAL) / impressions, 4)
        ELSE NULL
    END AS ctr,

    -- ------------------------------------------------------------------
    -- Engagement signals (may be NULL for crawl-only rows)
    -- ------------------------------------------------------------------
    bounce_rate,
    view_depth,
    time_spent,

    -- Convert HH:MM:SS to total seconds for arithmetic downstream.
    -- Splits on ':' and weights hours × 3600, minutes × 60, seconds × 1.
    -- Returns NULL if time_spent is NULL or malformed.
    CASE
        WHEN time_spent IS NOT NULL
             AND time_spent GLOB '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
        THEN (
            CAST(SUBSTR(time_spent, 1, 2) AS INTEGER) * 3600 +
            CAST(SUBSTR(time_spent, 4, 2) AS INTEGER) * 60  +
            CAST(SUBSTR(time_spent, 7, 2) AS INTEGER)
        )
        ELSE NULL
    END AS time_spent_seconds,

    robots_visits,
    mobility,

    -- ------------------------------------------------------------------
    -- Page taxonomy
    -- ------------------------------------------------------------------
    COALESCE(segment, 'uncategorised') AS segment,

    -- ------------------------------------------------------------------
    -- On-page content signals (may be NULL for analytics-only rows)
    -- ------------------------------------------------------------------
    title_length,
    meta_description_length,
    h1_length,
    word_count,
    sentence_count,

    -- ------------------------------------------------------------------
    -- Technical signals
    -- ------------------------------------------------------------------
    folder_depth,
    link_score,
    inlinks,
    outlinks,
    response_time,

    -- ------------------------------------------------------------------
    -- SERP position bucket — used throughout analysis
    --   Top 3:    featured / branded dominance
    --   4–10:     page 1 but not podium
    --   11–20:    page 2 — prime quick-win territory
    --   21–50:    middle ground — needs significant work
    --   51+:      effectively invisible for most queries
    -- ------------------------------------------------------------------
    CASE
        WHEN position BETWEEN 1  AND 3   THEN '1. Top 3'
        WHEN position BETWEEN 4  AND 10  THEN '2. Page 1 (4-10)'
        WHEN position BETWEEN 11 AND 20  THEN '3. Page 2 (11-20)'
        WHEN position BETWEEN 21 AND 50  THEN '4. Mid (21-50)'
        WHEN position > 50               THEN '5. Deep (51+)'
        ELSE                                  'Unknown'
    END AS position_bucket,

    -- ------------------------------------------------------------------
    -- Content length quality flags
    -- SEO best-practice thresholds used by most technical audit tools
    -- ------------------------------------------------------------------

    -- Title: ideal 50–60 chars; <30 or >70 is flagged
    CASE
        WHEN title_length IS NULL        THEN 'missing'
        WHEN title_length < 30           THEN 'too_short'
        WHEN title_length BETWEEN 30 AND 60 THEN 'optimal'
        WHEN title_length > 60           THEN 'too_long'
    END AS title_length_flag,

    -- Meta description: ideal 120–158 chars
    CASE
        WHEN meta_description_length IS NULL          THEN 'missing'
        WHEN meta_description_length < 70             THEN 'too_short'
        WHEN meta_description_length BETWEEN 70 AND 158 THEN 'optimal'
        WHEN meta_description_length > 158            THEN 'too_long'
    END AS meta_desc_flag,

    -- H1: present = 1+, absent = 0
    CASE
        WHEN h1_length IS NULL THEN 'missing'
        WHEN h1_length = 0     THEN 'absent'
        ELSE                        'present'
    END AS h1_flag,

    -- Response time classification (seconds)
    --   <0.8s = fast (good TTFB), 0.8–2s = acceptable, >2s = slow
    CASE
        WHEN response_time IS NULL  THEN 'unknown'
        WHEN response_time < 0.8    THEN 'fast'
        WHEN response_time <= 2.0   THEN 'acceptable'
        ELSE                             'slow'
    END AS response_time_flag

FROM stg_page_performance;


-- =============================================================================
-- LAYER 2a — QUICK WIN OPPORTUNITIES
-- Pages in positions 4–20 with sufficient search volume that would benefit
-- from CTR optimisation (title/meta rewrites) or minor content improvements.
-- These are the highest-ROI pages for an SEO team to focus on first.
-- =============================================================================

DROP VIEW IF EXISTS vw_quick_wins;

CREATE VIEW vw_quick_wins AS

SELECT
    page_id,
    segment,
    clicks,
    impressions,
    position,
    ctr,
    position_bucket,

    -- Expected CTR benchmarks by position (industry averages, rounded)
    -- Used to surface pages underperforming vs their ranking peers
    CASE
        WHEN position BETWEEN 1  AND 1  THEN 0.28
        WHEN position BETWEEN 2  AND 2  THEN 0.15
        WHEN position BETWEEN 3  AND 3  THEN 0.11
        WHEN position BETWEEN 4  AND 5  THEN 0.08
        WHEN position BETWEEN 6  AND 10 THEN 0.05
        WHEN position BETWEEN 11 AND 20 THEN 0.02
        ELSE                                 0.01
    END AS expected_ctr_benchmark,

    -- Actual vs expected CTR gap (negative = underperforming)
    ROUND(
        ctr - CASE
            WHEN position BETWEEN 1  AND 1  THEN 0.28
            WHEN position BETWEEN 2  AND 2  THEN 0.15
            WHEN position BETWEEN 3  AND 3  THEN 0.11
            WHEN position BETWEEN 4  AND 5  THEN 0.08
            WHEN position BETWEEN 6  AND 10 THEN 0.05
            WHEN position BETWEEN 11 AND 20 THEN 0.02
            ELSE                                 0.01
        END
    , 4) AS ctr_gap,

    -- Estimated click uplift if CTR reached benchmark (headline metric)
    ROUND(
        impressions * (
            CASE
                WHEN position BETWEEN 1  AND 1  THEN 0.28
                WHEN position BETWEEN 2  AND 2  THEN 0.15
                WHEN position BETWEEN 3  AND 3  THEN 0.11
                WHEN position BETWEEN 4  AND 5  THEN 0.08
                WHEN position BETWEEN 6  AND 10 THEN 0.05
                WHEN position BETWEEN 11 AND 20 THEN 0.02
                ELSE                                 0.01
            END - ctr
        )
    , 0) AS estimated_click_uplift,

    -- On-page signals to help prioritise which pages to fix first
    title_length,
    title_length_flag,
    meta_desc_flag,
    h1_flag,
    word_count,
    inlinks,
    link_score

FROM vw_page_base

WHERE
    -- Position range most likely to benefit from CTR optimisation
    position BETWEEN 4 AND 20

    -- Enough search volume to be worth the effort
    AND impressions >= 100

    -- Exclude pages already performing above benchmark (not a quick win)
    AND ctr < CASE
        WHEN position BETWEEN 4  AND 5  THEN 0.08
        WHEN position BETWEEN 6  AND 10 THEN 0.05
        WHEN position BETWEEN 11 AND 20 THEN 0.02
        ELSE 0.01
    END

ORDER BY estimated_click_uplift DESC;


-- =============================================================================
-- LAYER 2b — SEGMENT SUMMARY
-- Aggregate KPIs rolled up by page type (product / catalog / brands).
-- Useful as a dashboard-level summary and for Python/R analysis input.
-- =============================================================================

DROP VIEW IF EXISTS vw_segment_summary;

CREATE VIEW vw_segment_summary AS

SELECT
    segment,

    -- Volume
    COUNT(*)                                        AS total_pages,
    SUM(clicks)                                     AS total_clicks,
    SUM(impressions)                                AS total_impressions,

    -- Performance averages
    ROUND(AVG(position), 2)                         AS avg_position,
    ROUND(AVG(ctr), 4)                              AS avg_ctr,
    ROUND(CAST(SUM(clicks) AS REAL)
          / NULLIF(SUM(impressions), 0), 4)         AS blended_ctr,

    -- Engagement (only rows with analytics data)
    ROUND(AVG(bounce_rate), 3)                      AS avg_bounce_rate,
    ROUND(AVG(view_depth), 2)                       AS avg_view_depth,
    ROUND(AVG(time_spent_seconds), 0)               AS avg_time_spent_seconds,

    -- Technical health
    ROUND(AVG(response_time), 3)                    AS avg_response_time_s,
    ROUND(AVG(inlinks), 1)                          AS avg_inlinks,
    ROUND(AVG(link_score), 2)                       AS avg_link_score,

    -- Zero-click pages (crawl waste or ranking-but-not-winning)
    SUM(CASE WHEN clicks = 0 THEN 1 ELSE 0 END)    AS zero_click_pages,
    ROUND(
        100.0 * SUM(CASE WHEN clicks = 0 THEN 1 ELSE 0 END) / COUNT(*)
    , 1)                                            AS pct_zero_click,

    -- Quick win candidates within this segment
    SUM(CASE
        WHEN position BETWEEN 4 AND 20
         AND impressions >= 100
        THEN 1 ELSE 0
    END)                                            AS quick_win_candidates,

    -- Content health flags
    SUM(CASE WHEN title_length_flag  = 'optimal'   THEN 1 ELSE 0 END) AS titles_optimal,
    SUM(CASE WHEN meta_desc_flag     = 'optimal'   THEN 1 ELSE 0 END) AS meta_descs_optimal,
    SUM(CASE WHEN h1_flag            = 'present'   THEN 1 ELSE 0 END) AS h1_present,
    SUM(CASE WHEN response_time_flag = 'slow'      THEN 1 ELSE 0 END) AS slow_pages

FROM vw_page_base

GROUP BY segment

ORDER BY total_clicks DESC;


-- =============================================================================
-- LAYER 2c — POSITION DISTRIBUTION
-- SERP ranking distribution across position buckets, split by segment.
-- Shows the shape of the site's ranking profile at a glance.
-- =============================================================================

DROP VIEW IF EXISTS vw_position_distribution;

CREATE VIEW vw_position_distribution AS

SELECT
    segment,
    position_bucket,
    COUNT(*)                                            AS page_count,
    SUM(clicks)                                         AS total_clicks,
    SUM(impressions)                                    AS total_impressions,
    ROUND(AVG(ctr), 4)                                  AS avg_ctr,
    ROUND(AVG(position), 2)                             AS avg_position,

    -- Share of this segment's total clicks in each bucket
    ROUND(
        100.0 * SUM(clicks)
        / NULLIF(SUM(SUM(clicks)) OVER (PARTITION BY segment), 0)
    , 1)                                                AS pct_segment_clicks,

    -- Share of total site clicks (cross-segment context)
    ROUND(
        100.0 * SUM(clicks)
        / NULLIF(SUM(SUM(clicks)) OVER (), 0)
    , 1)                                                AS pct_total_clicks

FROM vw_page_base

GROUP BY segment, position_bucket

ORDER BY segment, position_bucket;


-- =============================================================================
-- LAYER 2d — CRAWL EFFICIENCY
-- Identifies pages consuming crawl budget without generating organic value.
-- High robot visits + zero clicks = likely crawl waste; can guide robots.txt
-- or noindex decisions, or highlight orphaned/thin content.
-- =============================================================================

DROP VIEW IF EXISTS vw_crawl_efficiency;

CREATE VIEW vw_crawl_efficiency AS

SELECT
    page_id,
    segment,
    clicks,
    impressions,
    position,
    robots_visits,

    -- Clicks generated per robot visit (efficiency ratio)
    -- NULL if robots_visits = 0 (no crawl data for this page)
    CASE
        WHEN robots_visits > 0
        THEN ROUND(CAST(clicks AS REAL) / robots_visits, 4)
        ELSE NULL
    END AS clicks_per_robot_visit,

    -- Waste classification
    CASE
        WHEN robots_visits = 0                          THEN 'not_crawled'
        WHEN clicks = 0 AND robots_visits > 10          THEN 'high_waste'
        WHEN clicks = 0 AND robots_visits BETWEEN 1 AND 10 THEN 'low_waste'
        WHEN clicks > 0 AND robots_visits > 0
             AND (CAST(clicks AS REAL) / robots_visits) < 0.1
                                                        THEN 'inefficient'
        ELSE                                                 'efficient'
    END AS crawl_efficiency_flag,

    -- Contextual signals to explain waste
    word_count,
    inlinks,
    folder_depth,
    response_time_flag

FROM vw_page_base

ORDER BY robots_visits DESC, clicks ASC;


-- =============================================================================
-- LAYER 2e — CONTENT HEALTH AUDIT
-- Flags on-page issues across the crawled page set.
-- Designed to replicate the output of a manual SEO content audit,
-- prioritised by the pages with the most impressions (highest visibility).
-- =============================================================================

DROP VIEW IF EXISTS vw_content_health;

CREATE VIEW vw_content_health AS

SELECT
    page_id,
    segment,
    clicks,
    impressions,
    position,
    position_bucket,

    -- Raw measurements
    title_length,
    meta_description_length,
    h1_length,
    word_count,
    sentence_count,
    response_time,
    inlinks,
    link_score,
    folder_depth,

    -- Quality flags (from vw_page_base)
    title_length_flag,
    meta_desc_flag,
    h1_flag,
    response_time_flag,

    -- Word count classification (thin / adequate / rich content)
    CASE
        WHEN word_count IS NULL      THEN 'unknown'
        WHEN word_count < 200        THEN 'thin'
        WHEN word_count BETWEEN 200 AND 600 THEN 'adequate'
        ELSE                              'rich'
    END AS content_depth_flag,

    -- Internal link equity flag
    CASE
        WHEN inlinks IS NULL         THEN 'unknown'
        WHEN inlinks = 0             THEN 'orphaned'
        WHEN inlinks < 5             THEN 'poorly_linked'
        ELSE                              'well_linked'
    END AS internal_link_flag,

    -- Total count of issues on this page (useful for sorting / triage)
    (
        CASE WHEN title_length_flag  != 'optimal'      THEN 1 ELSE 0 END +
        CASE WHEN meta_desc_flag     != 'optimal'      THEN 1 ELSE 0 END +
        CASE WHEN h1_flag             = 'absent'       THEN 1 ELSE 0 END +
        CASE WHEN response_time_flag  = 'slow'         THEN 1 ELSE 0 END +
        CASE WHEN word_count < 200
              AND word_count IS NOT NULL               THEN 1 ELSE 0 END +
        CASE WHEN inlinks = 0
              AND inlinks IS NOT NULL                  THEN 1 ELSE 0 END
    ) AS issue_count

FROM vw_page_base

-- Only include pages that have been crawled (have on-page data)
WHERE title_length IS NOT NULL

ORDER BY issue_count DESC, impressions DESC;
