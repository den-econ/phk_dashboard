#!/usr/bin/env bash
# ============================================================================
# YEARLY / FULL LPI REBUILD — run once when new ANNUAL data is released.
#   bash code/run_all.sh
#
# Re-fits the pillars, recomputes the per-year weights, scores the months, and
# rebuilds every output including outputs/lpi_scores.xlsx (annual + monthly).
# New years are picked up automatically — no manual base-year setting.
#
# PREREQUISITE: data/clean/phk_master.csv must be freshly rebuilt in Stata
# (code/01_build_phk_master.do) from the latest Google Sheet.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."                       # -> model/model_LPI
PY="../../.venv/bin/python"

echo "== 00 re-fit pillars (verify vs baseline) =="
Rscript code/00_fit_pillars.R
cp outputs/models_refit.rds outputs/models.rds   # promote only if 00 passed (set -e)

echo "== 02 LEI annual ==";           Rscript code/02_lei_annual.R
echo "== 03 weights + composite ==";  Rscript code/03_weights_composite.R
echo "== 04 HTML report / artifact =="; Rscript code/04_report.R
echo "== 05 annual result tables ==";  Rscript code/05_export_results.R
echo "== 08 monthly LPI scoring ==";   Rscript code/08_score_monthly.R
echo "== build lpi_scores.xlsx ==";    "$PY" code/05b_build_xlsx.py
echo "== DONE ==  ->  outputs/lpi_scores.xlsx (deliverable)"
