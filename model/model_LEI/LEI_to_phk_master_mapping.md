# LEI inputs → `phk_master.csv` mapping

Reference for repointing the LEI model to read from **`data/clean/phk_master.csv`**
(the single source of truth, built from `data_untuk_phk_dashboard` via
`code/01_build_phk_master.do`), replacing the hand-maintained `data_layoff.xlsx`.

**Grain of `phk_master.csv`:** province × month (annual/quarterly values are
repeated across the months of their period).
- For the **monthly** LEI (`data_layoff.xlsx` sheet *Bulanan*): read the monthly rows directly.
- For the **annual** LEI (sheet *Tahunan*): keep the `*_y` columns and de-duplicate to one row per `province × year`.

Identifier columns: `province_name_std`, `year`, `month`.

## Monthly (was sheet *Bulanan*)

| LEI variable | `phk_master.csv` column | level |
|---|---|---|
| Provinsi | `province_name_std` | — |
| Tahun / Bulan | `year` / `month` | — |
| PHK (Stock) | `phk_stock` | province |
| PMI Manufaktur S&P | `macro_pmi_manuf_nat` | national |
| IHK (2010=100) | `price_cpi_index` | province |
| Nilai Ekspor | `trade_export_value` | province |
| Nilai Impor | `trade_import_value` | province |
| NPL (IDR miliar) | `fin_npl_idr_billion` | province |
| BI Rate | `macro_bi_rate_pct_nat` | national |
| Kurs | `macro_fx_idr_usd_nat` | national |
| Harga Minyak Brent | `price_brent_usd_bbl_nat` | national |
| IHPB | `price_ihpb_nat` | national |
| Penjualan Mobil | `macro_car_sales_nat` | national — **new; requires a Stata rebuild (see below)** |
| Volatilitas Kurs | *derive* from `macro_fx_idr_usd_nat` | the build already has an annual SD, `macro_fx_vol_sd_nat_y`; compute monthly volatility as needed |

## Annual (was sheet *Tahunan*)

| LEI variable | `phk_master.csv` column | level |
|---|---|---|
| Provinsi / Tahun | `province_name_std` / `year` | — |
| PHK | `phk_y` | province |
| Jumlah Penduduk Bekerja | `lab_working_pop_y` | province |
| UMP (IDR) | `wage_ump_idr_y` | province |
| Growth UMP | `wage_ump_growth_pct_y` | province |
| Upah buruh/karyawan/pegawai (IDR) | `wage_avg_employee_idr_y` | province |
| Jumlah Tenaga Kerja Ind. Sedang | `ind_workers_medium_y` | province |
| PDRB Riil (IDR milyar) | `macro_pdrb_idr_billion_y` | province |
| FDI | `fin_fdi_y` | province |
| IHP (2016=100) | `price_producer_index_nat_y` | national |
| IHK (2010=100) | `price_cpi_index_nat_y` | national |
| Nilai Ekspor | `trade_export_value_y` | province |
| Nilai Impor | `trade_import_value_y` | province |
| NPL | `fin_npl_y` | province |
| BI Rate (Average) | `macro_bi_rate_pct_nat_y` | national |
| Kurs | `macro_fx_idr_usd_nat_y` | national |
| IKK | `macro_construction_cost_index_y` | province |

## Status / action needed

- **All LEI inputs are covered by `phk_master.csv`** once it is rebuilt.
- `Penjualan Mobil` was just added to the build (`macro_car_sales_nat`, national
  monthly). **`phk_master.csv` on disk is stale** — rebuild it in Stata
  (`code/01_build_phk_master.do`) so it reflects the latest `data_untuk_phk_dashboard`
  upload *and* includes `macro_car_sales_nat`.
- After rebuild, verify the LEI still produces the same `Indeks_LEI_Labour` for a
  known month before switching over.
