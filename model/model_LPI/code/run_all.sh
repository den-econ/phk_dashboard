#!/usr/bin/env bash
# Full / ANNUAL LPI rebuild — re-fits pillars, recomputes weights, regenerates
# every output. Run from model/model_LPI/ :  bash code/run_all.sh
#
# PREREQUISITE: data/clean/phk_master.csv must be freshly rebuilt in Stata
# (code/01_build_phk_master.do) from the latest Google Sheet.
set -euo pipefail
cd "$(dirname "$0")/.."                       # -> model/model_LPI
PY="../../.venv/bin/python"                    # project venv (openpyxl)

echo "== 00 re-fit pillars (verify vs baseline) =="
Rscript code/00_fit_pillars.R                  # exits non-zero if it fails to reproduce the baseline
cp outputs/models_refit.rds outputs/models.rds # promote only if 00 passed (set -e stops on failure)

echo "== 02 LEI annual ==";          Rscript code/02_lei_annual.R
echo "== 03 weights + composite ==";  Rscript code/03_weights_composite.R
echo "== 01 pillar spec/scores ==";   Rscript code/01_pillar_pca.R
echo "== 04 HTML report ==";          Rscript code/04_report.R
echo "== 05 result tables ==";        Rscript code/05_export_results.R
echo "== 05b build xlsx ==";          "$PY" code/05b_build_xlsx.py
echo "== 06 dashboard handoff ==";    Rscript code/06_export_dashboard.R
echo "== 07 freeze calibration ==";   Rscript code/07_freeze_calibration.R
echo "== DONE =="
echo "   workbook : outputs/lpi_scores.xlsx"
echo "   dashboard: outputs/dashboard/lpi_data.js (annual), outputs/dashboard/lpi_monthly.js (after run_monthly.sh)"
