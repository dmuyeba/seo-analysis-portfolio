# SEO Analytics Portfolio — SQL Layer

**Daniel Muyeba** · [LinkedIn](https://www.linkedin.com/in/daniel-muyeba-60093285/)

---

## Overview

This folder contains the SQL data modelling layer for the SEO Analytics Portfolio project.
It demonstrates end-to-end SQL thinking: from raw data ingestion through curated transformation
views to analysis-ready query outputs.

The dataset covers **9,439 pages** from an e-commerce site, combining Google Search Console
performance signals (clicks, impressions, position) with on-page technical signals (response
time, word count, inlinks, meta lengths) and page-type taxonomy (product / catalog / brands).

---

## File Structure

```
sql/
├── 01_schema.sql          # Staging table definition with constraints and indexes
├── 02_views.sql           # Layered transformation views
└── 03_analysis_queries.sql # Standalone analytical queries for exploration and export

scripts/
└── load_data.py           # Python loader: CSV → SQLite (handles type coercion)

data/
└── data.csv               # Source data (semicolon-delimited)
```

---

## View Architecture

The views are built in layers so that any fix in an upstream view propagates automatically:

```
stg_page_performance          ← raw staging table
    └── vw_page_base          ← cleaned types, CTR, position buckets, quality flags
            ├── vw_quick_wins             ← CTR opportunity filter with uplift estimates
            ├── vw_segment_summary        ← segment-level KPI rollup
            ├── vw_position_distribution  ← SERP ranking distribution
            ├── vw_crawl_efficiency       ← crawl budget waste signals
            └── vw_content_health         ← on-page issue flags and issue counts
```

### `vw_page_base`
The foundation view. Handles all type cleaning (comma-as-decimal position values,
HH:MM:SS → seconds conversion), computes CTR, assigns position buckets, and derives
content quality flags (title length, meta description, H1 presence, response time tier).

### `vw_quick_wins`
Filters to pages in positions 4–20 with ≥100 impressions that are underperforming
vs. industry CTR benchmarks. Computes the estimated click uplift if each page reached
its benchmark CTR — a directly actionable metric for an SEO team.

### `vw_segment_summary`
Aggregate KPI rollup by page type. Produces the segment comparison table used in the
Python EDA and R statistical analysis notebooks.

### `vw_position_distribution`
SERP ranking distribution by segment and position bucket, with window functions to
compute each bucket's share of total clicks. Designed for bar/waterfall chart output.

### `vw_crawl_efficiency`
Flags pages consuming crawl budget disproportionate to their organic value. Classifies
pages as `efficient`, `inefficient`, `low_waste`, `high_waste`, or `not_crawled`.
Informs robots.txt and noindex strategy recommendations.

### `vw_content_health`
Produces an automated content audit across all crawled pages. Each page is assigned
flags for title length, meta description, H1 presence, content depth, internal linking,
and response time — plus a total `issue_count` for triage prioritisation.

---

## Quick Start

### Option A — SQLite (local, no setup required)

```bash
# 1. Install Python dependency
pip install pandas

# 2. Load data and initialise the database
python scripts/load_data.py

# 3. Open the database
sqlite3 seo_portfolio.db

# 4. Run any query from 03_analysis_queries.sql
sqlite> SELECT * FROM vw_segment_summary;
```

### Option B — PostgreSQL

```bash
# 1. Create database
createdb seo_portfolio

# 2. Apply schema and views
psql -d seo_portfolio -f sql/01_schema.sql
psql -d seo_portfolio -f sql/02_views.sql

# 3. Load data (update path as needed)
psql -d seo_portfolio -c "
  COPY stg_page_performance(clicks, impressions, position, bounce_rate,
    view_depth, time_spent, robots_visits, mobility, segment,
    title_length, meta_description_length, h1_length, word_count,
    sentence_count, folder_depth, link_score, inlinks, outlinks, response_time)
  FROM '/absolute/path/to/data/data.csv'
  WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '');
"
```

---

## Key Findings

| Finding | Detail |
|---|---|
| **54% of pages have zero clicks** | 5,121 pages are ranking but generating no traffic — crawl or content waste |
| **1,833 quick-win candidates** | Pages on page 1–2 with sufficient impressions but below-benchmark CTR |
| **Link score is the #1 click predictor** | Stronger correlation with clicks than position alone (r = 0.16) |
| **Product pages rank best** | Avg position 11.1 vs 17.1 for catalog, but with higher bounce rates (36%) |
| **Crawl budget mismatch** | High-ranking pages receive fewer robot visits than deep, zero-click pages |

---

## Design Decisions

**Why views instead of materialised tables?**
For a portfolio of this size, views are more appropriate — they stay in sync with
the underlying data automatically and make the transformation logic readable and auditable.
In a production environment with millions of rows, these would be migrated to
materialised views or dbt models with incremental refresh.

**Why SQLite as default?**
SQLite requires zero infrastructure, meaning anyone cloning this repo can run the
full SQL layer instantly with a single Python command. All SQL is ANSI-compatible
and runs on PostgreSQL without modification (noted exceptions: window functions
require PostgreSQL 8.4+ and SQLite 3.25+).

**Why semicolon-delimited CSV?**
The source data uses European locale formatting (semicolons as delimiters, commas
as decimal separators). The loader handles this explicitly and is documented inline.

---

## Next Steps in the Project

- **Python layer** (`python/`) — EDA, opportunity clustering (K-Means), and click prediction model (XGBoost)
- **R layer** (`r/`) — multiple regression analysis, ggplot2 visualisations, inferential statistics
