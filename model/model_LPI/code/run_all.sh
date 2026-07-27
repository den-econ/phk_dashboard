#!/usr/bin/env bash
# Build the whole LPI pipeline. Run from model/model_LPI/ :  bash code/run_all.sh
set -euo pipefail
cd "$(dirname "$0")/.."                       # -> model/model_LPI
PY="../../.venv/bin/python"                    # project venv (openpyxl)

echo "== 02 LEI annual ==";        Rscript code/02_lei_annual.R
echo "== 03 weights + composite =="; Rscript code/03_weights_composite.R
echo "== 01 pillar spec/scores =="; Rscript code/01_pillar_pca.R
echo "== 04 HTML report ==";       Rscript code/04_report.R
echo "== 05 result tables ==";     Rscript code/05_export_results.R
echo "== 05b build xlsx ==";       "$PY" code/05b_build_xlsx.py
echo "== 06 dashboard handoff =="; Rscript code/06_export_dashboard.R
echo "== DONE =="
