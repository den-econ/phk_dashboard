# PHK Early Warning Dashboard — data pipeline

Clean, province-month panel for monitoring layoff (PHK) pressure across Indonesian
provinces. The clean database is built from **one source only**:
`Data untuk PHK Dashboard.xlsx`. MAP is **not** merged (see "MAP" below).

## Workflow

```text
raw data  →  cleaning script (Stata)  →  clean data  →  (data dictionary)  →  (dashboard data)
```

Everything is done in **Stata** (Stata 14+). Build the clean master:

```stata
do code/01_build_phk_master.do        // -> data/clean/phk_master.csv
```

The dictionary and dashboard-export steps are not built yet (kept minimal for now).

## Main output — `data/clean/phk_master.csv`

- **Grain:** one row = province × month
- **Coverage:** 2022–2025 (38 provinces × 48 months = **1,824 rows**, 226 columns)
- **Source:** only `Data untuk PHK Dashboard.xlsx`, sheets `Database (Bulan / Triwulan / Tahun)`

Monthly variables enter directly; **quarterly** variables repeat across the 3 months of
their quarter; **annual** variables repeat across the 12 months of their year.

Every variable is described in **`config/master_schema.yml`** (name, description, original
Bahasa name, frequency, level, unit).

### Reading the column names

Frequency and geographic level are encoded in the name (no separate flag columns needed):

| Encoding | Meaning |
| --- | --- |
| no suffix (e.g. `phk_stock`) | **monthly** variable |
| `_q` suffix (e.g. `macro_pdrb_svc_share_pct_q`) | **quarterly** variable |
| `_y` suffix (e.g. `lab_tpt_pct_y`) | **annual** variable |
| `_nat` in the name (e.g. `macro_bi_rate_pct_nat`) | **national** level (same across provinces) |
| otherwise | **province** level |

Columns are renamed by **Excel position** (the workbook headers are messy), using the
verified rename blocks inside `code/01_build_phk_master.do`. If the workbook's column
order changes, update those `rename` lines. Two unit fixes are applied so values match
their names: sector shares `emp_share_*` ×100 (stored as fractions) and `wage_ump_idr_y`
×1000 (stored in thousand-IDR).

## MAP

`MAP_composite_all.xlsx` is kept in `data/raw/` as **reference only** and is not part of
the clean database. Identifying which PHK variables overlap with MAP is a later,
dictionary-only step. All previous MAP-merged outputs are quarantined in
`data/archive/old_merged_with_map/`.

## Folder structure

```text
data/raw/        source workbooks + references (immutable)
data/clean/      phk_master.csv  (the clean panel)
data/archive/    old MAP-merged outputs (quarantined, not used)
code/            01_build_phk_master.do   (Stata build)
config/          master_schema.yml (variable descriptions), admin_mapping.yml, national_indicators.yml
dictionary/      data dictionary + naming notes
dashboard/       index.html, shock_simulation.html
model/           layoff pressure index (PCA) work + outputs
sources/         raw source docs to add manually (sakernas/kemnaker/bps/bpjstk/…)
legacy/          old scripts + old outputs (superseded, kept for reference)
```

## Sources folder

`sources/` is where you manually drop the underlying source documents (Sakernas,
Kemnaker, BPS, BPJSTK publications/PDFs). Nothing reads from it yet — it exists so each
number in the workbook can later be traced back to its published table.
