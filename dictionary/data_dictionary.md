# PHK Early Warning Dashboard, Data Dictionary (rebuilt)

Rebuilt directly from the actual columns of `Database (Tahun)`, `Database (Triwulan)`, and `Database (Bulan)` in **Data untuk PHK Outlook.xlsx**, the current canonical source. Metadata (R-squared, correlation direction, literature review, source institution) is carried over from `Kebutuhan Data` and `Kesimpulan Awal` wherever a real match exists. Standard economic indicators carry confirmed definitions.

The machine-readable version is `config/indicator_dictionary.csv`. This file is the human-readable companion.

## Why this was rebuilt

This dictionary is anchored to the data itself.

## Coverage summary

- Total indicators: **206** (monthly 15, quarterly 19, annual 172)
- With carried-over metadata: **94**
- Detected national (identical across provinces): **13**
- Detected provincial: **190**
- Empty in current data (no_data): **3**

## Data-quality flags that affect the LPI

**1. National indicators masquerading as provincial.** These are identical for every province in a given period and must not be read as provincial signal: PMI Manufaktur, BI Rate, Kurs, Brent oil, IHPB, and the producer-price-change columns. In the master they take a `_national` suffix. Three more (`ICOR`, annual `Perubahan harga konsumen (%)`, `IHP (2016=100)`) were auto-detected as national and are flagged for manual confirmation.

**2. Unit and scale conventions.** UMP in this sheet is in **thousand IDR** (MAP stores it in IDR, a factor of 1000). Sector employment shares are stored as **fractions** despite the `%` in the column name (MAP stores them as percent, a factor of 100). The dictionary records the intended unit per indicator.

**3. Correlation direction is provisional.** The `direction_risk` and `R-squared` values come from correlations computed on **levels, not first differences**, so they are trend-driven and marked provisional pending re-estimation on differences.

**4. Empty columns.** `IKK` (consumer confidence) and two contract-worker derivatives are entirely empty and carry `no_data`.

## Core indicators (confirmed definitions)

These are the standard, LPI-relevant indicators. Full metadata for all 206 is in the CSV.

| Indicator | Column | Frequency | Level | Unit | Dir | R2 | Source |
|---|---|---|---|---|---|---|---|
| Formal-sector worker share | `% Pekerja Formal` | annual | provincial | percent | + | 0.09 | Sakernas |
| Labor force participation rate (TPAK) | `% TPAK` | annual | provincial | percent | - | 0.02 | Sakernas |
| Open unemployment rate (TPT) | `% TPT` | annual | provincial | percent | + | 0.15 | Sakernas |
| Foreign direct investment | `FDI` | annual | provincial | IDR (check scale) | manual_review_required | - | CEIC |
| UMP growth | `Growth UMP` | annual | provincial | percent | + | 0.01 | Sakernas |
| Kaitz index | `Kaitz Index` | annual | provincial | ratio | - | 0.21 | Sakernas |
| Manufacturing share of GRDP | `Manufacturing Share` | annual | provincial | percent | manual_review_required | - | CEIC |
| Layoffs (annual count) | `PHK` | annual | provincial | count (persons) | manual_review_required | - | Satudata Kemnaker |
| Informal employment share | `Proporsi Lapangan Kerja Informal` | annual | provincial | percent | - | 0.07 | Sakernas |
| Provincial minimum wage (UMP) | `UMP (IDR)` | annual | provincial | thousand IDR | - | 0.01 | Sakernas |
| BI policy rate | `BI Rate` | monthly | national | percent | manual_review_required | - | BI |
| Brent crude price | `Harga Minyak Brent (USD/barrel)` | monthly | national | USD/barrel | manual_review_required | - | review |
| Consumer Price Index (CPI) | `IHK (2010=100)` | monthly | provincial | index | manual_review_required | - | BPS |
| Wholesale Price Index | `IHPB` | monthly | national | index | manual_review_required | - | review |
| Inflation, month-on-month | `Inflasi Bulanan (M-to-M)` | monthly | provincial | percent | manual_review_required | - | review |
| Inflation, year-on-year | `Inflasi Tahunan (Y-on-Y)` | monthly | provincial | percent | manual_review_required | - | BPS |
| Exchange rate | `Kurs` | monthly | national | IDR per USD | manual_review_required | - | BI |
| Non-performing loans | `NPL (IDR miliar)` | monthly | provincial | IDR billion | manual_review_required | - | review |
| Trade balance | `Neraca Perdagangan` | monthly | provincial | USD million | manual_review_required | - | BPS |
| Export value | `Nilai Ekspor` | monthly | provincial | USD million | manual_review_required | - | BPS |
| Import value | `Nilai Impor` | monthly | provincial | USD million | manual_review_required | - | BPS |
| Layoffs, period flow | `PHK (Flow)` | monthly | provincial | count (persons) | manual_review_required | - | review |
| Layoffs, cumulative stock | `PHK (Stock)` | monthly | provincial | count (persons) | manual_review_required | - | review |
| Manufacturing PMI (S&P Global) | `PMI Manufaktur S&P` | monthly | national | index | manual_review_required | - | review |
| Consumer Confidence Index | `IKK` | quarterly | no_data | index | manual_review_required | - | BI |
| Number of employed persons | `Jumlah Penduduk Bekerja` | quarterly | provincial | count (persons) | + | 0.44 | Sakernas |
| Gross Regional Domestic Product | `PDRB (IDR mn)` | quarterly | provincial | IDR million | manual_review_required | - | review |

