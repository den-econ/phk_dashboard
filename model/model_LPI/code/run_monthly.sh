#!/usr/bin/env bash
# Monthly LPI update (pressure only; structure + weights frozen at base year).
# Run from model/model_LPI/ :  bash code/run_monthly.sh
#
# PREREQUISITES each month (done upstream, not by this script):
#   1. Enter the new month in the Google Sheet (Database Bulan / Bulan, Nasional).
#   2. Rebuild data/clean/phk_master.csv in Stata (code/01_build_phk_master.do).
#   3. Rebuild the LEI so Komposit_LEI_Ketenagakerjaan.xlsx has the new month.
#   (The base-year calibration from 07_freeze_calibration.R must already exist.)
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== 08 monthly LPI scoring =="; Rscript code/08_score_monthly.R
echo "== DONE == -> outputs/lpi_monthly.csv , outputs/dashboard/lpi_monthly.js"
