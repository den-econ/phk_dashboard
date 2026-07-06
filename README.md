# PHK Early Warning Dashboard — data pipeline

Merges the two source workbooks (PHK Outlook + MAP composite) into clean,
analysis-ready datasets for monitoring layoff (PHK) pressure across Indonesian
provinces, using a **domain-based** column naming convention.

## Build (run from the repo ROOT, in order)

```bash
python code/build_crosswalk.py   # workbook -> data/processed/indicator_dictionary.csv (names + classification)
python code/gen_pipeline.py      # dictionary -> config/master_schema.yml + code/01_build_baseline_master.do
```
```stata
do code/01_build_baseline_master.do   # builds every dataset under data/processed/
```

Columns are renamed by **Excel position**, so re-run the two Python generators
whenever the workbook's columns change. (Requires Stata 14+, and `openpyxl`+`pyyaml`
for the generators.)

## Naming convention

The **column name says what the variable means**; **where it came from is metadata**
(`src_*` fields + the dictionary), never baked into the name.

- Domain prefixes: `phk_` (layoffs only), `lab_ wage_ bpjstk_ emp_ emp_share_ ind_
  macro_ price_ trade_ fin_ map_ geo_`; derived `growth_ lag1_ diff_`.
- Suffixes: `_pct _share _index _idr[_billion|_million] _usd_million _pp
  _yoy _mom _qoq _annual _quarterly _national`.
- `phk_*` is **not** used for macro/price/trade/finance series just because they
  live in the PHK workbook.

## Outputs (`data/processed/`)

| File | Grain | Notes |
| --- | --- | --- |
| `phk_master.csv` | province × month | Main panel; monthly direct, annual/quarterly/MAP repeated + flagged |
| `phk_monthly_features.csv` | province × month | Full native monthly set |
| `phk_quarterly_features.csv` | province × quarter | Full native quarterly set |
| `phk_annual_features.csv` | province × year | Full native annual set |
| `national_{monthly,quarterly,annual}.csv` | period | National indicators (identical across provinces) |
| `map_kabkot_context.csv` | kabupaten/kota | MAP structural data below province level |
| `indicator_dictionary.csv` | — | Complete source→final mapping + metadata for every column |
| `merge_issues.csv` | — | Province-years failing key/mapping checks |

## Coverage guarantee

Every source column in `Database (Bulan/Triwulan/Tahun)`, `phk`, `Kebutuhan Data`,
and `MAP_composite_all` is accounted for in `indicator_dictionary.csv` — either
`include_in_master`, in a `clean_feature_file`, or `excluded_from_master` with a
reason. Nothing is silently dropped.

## Key conventions

- **Coverage:** 2014-01 to 2025-12. MAP structural data 2014–2024 (2024 carried
  into 2025); PHK data 2022–2025, missing before 2022.
- **National indicators** are extracted to `national_*.csv` and kept **out** of the
  province master.