## Derived indicator families (rule-based, see CSV for the full list)

- **base** (89): primary measured indicators
- **growth** (37): year-on-year growth or change of a base indicator
- **lagged** (9): 1-year lag of a base indicator (`Lag_1 ...`)
- **sector_emp_count** (17): employment count by 17 economic sectors
- **sector_emp_share** (17): employment share by sector, stored as a fraction
- **baseline_2019** (2): 2019 reference value and change-from-2019
- **ibs_survey** (35): BPS Industri Besar Sedang block (firms, output, value added, labor cost, productivity ratios)

## Update schedule

- PHK stock and flow: monthly, when new Kemnaker data arrives
- PMI, IHK and inflation, export and import, NPL, BI Rate, Kurs, Brent: monthly or on release
- Annual labor and structural indicators (TPT, TPAK, formal share, UMP, sectoral): annual
- MAP composite structural indicators: annual or irregular
- Quarterly indicators (PDRB, shares, FDI): quarterly

## Backlog: desired indicators not yet in the data

Preserved from `Kebutuhan Data` for the external-exposure and structural gap-filling work. Full list in `config/candidate_indicators_backlog.csv`.

| Candidate indicator | Source |
|---|---|
| PDRB per sektor | CEIC |
| Tabel input output (IO) | BPS |
| Jumlah Tenaga Kerja/Nilai Tambah  | Survei Industri, diolah |
| Nilai Tambah/Nilai Output | Survei Industri, diolah |
| Pertumbuhan Nilai Tambah | Survei Industri, diolah perubahan tahunan |
| Pertumbuhan Produktivitas Tenaga Kerja (Nilai Tambah) | Survei Industri, diolah perubahan tahunan |
| Capital/labor | Survei Industri, diolah perubahan tahunan |
| Pengeluaran konsumsi rumah tangga | Susenas |
| Population density | Susenas |
| Urbanization rate | Susenas |
| Poverty rate | Susenas |
| Inequality rate | Susenas |
| Data twitter lihat job posting  | Public sentiment |
| Penggunaan pegadaian | Pegadaian? |
| Penggunaan judol dan pinjol  | PPATK |

## Fields still needs review

- **27** non-standard base indicators need a one-line definition
- `used_in_dashboard` for every row (requires checking against the v5 dashboard)
- `expected_update_timing` (release calendar) per indicator group
- Confirmation of the three ambiguous national flags
