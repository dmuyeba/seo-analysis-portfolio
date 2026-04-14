"""
SEO Analytics Portfolio | Daniel Muyeba
=======================================
scripts/load_data.py

Loads the raw CSV into a local SQLite database, applying all type coercions
that the raw source requires (comma-as-decimal separator, HH:MM:SS strings, etc.).
Run this once after cloning the repo to initialise the database.

Usage:
    python scripts/load_data.py

Requirements:
    pip install pandas
    (sqlite3 is part of the Python standard library)

Output:
    seo_portfolio.db  — SQLite database file in the repo root
"""

import sqlite3
import pandas as pd
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT  = Path(__file__).resolve().parent.parent
DATA_PATH  = REPO_ROOT / "data" / "data.csv"
DB_PATH    = REPO_ROOT / "seo_portfolio.db"
SCHEMA_SQL = REPO_ROOT / "sql" / "01_schema.sql"
VIEWS_SQL  = REPO_ROOT / "sql" / "02_views.sql"

# ---------------------------------------------------------------------------
# Load & clean
# ---------------------------------------------------------------------------
print(f"Loading data from {DATA_PATH} ...")

df = pd.read_csv(DATA_PATH, sep=";")

# Columns that use a comma as a decimal separator (European locale export)
comma_decimal_cols = ["Position", "BounceRate", "ViewDepth", "Mobility", "Response Time"]
for col in comma_decimal_cols:
    df[col] = (
        df[col]
        .astype(str)
        .str.replace(",", ".", regex=False)
        .pipe(pd.to_numeric, errors="coerce")
    )

# Rename columns to match the snake_case schema
df = df.rename(columns={
    "Clicks":                   "clicks",
    "Impressions":              "impressions",
    "Position":                 "position",
    "BounceRate":               "bounce_rate",
    "ViewDepth":                "view_depth",
    "TimeSpent":                "time_spent",
    "RobotsVisits":             "robots_visits",
    "Mobility":                 "mobility",
    "Segments":                 "segment",
    "Title Length":             "title_length",
    "Meta Description Length":  "meta_description_length",
    "H1 Length":                "h1_length",
    "Word Count":               "word_count",
    "Sentence Count":           "sentence_count",
    "Folder Depth":             "folder_depth",
    "Link Score":               "link_score",
    "Inlinks":                  "inlinks",
    "Outlinks":                 "outlinks",
    "Response Time":            "response_time",
})

# Coerce integer-typed columns (may have arrived as float due to NaN rows)
int_cols = ["clicks", "impressions", "robots_visits",
            "title_length", "meta_description_length", "h1_length",
            "word_count", "sentence_count", "folder_depth", "inlinks", "outlinks"]
for col in int_cols:
    df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")

print(f"  Rows loaded : {len(df):,}")
print(f"  Columns     : {list(df.columns)}")
print(f"  Null counts :\n{df.isnull().sum()}\n")

# ---------------------------------------------------------------------------
# Write to SQLite
# ---------------------------------------------------------------------------
print(f"Writing to {DB_PATH} ...")

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# Apply schema (creates table + indexes)
with open(SCHEMA_SQL) as f:
    cursor.executescript(f.read())

# Insert data — if_exists='append' respects the schema constraints
df.to_sql(
    "stg_page_performance",
    conn,
    if_exists="append",
    index=True,           # page_id = DataFrame index (0-based)
    index_label="page_id",
)

# Apply views
with open(VIEWS_SQL) as f:
    cursor.executescript(f.read())

conn.commit()

# Quick sanity check
row_count = cursor.execute("SELECT COUNT(*) FROM stg_page_performance").fetchone()[0]
print(f"  Rows in database : {row_count:,}")

seg_counts = cursor.execute(
    "SELECT segment, COUNT(*) FROM stg_page_performance GROUP BY segment"
).fetchall()
print("  Rows by segment  :")
for seg, count in seg_counts:
    print(f"    {seg or 'NULL':<15} {count:,}")

conn.close()
print("\nDone. Database ready at:", DB_PATH)
print("Run SQL queries with: sqlite3 seo_portfolio.db")
