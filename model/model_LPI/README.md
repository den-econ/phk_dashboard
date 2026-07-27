# model_LPI — Layoff Pressure Index (LPI)

Provincial **Layoff Pressure Index** for the PHK Early-Warning Dashboard. The LPI
combines three province-year indices into one early-warning score (0–100) per
province, using PCA pillars aggregated with the **OECD/JRC factor-analysis
weighting method** (Handbook on Constructing Composite Indicators, 2008, §6.1).

> **Recorded PHK is used only to *validate* the indices — never as an input.**

## The three pillars

| Pillar | Meaning | Source |
|---|---|---|
| **Indeks Kerentanan Pasar Kerja** (L9) | labour-market vulnerability — how formal / full-time / industrial the workforce is | `data/clean/phk_master.csv` |
| **Indeks Kerentanan Struktural Ekonomi** (E5) | economic-structure vulnerability — trade-integrated & industrial vs domestic & agrarian | `data/clean/phk_master.csv` |
| **Indeks Tekanan Makroekonomi** (LEI) | building macro/labour pressure over time | `../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx` |

Stage 1 = each pillar is a first-layer PCA (or the LEI). Stage 2 = a second PCA
over the three pillar scores derives the weights (see `docs/LPI_methodology.md`).

## Folder layout

```
model_LPI/
├── code/                     pipeline (run in numeric order; run_all.sh runs all)
│   ├── 01_pillar_pca.R           pillar spec + score export (see provenance note)
│   ├── 02_lei_annual.R           LEI monthly → annual (Tekanan pillar)  [verified]
│   ├── 03_weights_composite.R    OECD weights + composite LPI
│   ├── 04_report.R               builds docs/lpi_structure_report.html
│   ├── 05_export_results.R       tidy result tables (CSV parts)
│   ├── 05b_build_xlsx.py         packages → outputs/lpi_scores.xlsx (needs .venv)
│   ├── 06_export_dashboard.R     → outputs/dashboard/lpi_data.js
│   └── run_all.sh                runs the whole pipeline
├── outputs/
│   ├── models.rds                ⭐ validated pillar fits (authoritative — see note)
│   ├── lpi_scores.xlsx           ⭐ canonical results workbook (for humans/records)
│   ├── lpi_scores_long.csv       province-year: 3 pillars + LPI + rank + tier
│   ├── lpi_weights_by_year.csv, pillar_loadings.csv, pillar_metrics.csv, …
│   └── dashboard/lpi_data.js     ⭐ dashboard handoff (window.LPI_DATA)
├── assets/report.css             report styling
├── docs/
│   ├── LPI_methodology.md         method write-up
│   └── lpi_structure_report.html  generated results/methodology report
└── LPI_Labor_Market_Structure/   ⚠ SUPERSEDED earlier single-year (2023) approach
```

## How to run

```bash
cd model/model_LPI
bash code/run_all.sh          # 02 → 03 → 01 → 04 → 05 → 05b → 06
```

Requires R (`readxl`, `base64enc`, `jsonlite`) and the project `.venv` (for
`openpyxl`, used only to package the `.xlsx`).

## Using the results in the dashboard

The dashboard HTML is opened via `file://` and embeds all data as JavaScript —
it cannot `fetch()` a local CSV. So the model hands off a JS file the dashboard
includes once:

```html
<script src="../model/model_LPI/outputs/dashboard/lpi_data.js"></script>
<!-- then read window.LPI_DATA (meta, weights[year], scores[]) in the chart code -->
```

Regenerating the LPI never requires editing the (minified) dashboard HTML — just
re-run the pipeline and the `lpi_data.js` is refreshed.

## Provenance note (important)

`outputs/models.rds` holds the **validated, published** pillar PCA fits (L9, E5).
The original interactive fitting script was not preserved, so `01_pillar_pca.R`
does **not** re-fit the pillars from `phk_master.csv`; it documents the
specification and re-exports the validated scores. Everything downstream
(`02`–`06`) is fully reproducible and was verified to reproduce the published
numbers (e.g. 2025 weights 26.3 / 33.2 / 40.6; Kepulauan Riau LPI = 100,
Aceh = 0). `02_lei_annual.R` **is** re-derived from the LEI workbook and verified
to match the persisted values exactly.
