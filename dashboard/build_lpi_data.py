#!/usr/bin/env python3
"""
build_lpi_data.py — regenerate dashboard_lpi_monthly_data.js (window.LPI_DATA)
from the current model_LPI/outputs/lpi_scores.xlsx.

Run from dashboard/:  ../.venv/bin/python build_lpi_data.py
The dashboard HTML loads window.LPI_DATA from the emitted file, so refreshing the
LPI (and its Struktural component) is just: rebuild lpi_scores.xlsx -> run this.
"""
import json, openpyxl

XLSX = "../model/model_LPI/outputs/lpi_scores.xlsx"
OUT  = "dashboard_lpi_monthly_data.js"
BULAN = {1:"Januari",2:"Februari",3:"Maret",4:"April",5:"Mei",6:"Juni",
         7:"Juli",8:"Agustus",9:"September",10:"Oktober",11:"November",12:"Desember"}

def num(v):  # keep 1-decimal floats; drop trailing .0 to whole numbers (matches prior file)
    if isinstance(v,(int,float)):
        return int(v) if float(v).is_integer() else round(float(v),1)
    return v

wb = openpyxl.load_workbook(XLSX, data_only=True)

# ---- weights sheet -> {year: {pasar_kerja, struktural, tekanan}} ----
ws = wb["weights"]; rows = list(ws.iter_rows(values_only=True)); h = list(rows[0]); c = h.index
weights = {}
for r in rows[1:]:
    if r[c("year")] is None: continue
    weights[str(int(r[c("year")]))] = {
        "pasar_kerja": num(r[c("Labour")]),
        "struktural":  num(r[c("Econ")]),
        "tekanan":     num(r[c("Pressure")]),
    }

# ---- monthly sheet -> scores[] (map xlsx column names to the dashboard's fields) ----
ws = wb["monthly"]; rows = list(ws.iter_rows(values_only=True)); h = list(rows[0]); c = h.index
scores = []
for r in rows[1:]:
    if r[c("year")] is None: continue
    scores.append({
        "year": int(r[c("year")]), "month": int(r[c("month")]), "province": r[c("province")],
        "lpi": num(r[c("lpi_score")]), "pasar_kerja": num(r[c("pasar_kerja_score")]),
        "struktural": num(r[c("struktural_score")]), "tekanan": num(r[c("tekanan_score")]),
        "rank": int(r[c("lpi_rank")]), "tier": int(r[c("tier")]),
        "tier_label": r[c("lpi_tier_label")], "lpi_tier_label": r[c("lpi_tier_label")],
        "pasar_kerja_tier_label": r[c("pasar_kerja_tier_label")],
        "struktural_tier_label":  r[c("struktural_tier_label")],
        "tekanan_tier_label":     r[c("tekanan_tier_label")],
        "avg_lpi_tier_pasar_kerja": num(r[c("avg_lpi_tier_pasar_kerja")]),
        "avg_lpi_tier_struktural":  num(r[c("avg_lpi_tier_struktural")]),
    })

# ---- years present in scores but not in weights (e.g. 2026) fall back to latest available ----
avail = sorted(int(y) for y in weights)
for s in scores:
    ys = str(s["year"])
    if ys not in weights:
        weights[ys] = weights[str(max(avail))]
weights = {y: weights[y] for y in sorted(weights, key=int)}   # keep years ordered

ymax = max((s["year"], s["month"]) for s in scores)
data = {
    "meta": {"source": "lpi_scores.xlsx / monthly", "latest_year": ymax[0],
             "latest_month": ymax[1], "latest_label": f"{BULAN[ymax[1]]} {ymax[0]}"},
    "weights": weights,
    "scores": scores,
}
with open(OUT, "w", encoding="utf-8") as f:
    f.write("window.LPI_DATA = " + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + ";")
print(f"wrote {OUT}: {len(scores)} score rows, latest {data['meta']['latest_label']}, weight years {list(weights)}")
