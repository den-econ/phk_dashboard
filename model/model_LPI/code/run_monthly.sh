#!/usr/bin/env bash
# ============================================================================
# MONTHLY LPI UPDATE — the only command you run each month.
#   bash code/run_monthly.sh
#
# It refreshes outputs/lpi_scores.xlsx (annual sheets + a `monthly` sheet with
# the newest LPI + macro-pressure per province). Each year's rows use that year's
# own weights + structure (the current year without annual data yet uses the
# latest available year); only the new month's LEI moves things.
#
# BEFORE running this, each month:
#   1. Update the newest month in the Google Sheet; download to Excel.
#   2. Run the LEI R code so Komposit_LEI_Ketenagakerjaan.xlsx has the new month.
# (No Stata / no phk_master rebuild needed monthly — that is only for the yearly
#  re-calibration via run_all.sh when new annual data is released.)
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."                       # -> model/model_LPI
PY="../../.venv/bin/python"

echo "== annual result tables (from frozen 2025 baseline) =="; Rscript code/05_export_results.R
echo "== monthly LPI scoring (newest LEI) ==";                 Rscript code/08_score_monthly.R
echo "== build lpi_scores.xlsx (annual + monthly sheets) ==";  "$PY" code/05b_build_xlsx.py
echo "== DONE ==  ->  hand outputs/lpi_scores.xlsx to the dashboard team"
