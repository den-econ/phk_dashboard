# model_LPI — Layoff Pressure Index (LPI)

Provincial **Layoff Pressure Index** for the PHK Early-Warning Dashboard: one
early-warning score per province, combining three indices with the
**OECD/JRC factor-analysis weighting method** (Handbook 2008, §6.1).

> **Recorded PHK is used only to *validate* the indices — never as an input.**

---

## 1. What the LPI is (the essentials)

**Three pillars**, combined into one score:

| Pillar | Meaning | Frequency | Source |
|---|---|---|---|
| **Indeks Kerentanan Pasar Kerja** | labour-market vulnerability (formal / full-time / industrial workforce) | annual | `phk_master.csv` |
| **Indeks Kerentanan Struktural Ekonomi** | economic-structure vulnerability (trade-integrated & industrial vs domestic & agrarian) | annual | `phk_master.csv` |
| **Indeks Tekanan Makroekonomi** | building macro pressure over time (the LEI) | monthly | `model_LEI` LEI workbook |

**How the score is built:** each pillar is scored **0–100 by min-max across
provinces** — the structural pillars within the year, the pressure pillar within
each month (same standardisation, applied at each pillar's grain). A 2-factor PCA
over the three pillars derives **data-driven weights** (varimax-rotated; a
pillar's weight = its squared-loading share within its factor × that factor's
variance share). The **LPI is the weighted sum of the three pillar scores** —
*not* separately re-normalised — and since the inputs are 0–100 with weights
summing to 100%, the LPI also sits in **0–100** (higher = more layoff pressure).
Recent weights ≈ **30 / 32 / 38** (Pasar Kerja / Struktural / Tekanan). Full
method: [docs/LPI_methodology.md](docs/LPI_methodology.md).

**Two things to remember:**
- The LPI is a **within-year measure**, not a cross-year level.
- Provinces are grouped into **4 equal-count risk tiers** (Risiko Sangat Tinggi → Rendah).

---

## 2. The two cadences (the key mental model)

The pillars update at different speeds, so there are **two update rhythms**:

| | **Monthly** | **Annual (re-calibration)** |
|---|---|---|
| What's new | new month of **pressure (LEI)** only | new year of **labour + structure** data |
| Structure pillars | that year's own (held across its months) | **re-fit** for the new year |
| Weights | that year's own | **recomputed** for the new year |
| Script | `run_monthly.sh` | `run_all.sh` |
| Needs Stata? | no | yes (rebuild `phk_master.csv`) |
| Output | `lpi_scores.xlsx` (refreshes the `monthly` sheet) | `lpi_scores.xlsx` (all sheets) |

Each year's monthly rows use **that year's own** weights and structure; only the
pressure input moves month to month. A year with no annual data yet (e.g. 2026
before its labour/structure lands) automatically uses the **latest available
year's** calibration (2025), then switches to its own once that data is built.

---

## 3. RUNBOOKS — what the team does

> **Single source of truth:** the Google Sheet. The **annual** rebuild regenerates
> `data/clean/phk_master.csv` in Stata (`code/01_build_phk_master.do`); the
> **monthly** update does **not** need Stata — it only needs the refreshed LEI
> workbook. The LPI scripts themselves are R + a little Python.

### 🅐 When NEW ANNUAL data is released (e.g. 2026 labour/structure)

1. Enter the 2026 annual data in the Google Sheet (*Database (Tahun)* tabs).
2. **Rebuild** `phk_master.csv` in Stata (`01_build_phk_master.do`).
3. Run the full pipeline:
   ```bash
   cd model/model_LPI
   bash code/run_all.sh
   ```
   This re-fits both pillars, recomputes the weights for **all** years (2026
   included), and regenerates all outputs. 2026 monthly rows then automatically
   switch from the 2025 fallback to 2026's own calibration — no manual setting.
   `00_fit_pillars.R` verifies the historical years still reproduce the validated
   baseline — if a prior year was revised upstream, it stops and reports.

### 🅑 When NEW MONTHLY data is released (e.g. July 2026)

**No Stata, no `phk_master` rebuild needed** — the year's weights and structure
are already set; only the new month's LEI moves. Just three steps:

1. Enter the month in the Google Sheet (*Database (Bulan)* + *Database (Bulan, Nasional)*, incl. `Penjualan Mobil`); download to Excel.
2. **Rebuild the LEI** so `model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx` has the new month.
3. Run the single monthly command:
   ```bash
   cd model/model_LPI
   bash code/run_monthly.sh
   ```
   → refreshes **`outputs/lpi_scores.xlsx`** (the `monthly` sheet gets the newest
   LPI + macro-pressure per province). Hand that file to the dashboard team.

### 🅒 Who runs what — quick reference

| Person | Does | Runs |
|---|---|---|
| Data updater | enters data monthly/annually | the Google Sheet |
| LEI owner | rebuilds the pressure index | `model_LEI` → LEI workbook |
| LPI owner | produces the scores | **`run_monthly.sh`** (monthly) / `run_all.sh` (annual) |
| Build owner | rebuilds the master table (annual only) | `code/01_build_phk_master.do` (Stata) |
| Dashboard owner | shows the scores | reads **`lpi_scores.xlsx`** |

---

## 4. Outputs — the one file the dashboard uses

The single deliverable is **`outputs/lpi_scores.xlsx`**. The dashboard team reads it:

| Sheet | Contents | Use |
|---|---|---|
| **`scores`** | annual province × year | annual view |
| **`monthly`** | province × month (ranked within each month) | monthly view |
| `weights`, `pillar_metrics`, `pillar_loadings`, `stage2_2025`, `README` | supporting detail | reference |

Both `scores` and `monthly` share the same columns: **`lpi_score`** + the three
pillar scores (`pasar_kerja_score`, `struktural_score`, `tekanan_score`),
`lpi_rank`, `tier`, and a tier label per index (`lpi_tier_label`,
`pasar_kerja_tier_label`, `struktural_tier_label`, `tekanan_tier_label`) — plus
`avg_lpi_tier_pasar_kerja` / `avg_lpi_tier_struktural` (the mean LPI of the
provinces sharing that province's labor / econ category, within the period).

**The dashboard's score is the `lpi_score` column** (the weighted-sum LPI); macro
pressure is `tekanan_score`. Everything else in
`outputs/` is machinery: the five `.rds` files are the pipeline's frozen inputs;
the report PNGs and `_`-prefixed files are gitignored regenerable scratch. The
dashboard needs only `lpi_scores.xlsx`.

---

## 5. Folder layout

```
model_LPI/
├── code/
│   ├── 00_fit_pillars.R        re-fit both pillars from phk_master (verified vs baseline)
│   ├── 02_lei_annual.R         LEI monthly → annual (pressure pillar)
│   ├── 03_weights_composite.R  OECD weights + annual composite (weighted sum of 0-100)
│   ├── 04_report.R             docs/lpi_structure_report.html (the artifact page)
│   ├── 05_export_results.R      annual result tables (parts for the workbook)
│   ├── 05b_build_xlsx.py        packages parts → lpi_scores.xlsx (annual + monthly sheets)
│   ├── 08_score_monthly.R       monthly LPI (per-year calibration) → the workbook's monthly sheet
│   ├── run_all.sh              ← run once a YEAR (full re-calibration)
│   └── run_monthly.sh          ← run each MONTH (the only monthly command)
├── outputs/                    lpi_scores.xlsx (deliverable) + models*.rds / *.rds inputs
├── assets/report.css
└── docs/                       LPI_methodology.md, lpi_structure_report.html
```

---

## 6. Reproducibility / provenance

- `00_fit_pillars.R` re-fits both pillars **from `phk_master.csv`** and is
  **verified field-for-field** against the validated baseline
  (`outputs/models_frozen_2025.rds`) for 2022–2025 — see `outputs/_refit_verification.txt`.
  It fits whatever years exist, so new years are picked up automatically.
- `run_all.sh` promotes the re-fit to `outputs/models.rds` **only if** verification passes.
- `02_lei_annual.R` and `08_score_monthly.R` also self-verify (LEI reproduces the
  persisted values; feeding each year's annual-mean LEI reproduces that year's
  annual LPI exactly, so the monthly and annual grains stay consistent).
- `models_frozen_2025.rds` is the immutable validated baseline — do not edit.
