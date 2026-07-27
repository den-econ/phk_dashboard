# model_LPI — Layoff Pressure Index (LPI)

Provincial **Layoff Pressure Index** for the PHK Early-Warning Dashboard: one
early-warning score (0–100) per province, combining three indices with the
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

**How the score is built (per year):** each pillar is scored **0–100 within its
own index** (PCA → min-max). A 2-factor PCA over the three pillars derives
**data-driven weights** (varimax-rotated; a pillar's weight = its squared-loading
share within its factor × that factor's variance share). The LPI is then the
**plain weighted sum of the three 0–100 pillar scores** — since the inputs are
0–100 and the weights sum to 100%, the LPI is itself 0–100, with no further
standardisation (higher = more layoff pressure). Recent weights ≈ **30 / 32 / 38**
(Pasar Kerja / Struktural / Tekanan). Full method: [docs/LPI_methodology.md](docs/LPI_methodology.md).

**Two things to remember:**
- The 0–100 score is a **within-year measure**, not a cross-year level.
- Provinces are grouped into **4 equal-count risk tiers** (Risiko Sangat Tinggi → Rendah).

---

## 2. The two cadences (the key mental model)

The pillars update at different speeds, so there are **two update rhythms**:

| | **Monthly** | **Annual (re-calibration)** |
|---|---|---|
| What's new | new month of **pressure (LEI)** only | new year of **labour + structure** data |
| Structure pillars | **frozen** at base year | **re-fit** |
| Weights | **frozen** at base year | **recomputed** |
| Script | `run_monthly.sh` | `run_all.sh` |
| Output | `lpi_monthly.*` | everything (incl. `lpi_scores.xlsx`) |

Because structure + weights are frozen monthly, only the pressure input moves —
so monthly scores stay comparable month to month.

---

## 3. RUNBOOKS — what the team does

> **Prerequisite for both:** the Google Sheet is the single source of truth. After
> editing it, **rebuild `data/clean/phk_master.csv` in Stata** by running
> `code/01_build_phk_master.do`. Everything below reads from `phk_master.csv`.
> (Stata is required for that one step; the LPI scripts are R + a little Python.)

### 🅐 When NEW ANNUAL data is released (e.g. 2026 labour/structure)

1. Enter the 2026 annual data in the Google Sheet (*Database (Tahun)* tabs).
2. **Rebuild** `phk_master.csv` in Stata (`01_build_phk_master.do`).
3. Set the new base year: edit `BASE <- 2026` at the top of `code/07_freeze_calibration.R`
   **and** `code/08_score_monthly.R`.
4. Run the full pipeline:
   ```bash
   cd model/model_LPI
   bash code/run_all.sh
   ```
   This re-fits both pillars, recomputes the weights, refreezes the calibration,
   and regenerates all outputs. `00_fit_pillars.R` verifies the historical years
   still reproduce the validated baseline — if a prior year was revised upstream,
   it stops and reports (intended safety check).

### 🅑 When NEW MONTHLY data is released (e.g. July 2026)

1. Enter the month in the Google Sheet (*Database (Bulan)* and *Database (Bulan, Nasional)*, incl. `Penjualan Mobil`).
2. **Rebuild** `phk_master.csv` in Stata.
3. **Rebuild the LEI** so `model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx` includes the new month (LEI team; see [../model_LEI/LEI_to_phk_master_mapping.md](../model_LEI/LEI_to_phk_master_mapping.md)).
4. Run the monthly update:
   ```bash
   cd model/model_LPI
   bash code/run_monthly.sh
   ```
   Structure pillars and weights stay frozen; only the pressure pillar updates.

### 🅒 Who runs what — quick reference

| Person | Does | Runs |
|---|---|---|
| Data updater | enters data monthly/annually | the Google Sheet |
| Build owner | rebuilds the master table | `code/01_build_phk_master.do` (Stata) |
| LEI owner | rebuilds the pressure index | `model_LEI` → LEI workbook |
| LPI owner | produces the scores | `run_monthly.sh` (monthly) / `run_all.sh` (annual) |
| Dashboard owner | shows the scores | reads the JS handoff (below) |

---

## 4. Outputs — what feeds the dashboard, and where the Excel is

All under `model/model_LPI/outputs/`:

| File | What it is | For |
|---|---|---|
| **`lpi_scores.xlsx`** | ⭐ **canonical results workbook** — scores, weights, loadings, metrics (6 sheets) | **humans / records / sharing** |
| `lpi_scores_long.csv` | flat annual scores (province × year: 3 pillars, LPI, rank, tier) | analysts |
| `lpi_monthly.csv` | flat monthly scores (province × month, from `run_monthly.sh`) | analysts |
| **`dashboard/lpi_data.js`** | ⭐ **annual** handoff → `window.LPI_DATA` | **the dashboard** |
| **`dashboard/lpi_monthly.js`** | ⭐ **monthly** handoff → `window.LPI_MONTHLY` | **the dashboard** |

**Feeding the dashboard:** the dashboard is opened via `file://` and cannot fetch
a CSV/Excel at runtime — so it reads the **JS handoff files**, not the Excel.
Include once and read the global:
```html
<script src="../model/model_LPI/outputs/dashboard/lpi_data.js"></script>     <!-- annual -->
<script src="../model/model_LPI/outputs/dashboard/lpi_monthly.js"></script>  <!-- monthly -->
```
The **Excel (`lpi_scores.xlsx`) is the human-readable record** — open it, share it,
check numbers — while the **JS files are what the dashboard actually loads**. Both
are regenerated by the runbooks above, so they never drift apart.

---

## 5. Folder layout

```
model_LPI/
├── code/
│   ├── 00_fit_pillars.R        re-fit both pillars from phk_master (verified vs baseline)
│   ├── 01_pillar_pca.R         pillar spec + score export
│   ├── 02_lei_annual.R         LEI monthly → annual (pressure pillar)
│   ├── 03_weights_composite.R  OECD weights + annual composite
│   ├── 04_report.R             docs/lpi_structure_report.html
│   ├── 05_export_results.R + 05b_build_xlsx.py   → lpi_scores.xlsx + CSVs
│   ├── 06_export_dashboard.R   → dashboard/lpi_data.js (annual)
│   ├── 07_freeze_calibration.R freeze base-year weights/structure/scaling
│   ├── 08_score_monthly.R      → lpi_monthly.csv + dashboard/lpi_monthly.js
│   ├── run_all.sh              ANNUAL full rebuild
│   └── run_monthly.sh          MONTHLY update
├── outputs/                    results (see §4) + models.rds / models_frozen_2025.rds
├── assets/report.css
├── docs/                       LPI_methodology.md, lpi_structure_report.html
└── LPI_Labor_Market_Structure/ ⚠ SUPERSEDED earlier 2023 prototype
```

---

## 6. Reproducibility / provenance

- `00_fit_pillars.R` re-fits both pillars **from `phk_master.csv`** and is
  **verified field-for-field** against the validated baseline
  (`outputs/models_frozen_2025.rds`) for 2022–2025 — see `outputs/_refit_verification.txt`.
  It fits whatever years exist, so new years are picked up automatically.
- `run_all.sh` promotes the re-fit to `outputs/models.rds` **only if** verification passes.
- `02_lei_annual.R` and `08_score_monthly.R` also self-verify (LEI reproduces the
  persisted values; monthly machinery reproduces the base-year annual LPI exactly).
- `models_frozen_2025.rds` is the immutable validated baseline — do not edit.
