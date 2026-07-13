# PHK Early Warning Dashboard — data pipeline

Clean, province-month panel for monitoring layoff (PHK) pressure across Indonesian
provinces. The clean database is built from **one source only**:
`Data untuk PHK Dashboard.xlsx`. 

## Workflow

```text
raw data  →  cleaning script (Stata)  →  clean data  →  (data dictionary)  →  (dashboard data)
```

Everything is done in **Stata** (Stata 14+). Build the clean master:

```stata
do code/01_build_phk_master.do        // -> data/clean/phk_master.csv
```

## Main output — `data/clean/phk_master.csv`

- **Grain:** one row = province × month (identity keys: `province_name_std`, `province_code` [BPS 2-digit text], `year`, `month`, `date`, `quarter`)
- **Coverage:** 2022–2025 (38 provinces × 48 months = **1,824 rows**, 257 columns)
- **Source:** only `Data untuk PHK Dashboard.xlsx`, sheets `Database (Bulan / Triwulan / Tahun)`

Monthly variables enter directly; **quarterly** variables repeat across the 3 months of
their quarter; **annual** variables repeat across the 12 months of their year. PDRB is
elaborated into 17 sectors at both quarterly (`macro_pdrb_<sector>_q`) and annual
(`macro_pdrb_<sector>_y`) grain.

Every variable is documented in two places with **identical variable lists**:
- **`config/master_schema.yml`** — name, description, source (Bahasa) name, data_period, data_level, unit.
- **`dictionary/indicator_dictionary.csv`** — grouped by theme: `theme, variable,
  source_variable_name, data_level, data_period, source_data` (`source_data` is left blank
  for you to fill in). `data_period` lists every frequency an indicator appears at.

**Variable flags — `data/clean/phk_variable_flags.csv`** (one row per indicator, 251 rows):
1/0 flags for frequency (`data_bulanan`, `data_triwulan`, `data_tahunan`) and geographic
level (`data_provinsi`, `data_nasional`). Compact per-variable reference.

**Long / filterable master — `data/clean/phk_master_long.csv`** (457,824 rows = 1,824 ×
251 variables): the same data reshaped **long** (one row per province-month-**variable**),
carrying the 1/0 flags as **row** columns so you can filter directly:

```stata
import delimited "data/clean/phk_master_long.csv", clear varnames(1)
keep if data_triwulan==1     // quarterly variables only
keep if data_tahunan==1      // annual variables only
keep if data_nasional==1     // national variables only
```

Columns: `province_name_std, province_code, year, month, date, quarter, variable, value,
data_bulanan, data_triwulan, data_tahunan, data_provinsi, data_nasional`. Note: annual
values are repeated across the 12 months of their year and quarterly across 3 months (same
as the wide master); add `keep if month==1` (annual) or one month per quarter to de-duplicate.

### Reading the column names

Frequency and geographic level are encoded in the name (no separate flag columns needed):

| Encoding | Meaning |
| --- | --- |
| no suffix (e.g. `phk_stock`) | **monthly** variable |
| `_q` suffix (e.g. `macro_pdrb_svc_share_pct_q`) | **quarterly** variable |
| `_y` suffix (e.g. `lab_tpt_pct_y`) | **annual** variable |
| `_nat` in the name (e.g. `macro_bi_rate_pct_nat`) | **national** level (same across provinces) |
| otherwise | **province** level |

Columns are renamed by **Excel position**, using the
verified rename blocks inside `code/01_build_phk_master.do`. If the workbook's column
order changes, re-derive those `rename` lines. **Units are taken as-is from the workbook —
no conversion is applied.**

## Folder structure

```text
data/raw/        source workbook (+ map_composite_all.xlsx reference, lo.csv, geospatial)
data/clean/      phk_master.csv + phk_variable_flags.csv
code/            01_build_phk_master.do   (Stata build)
config/          master_schema.yml (variable descriptions), admin_mapping.yml, national_indicators.yml
dictionary/      indicator_dictionary.csv + naming notes
dashboard/       index.html, shock_simulation.html
model/model_LEI/ layoff pressure index (PCA) work + outputs
```
