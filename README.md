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
- **Coverage:** 2022–2026 (38 provinces × 60 months = **2,280 rows**, 290 columns). Monthly
  2026 data currently runs through ~July (Aug–Dec present as empty rows); Triwulan/Tahun 2026
  are not yet in the workbook, so **all `_q` and `_y` columns are missing for 2026**.
- **Source:** only `Data untuk PHK Dashboard.xlsx`, sheets `Database (Bulan / Triwulan / Tahun)`

Monthly variables enter directly; **quarterly** variables repeat across the 3 months of
their quarter; **annual** variables repeat across the 12 months of their year. PDRB is
elaborated into 17 sectors at both quarterly (`macro_pdrb_<sector>_q`) and annual
(`macro_pdrb_<sector>_y`) grain.

**Derived macro-trigger transforms** (computed by the build, not entered in raw): %yoy
growth for Brent (`growth_brent_yoy_pct_nat`), wholesale IHPB (`growth_ihpb_yoy_pct_nat`),
NPL (`growth_npl_yoy_pct`), and export/import at monthly (`growth_export_yoy_pct`,
`growth_import_yoy_pct`) and quarterly (`growth_export_yoy_pct_q`, `growth_import_yoy_pct_q`)
grain; IDR/USD annual volatility (`macro_fx_vol_sd_nat_y` = SD of the 12 monthly rates per
year); and the year-on-year **percentage-point change** of each of the 17 employment shares
(`emp_share_<sector>_ppt_chg_y`). yoy needs the prior year, so these are **missing in 2022**
and start 2023 (FX volatility starts 2022). CPI %yoy already exists as `price_inflation_yoy_pct`.

Every variable is documented in two places with **identical variable lists**:
- **`config/master_schema.yml`** — name, description, source (Bahasa) name, data_period, data_level, unit.
- **`dictionary/indicator_dictionary.csv`** — grouped by theme: `theme, variable,
  source_variable_name, data_level, data_period, source_data` (`source_data` is left blank
  for you to fill in). `data_period` lists every frequency an indicator appears at.

**Variable flags — `data/clean/phk_variable_flags.csv`** (one row per indicator, 284 rows):
1/0 flags for frequency (`data_bulanan`, `data_triwulan`, `data_tahunan`) and geographic
level (`data_provinsi`, `data_nasional`). Compact per-variable reference.

> **Using the data by frequency / level** (column-select recipes) is documented in
> **`dictionary/data_dictionary.md`** and below.

### Reading the column names

Frequency and geographic level are encoded in the name (no separate flag columns needed):

| Encoding | Meaning |
| --- | --- |
| no suffix (e.g. `phk_stock`) | **monthly** variable |
| `_q` suffix (e.g. `macro_pdrb_svc_share_pct_q`) | **quarterly** variable |
| `_y` suffix (e.g. `lab_tpt_pct_y`) | **annual** variable |
| `_nat` in the name (e.g. `macro_bi_rate_pct_nat`) | **national** level (same across provinces) |
| otherwise | **province** level |

### Filtering `phk_master.csv` by type (column-select)

In the **wide** master a row is a province-month, so you pick a data type by **selecting
columns** (not `keep if`). The type is in the column name:

```stata
import delimited "data/clean/phk_master.csv", clear varnames(1)

* MONTHLY variables only (drop quarterly + annual):
ds *_q *_y
drop `r(varlist)'

* QUARTERLY variables only:
keep province_name_std province_code year month date quarter *_q

* ANNUAL variables only:
keep province_name_std province_code year *_y

* NATIONAL variables only (any frequency):
keep province_name_std province_code year month date quarter *nat*

* PROVINCIAL variables only (drop national):
ds *nat*
drop `r(varlist)'
```

Annual/quarterly values are broadcast across months, so after `keep ... *_y` add
`keep if month==1` (then `duplicates drop`) for one row per province-year; for `*_q`
keep one month per quarter (`keep if inlist(month,1,4,7,10)`).

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
