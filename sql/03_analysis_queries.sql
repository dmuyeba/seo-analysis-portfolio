-- =============================================================================
-- SEO Analytics Portfolio | Daniel Muyeba
-- =============================================================================
-- FILE: 03_analysis_queries.sql
-- PURPOSE: Standalone analytical queries for exploration and reporting.
--          Each query is self-contained, references the views from 02_views.sql,
--          and is annotated with the business question it answers.
--          These are the queries you would run interactively or pipe into
--          a BI tool / Python / R for further analysis.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — SITE-LEVEL OVERVIEW
-- =============================================================================

-- Q1: Top-line site health dashboard
-- What does the site's overall search performance look like?
-- -----------------------------------------------------------------------
SELECT
    COUNT(*)                                        AS total_pages,
    SUM(clicks)                                     AS total_clicks,
    SUM(impressions)                                AS total_impressions,
    ROUND(CAST(SUM(clicks) AS REAL)
          / NULLIF(SUM(impressions), 0) * 100, 2)  AS overall_ctr_pct,
    ROUND(AVG(position), 2)                         AS avg_position,
    SUM(CASE WHEN clicks = 0 THEN 1 ELSE 0 END)    AS zero_click_pages,
    ROUND(100.0 * SUM(CASE WHEN clicks = 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS pct_zero_click,
    SUM(CASE WHEN position BETWEEN 4 AND 20
             AND impressions >= 100
        THEN 1 ELSE 0 END)                          AS quick_win_candidates
FROM vw_page_base;


-- Q2: Performance by segment — the segment comparison table
-- How do product, catalog, and brand pages compare on every KPI?
-- -----------------------------------------------------------------------
SELECT *
FROM vw_segment_summary;


-- Q3: SERP position distribution
-- What proportion of pages rank on page 1, page 2, etc.?
-- -----------------------------------------------------------------------
SELECT
    position_bucket,
    COUNT(*)                                    AS pages,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_pages,
    SUM(clicks)                                 AS clicks,
    ROUND(100.0 * SUM(clicks) / NULLIF(SUM(SUM(clicks)) OVER (), 0), 1) AS pct_clicks,
    ROUND(AVG(ctr) * 100, 2)                    AS avg_ctr_pct
FROM vw_page_base
GROUP BY position_bucket
ORDER BY position_bucket;


-- =============================================================================
-- SECTION 2 — QUICK WIN OPPORTUNITIES
-- =============================================================================

-- Q4: Top 25 quick-win pages by estimated click uplift
-- Which pages would drive the most additional clicks if CTR reached benchmark?
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    impressions,
    ROUND(position, 1)                          AS position,
    ROUND(ctr * 100, 2)                         AS actual_ctr_pct,
    ROUND(expected_ctr_benchmark * 100, 2)      AS benchmark_ctr_pct,
    ROUND(ctr_gap * 100, 2)                     AS ctr_gap_pct,
    estimated_click_uplift,
    title_length_flag,
    meta_desc_flag,
    h1_flag
FROM vw_quick_wins
LIMIT 25;


-- Q5: Quick wins segmented — where is the opportunity concentrated?
-- Are the biggest gains in product pages, catalog pages, or brand pages?
-- -----------------------------------------------------------------------
SELECT
    segment,
    COUNT(*)                                    AS candidate_pages,
    SUM(estimated_click_uplift)                 AS total_click_uplift,
    ROUND(AVG(estimated_click_uplift), 0)       AS avg_click_uplift_per_page,
    ROUND(AVG(ctr_gap * 100), 2)               AS avg_ctr_gap_pct,
    SUM(CASE WHEN title_length_flag != 'optimal' THEN 1 ELSE 0 END) AS suboptimal_titles,
    SUM(CASE WHEN meta_desc_flag    != 'optimal' THEN 1 ELSE 0 END) AS suboptimal_metas
FROM vw_quick_wins
GROUP BY segment
ORDER BY total_click_uplift DESC;


-- Q6: Position 11–20 pages with high impressions (page 2 to page 1 lifts)
-- A single position bucket often missed — these pages just need a nudge.
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    impressions,
    ROUND(position, 1)                          AS position,
    ROUND(ctr * 100, 2)                         AS ctr_pct,
    estimated_click_uplift,
    inlinks,
    link_score,
    word_count
FROM vw_quick_wins
WHERE position BETWEEN 11 AND 20
ORDER BY impressions DESC
LIMIT 20;


-- =============================================================================
-- SECTION 3 — INTERNAL LINKING & LINK EQUITY
-- =============================================================================

-- Q7: Link score distribution — is link equity well spread?
-- Heavy concentration of link score on a few pages suggests poor distribution.
-- -----------------------------------------------------------------------
SELECT
    CASE
        WHEN link_score = 0             THEN '0 — no equity'
        WHEN link_score BETWEEN 1 AND 5 THEN '1–5'
        WHEN link_score BETWEEN 6 AND 20 THEN '6–20'
        WHEN link_score BETWEEN 21 AND 50 THEN '21–50'
        ELSE                                 '51–99 — high equity'
    END AS link_score_band,
    COUNT(*)                            AS pages,
    ROUND(AVG(clicks), 1)               AS avg_clicks,
    ROUND(AVG(position), 2)             AS avg_position,
    ROUND(AVG(ctr) * 100, 2)           AS avg_ctr_pct
FROM vw_page_base
WHERE link_score IS NOT NULL
GROUP BY link_score_band
ORDER BY MIN(link_score);


-- Q8: Poorly linked pages with good ranking potential
-- Orphaned or poorly linked pages sitting on page 1/2 — easy internal linking wins.
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    clicks,
    impressions,
    ROUND(position, 1)                  AS position,
    inlinks,
    link_score,
    internal_link_flag
FROM vw_content_health
WHERE internal_link_flag IN ('orphaned', 'poorly_linked')
  AND position <= 20
  AND impressions >= 50
ORDER BY impressions DESC
LIMIT 20;


-- =============================================================================
-- SECTION 4 — CRAWL BUDGET ANALYSIS
-- =============================================================================

-- Q9: Crawl efficiency summary
-- How is the site's crawl budget being allocated?
-- -----------------------------------------------------------------------
SELECT
    crawl_efficiency_flag,
    COUNT(*)                                AS pages,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_pages,
    SUM(robots_visits)                      AS total_robot_visits,
    ROUND(100.0 * SUM(robots_visits)
          / NULLIF(SUM(SUM(robots_visits)) OVER (), 0), 1) AS pct_robot_visits,
    SUM(clicks)                             AS total_clicks
FROM vw_crawl_efficiency
GROUP BY crawl_efficiency_flag
ORDER BY total_robot_visits DESC;


-- Q10: Top 20 crawl-wasteful pages
-- Pages consuming the most crawl budget while generating zero organic value.
-- These are candidates for noindex, consolidation, or robots.txt exclusion.
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    robots_visits,
    clicks,
    impressions,
    ROUND(position, 1)                  AS position,
    word_count,
    inlinks,
    response_time_flag
FROM vw_crawl_efficiency
WHERE crawl_efficiency_flag = 'high_waste'
ORDER BY robots_visits DESC
LIMIT 20;


-- =============================================================================
-- SECTION 5 — CONTENT & TECHNICAL HEALTH
-- =============================================================================

-- Q11: Content issue frequency — what are the most common on-page problems?
-- -----------------------------------------------------------------------
SELECT 'Title too short'         AS issue, SUM(CASE WHEN title_length_flag  = 'too_short' THEN 1 ELSE 0 END) AS pages FROM vw_content_health
UNION ALL
SELECT 'Title too long',                   SUM(CASE WHEN title_length_flag  = 'too_long'  THEN 1 ELSE 0 END) FROM vw_content_health
UNION ALL
SELECT 'Meta description too short',       SUM(CASE WHEN meta_desc_flag     = 'too_short' THEN 1 ELSE 0 END) FROM vw_content_health
UNION ALL
SELECT 'Meta description too long',        SUM(CASE WHEN meta_desc_flag     = 'too_long'  THEN 1 ELSE 0 END) FROM vw_content_health
UNION ALL
SELECT 'H1 absent',                        SUM(CASE WHEN h1_flag            = 'absent'    THEN 1 ELSE 0 END) FROM vw_content_health
UNION ALL
SELECT 'Thin content (<200 words)',         SUM(CASE WHEN content_depth_flag = 'thin'      THEN 1 ELSE 0 END) FROM vw_content_health
UNION ALL
SELECT 'Slow response time (>2s)',          SUM(CASE WHEN response_time_flag = 'slow'      THEN 1 ELSE 0 END) FROM vw_content_health
UNION ALL
SELECT 'Orphaned (0 inlinks)',              SUM(CASE WHEN internal_link_flag = 'orphaned'  THEN 1 ELSE 0 END) FROM vw_content_health
ORDER BY pages DESC;


-- Q12: Multi-issue pages — which pages have 3+ problems simultaneously?
-- The most technically broken pages, sorted by organic visibility.
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    impressions,
    ROUND(position, 1)          AS position,
    issue_count,
    title_length_flag,
    meta_desc_flag,
    h1_flag,
    content_depth_flag,
    internal_link_flag,
    response_time_flag
FROM vw_content_health
WHERE issue_count >= 3
ORDER BY issue_count DESC, impressions DESC
LIMIT 25;


-- Q13: Response time vs. performance — do slow pages rank worse?
-- Aggregate view to feed into the R statistical analysis.
-- -----------------------------------------------------------------------
SELECT
    response_time_flag,
    segment,
    COUNT(*)                        AS pages,
    ROUND(AVG(position), 2)         AS avg_position,
    ROUND(AVG(ctr) * 100, 2)       AS avg_ctr_pct,
    ROUND(AVG(bounce_rate) * 100, 2) AS avg_bounce_pct,
    ROUND(AVG(clicks), 1)           AS avg_clicks
FROM vw_page_base
WHERE response_time_flag != 'unknown'
GROUP BY response_time_flag, segment
ORDER BY segment, avg_position;


-- =============================================================================
-- SECTION 6 — ENGAGEMENT DEEP DIVE
-- =============================================================================

-- Q14: Engagement signals by position bucket
-- Do higher-ranking pages engage users better? Or does the data complicate that?
-- -----------------------------------------------------------------------
SELECT
    position_bucket,
    COUNT(*)                                    AS pages,
    ROUND(AVG(bounce_rate) * 100, 1)           AS avg_bounce_pct,
    ROUND(AVG(view_depth), 2)                   AS avg_view_depth,
    ROUND(AVG(time_spent_seconds), 0)           AS avg_time_on_page_s,
    ROUND(AVG(mobility) * 100, 1)              AS avg_mobile_pct
FROM vw_page_base
WHERE bounce_rate IS NOT NULL   -- only rows with analytics data
GROUP BY position_bucket
ORDER BY position_bucket;


-- Q15: High-traffic, high-bounce pages — engagement red flags
-- These pages are winning clicks but losing users — a UX or content mismatch.
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    clicks,
    ROUND(position, 1)              AS position,
    ROUND(bounce_rate * 100, 1)     AS bounce_pct,
    ROUND(view_depth, 2)            AS view_depth,
    time_spent,
    word_count,
    response_time_flag
FROM vw_page_base
WHERE bounce_rate > 0.5
  AND clicks > 10
  AND bounce_rate IS NOT NULL
ORDER BY clicks DESC
LIMIT 20;


-- =============================================================================
-- SECTION 7 — DATA EXPORT QUERIES
-- Use these to export clean, analysis-ready datasets for Python and R.
-- =============================================================================

-- Q16: Full cleaned dataset export for Python EDA / ML modelling
-- Run: sqlite3 seo_portfolio.db ".mode csv" ".headers on"
--      ".output exports/clean_data.csv" ".read sql/03_analysis_queries.sql"
-- -----------------------------------------------------------------------
SELECT
    page_id,
    segment,
    clicks,
    impressions,
    position,
    ROUND(ctr, 4)                   AS ctr,
    bounce_rate,
    view_depth,
    time_spent_seconds,
    robots_visits,
    mobility,
    title_length,
    meta_description_length,
    h1_length,
    word_count,
    sentence_count,
    folder_depth,
    link_score,
    inlinks,
    outlinks,
    response_time,
    position_bucket,
    title_length_flag,
    meta_desc_flag,
    h1_flag,
    response_time_flag
FROM vw_page_base
ORDER BY clicks DESC;


-- Q17: Export for R regression analysis (numeric columns only, no nulls)
-- Feeds directly into the R statistical analysis Rmd.
-- -----------------------------------------------------------------------
SELECT
    clicks,
    impressions,
    position,
    ROUND(ctr, 4)                   AS ctr,
    bounce_rate,
    view_depth,
    robots_visits,
    mobility,
    title_length,
    meta_description_length,
    h1_length,
    word_count,
    sentence_count,
    folder_depth,
    link_score,
    inlinks,
    outlinks,
    response_time,
    segment
FROM vw_page_base
WHERE position        IS NOT NULL
  AND title_length    IS NOT NULL
  AND word_count      IS NOT NULL
  AND inlinks         IS NOT NULL
  AND response_time   IS NOT NULL
ORDER BY clicks DESC;
