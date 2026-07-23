# PHK Early Warning Dashboard — Data Dictionary

Human-readable companion to the machine-readable **`dictionary/indicator_dictionary.csv`** and **`config/master_schema.yml`** (same variable list). Built from the actual columns of `Database (Bulan / Triwulan / Tahun)` in **`data/raw/data_untuk_phk_dashboard.xlsx`**, the canonical source. MAP is not merged.

## Dataset at a glance

| Property | Value |
| --- | --- |
| Main output | `data/clean/phk_master.csv` |
| Grain | one row = province × month |
| Coverage | 2022–2026 (38 provinces × 60 months = 2,280 rows) |
| Variables | 304 columns |
| Build | `code/01_build_phk_master.do` (Stata) |

## Naming convention

The column name says what the variable means; frequency and level are encoded in the name:

- Frequency suffix: no suffix = **monthly**, `_q` = **quarterly**, `_y` = **annual**.
- Level: `_nat` in the name = **national** (identical across provinces); otherwise **province**.
- Domain prefixes: `phk_ lab_ emp_ emp_share_ wage_ bpjstk_ ind_ macro_ price_ trade_ fin_`; derived `growth_ lag1_ diffgr_`.

## Notes

- **Coverage by frequency:** **monthly** variables run 2022–2026 (2026 real data through ~July; Aug–Dec present as empty rows). **Quarterly (`_q`) and annual (`_y`)** variables run **2022–2025 only** — Triwulan/Tahun 2026 are not yet in the workbook, so every `_q`/`_y` column is missing for 2026.
- **National indicators (21):** repeated across province rows but are national-level — do not read as provincial variation. They carry `_nat`.
- **PDRB:** elaborated into 17 sectors at quarterly (`macro_pdrb_<sector>_q`) and annual (`macro_pdrb_<sector>_y`) grain. Level values are **PDRB Riil (constant price / ADHK)** in **IDR milyar (billion)**. Verified: the 17 sectors sum to the total, and the 4 quarters sum to the annual.
- **Missing vs zero:** invalid source cells (`-`, `#VALUE!`, blank) import as **missing**, never zero.
- Units are taken as-is from the workbook; no conversion is applied in the build.

## Using the data by frequency / level

Frequency and geographic level are encoded in each variable's **name**: `_q` = quarterly,
`_y` = annual, no suffix = monthly; `_nat` = national, otherwise provincial. The master
(`phk_master.csv`) is one row = province x month; select a subset by **column**:

```stata
import delimited "data/clean/phk_master.csv", clear varnames(1)
keep province_name_std province_code year month date quarter *_q     // quarterly only
keep province_name_std province_code year *_y                        // annual only
keep province_name_std province_code year month date quarter *nat*   // national only
ds *nat*
drop `r(varlist)'                                                    // provincial only (drop national)
```

**Reminders.** National variables are repeated across all provinces - do not read them as
provincial variation. Annual values are broadcast across the 12 months of their year and
quarterly across 3 months; for one value per period add e.g. `keep if month==1`
(annual) or `keep if inlist(month,1,4,7,10)` (quarterly).

## Variables by theme

### Identity / keys (6)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `province_name_std` | — | province | key | — | Provinsi (standardized) |
| `province_code` | — | province | key | — | Kode Provinsi (BPS 2-digit, text) |
| `year` | — | - | key | — | Tahun |
| `month` | — | - | key | — | Bulan |
| `date` | — | - | key | — | (derived) first day of month |
| `quarter` | — | - | key | — | (derived) Triwulan |

### Layoffs (PHK) (5)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `phk_stock` | PHK (Stock) | province | monthly, quarterly | — | PHK (Stock) |
| `phk_flow` | PHK (Flow) | province | monthly, quarterly | — | PHK (Flow) |
| `phk_stock_q` | PHK (Stock) | province | monthly, quarterly | — | PHK (Stock) |
| `phk_flow_q` | PHK (Flow) | province | monthly, quarterly | — | PHK (Flow) |
| `phk_y` | PHK | province | annual | — | PHK |

### Labor market (34)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `lab_working_pop_q` | Jumlah Penduduk Bekerja | province | quarterly, annual | count | Jumlah Penduduk Bekerja |
| `lab_formal_share_pct_y` | % Pekerja Formal | province | annual | percent | % Pekerja Formal |
| `lab_formal_share_2019_pct_y` | % Pekerja Formal (2019) | province | annual | percent | % Pekerja Formal (2019) |
| `lab_formal_share_chg_vs2019_y` | % Pekerja Formal (Growth from 2019, pp) | province | annual | — | % Pekerja Formal (Growth from 2019, pp) |
| `lab_contract_workers_y` | Jumlah Pekerja Memiliki Kontrak Tertulis | province | annual | count | Jumlah Pekerja Memiliki Kontrak Tertulis |
| `lab_formal_workers_y` | Jumlah Pekerja Formal | province | annual | count | Jumlah Pekerja Formal |
| `lab_contract_share_pct_y` | % Pekerja Memiliki Kontrak Tertulis | province | annual | percent | % Pekerja Memiliki Kontrak Tertulis |
| `lab_contract_share_2019_pct_y` | % Pekerja Memiliki Kontrak Tertulis (2019) | province | annual | percent | % Pekerja Memiliki Kontrak Tertulis (2019) |
| `lab_contract_share_chg_vs2019_y` | % Pekerja Memiliki Kontrak Tertulis (Growth from 2019, pp) | province | annual | — | % Pekerja Memiliki Kontrak Tertulis (Growth from 2019, pp) |
| `lab_working_pop_y` | Jumlah Penduduk Bekerja | province | quarterly, annual | count | Jumlah Penduduk Bekerja |
| `lab_tpt_pct_y` | % TPT | province | annual | percent | % TPT |
| `lab_tpt_male_pct_y` | % TPT Laki-laki | province | annual | percent | % TPT Laki-laki |
| `lab_tpt_female_pct_y` | % TPT Perempuan | province | annual | percent | % TPT Perempuan |
| `lab_tpak_pct_y` | % TPAK | province | annual | percent | % TPAK |
| `lab_tpak_male_pct_y` | % TPAK Laki-laki | province | annual | percent | % TPAK Laki-laki |
| `lab_tpak_female_pct_y` | % TPAK Perempuan | province | annual | percent | % TPAK Perempuan |
| `lab_self_employed_y` | Berusaha Sendiri | province | annual | count | Berusaha Sendiri |
| `lab_employee_count_y` | Buruh/karyawan/pegawai | province | annual | count | Buruh/karyawan/pegawai |
| `lab_unpaid_family_y` | Pekerja Keluarga Tidak Dibayar | province | annual | count | Pekerja Keluarga Tidak Dibayar |
| `lab_underemployed_workers_y` | Penduduk Bekerja Setengah Penganggur | province | annual | count | Penduduk Bekerja Setengah Penganggur |
| `lab_full_time_share_pct_y` | % Pekerja Penuh Waktu | province | annual | percent | % Pekerja Penuh Waktu |
| `lab_part_time_share_pct_y` | % Pekerja Paruh Waktu | province | annual | percent | % Pekerja Paruh Waktu |
| `lab_underemp_share_pct_y` | % Setengah Pengangguran | province | annual | percent | % Setengah Pengangguran |
| `lab_working_hours_y` | Jam Kerja | province | annual | hours | Jam Kerja |
| `lab_nonagri_informal_share_pct_y` | Proporsi Lapangan Kerja Informal Sektor Non-Pertanian | province | annual | percent | Proporsi Lapangan Kerja Informal Sektor Non-Pertanian |
| `lab_informal_share_pct_y` | Proporsi Lapangan Kerja Informal | province | annual | percent | Proporsi Lapangan Kerja Informal |
| `lab_job_seekers_y` | Pencari Kerja Terdaftar - Jumlah | province | annual | count | Pencari Kerja Terdaftar - Jumlah |
| `lab_vacancies_registered_y` | Lowongan Kerja Terdaftar - Jumlah | province | annual | count | Lowongan Kerja Terdaftar - Jumlah |
| `lab_placements_registered_y` | Penempatan/Pemenuhan Tenaga Kerja - Jumlah | province | annual | count | Penempatan/Pemenuhan Tenaga Kerja - Jumlah |
| `lab_unemployed_y` | Jumlah Pengangguran | province | annual | count | Jumlah Pengangguran |
| `lab_unemployed_youth_y` | Jumlah Penganggur Usia Muda (15-24 tahun) | province | annual | count | Jumlah Penganggur Usia Muda (15-24 tahun) |
| `lab_unemployed_edu_y` | Jumlah Penganggur Terdidik (S1/Diploma ke atas) | province | annual | count | Jumlah Penganggur Terdidik (S1/Diploma ke atas) |
| `lab_unemployed_youth_share_pct_y` | % Share Penganggur Usia Muda (15-24 tahun) | province | annual | percent | % Share Penganggur Usia Muda (15-24 tahun) |
| `lab_unemployed_edu_share_pct_y` | % Share Penganggur Terdidik (S1/Diploma ke atas) | province | annual | percent | % Share Penganggur Terdidik (S1/Diploma ke atas) |
| `lab_above_minwage_share_pct_y` | % Pekerja di atas UM | province | annual | percent | % Pekerja di atas UM |

### Employment by sector (51)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `emp_agri_y` | Tenaga Kerja - Pertanian, Kehutanan dan Perikanan | province | annual | count | Tenaga Kerja - Pertanian, Kehutanan dan Perikanan |
| `emp_mining_y` | Tenaga Kerja - Pertambangan dan Penggalian | province | annual | count | Tenaga Kerja - Pertambangan dan Penggalian |
| `emp_manuf_y` | Tenaga Kerja - Industri Pengolahan | province | annual | count | Tenaga Kerja - Industri Pengolahan |
| `emp_electricity_y` | Tenaga Kerja - Pengadaan Listrik dan Gas | province | annual | count | Tenaga Kerja - Pengadaan Listrik dan Gas |
| `emp_water_waste_y` | Tenaga Kerja - Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang | province | annual | count | Tenaga Kerja - Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang |
| `emp_construction_y` | Tenaga Kerja - Konstruksi | province | annual | count | Tenaga Kerja - Konstruksi |
| `emp_trade_y` | Tenaga Kerja - Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor | province | annual | count | Tenaga Kerja - Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor |
| `emp_transport_y` | Tenaga Kerja - Transportasi dan Pergudangan | province | annual | count | Tenaga Kerja - Transportasi dan Pergudangan |
| `emp_accom_food_y` | Tenaga Kerja - Penyediaan Akomodasi dan Makan Minum | province | annual | count | Tenaga Kerja - Penyediaan Akomodasi dan Makan Minum |
| `emp_info_comm_y` | Tenaga Kerja - Informasi dan Komunikasi | province | annual | count | Tenaga Kerja - Informasi dan Komunikasi |
| `emp_finance_y` | Tenaga Kerja - Jasa Keuangan dan Asuransi | province | annual | count | Tenaga Kerja - Jasa Keuangan dan Asuransi |
| `emp_real_estate_y` | Tenaga Kerja - Real Estate | province | annual | count | Tenaga Kerja - Real Estate |
| `emp_business_svc_y` | Tenaga Kerja - Jasa Perusahaan | province | annual | count | Tenaga Kerja - Jasa Perusahaan |
| `emp_public_admin_y` | Tenaga Kerja - Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib | province | annual | count | Tenaga Kerja - Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib |
| `emp_education_y` | Tenaga Kerja - Jasa Pendidikan | province | annual | count | Tenaga Kerja - Jasa Pendidikan |
| `emp_health_y` | Tenaga Kerja - Jasa Kesehatan dan Kegiatan Sosial | province | annual | count | Tenaga Kerja - Jasa Kesehatan dan Kegiatan Sosial |
| `emp_other_svc_y` | Tenaga Kerja - Jasa Lainnya | province | annual | count | Tenaga Kerja - Jasa Lainnya |
| `emp_share_agri_pct_y` | % Share Tenaga Kerja - Pertanian, Kehutanan dan Perikanan | province | annual | percent | % Share Tenaga Kerja - Pertanian, Kehutanan dan Perikanan |
| `emp_share_mining_pct_y` | % Share Tenaga Kerja - Pertambangan dan Penggalian | province | annual | percent | % Share Tenaga Kerja - Pertambangan dan Penggalian |
| `emp_share_manuf_pct_y` | % Share Tenaga Kerja - Industri Pengolahan | province | annual | percent | % Share Tenaga Kerja - Industri Pengolahan |
| `emp_share_electricity_pct_y` | % Share Tenaga Kerja - Pengadaan Listrik dan Gas | province | annual | percent | % Share Tenaga Kerja - Pengadaan Listrik dan Gas |
| `emp_share_water_waste_pct_y` | % Share Tenaga Kerja - Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang | province | annual | percent | % Share Tenaga Kerja - Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang |
| `emp_share_construction_pct_y` | % Share Tenaga Kerja - Konstruksi | province | annual | percent | % Share Tenaga Kerja - Konstruksi |
| `emp_share_trade_pct_y` | % Share Tenaga Kerja - Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor | province | annual | percent | % Share Tenaga Kerja - Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor |
| `emp_share_transport_pct_y` | % Share Tenaga Kerja - Transportasi dan Pergudangan | province | annual | percent | % Share Tenaga Kerja - Transportasi dan Pergudangan |
| `emp_share_accom_food_pct_y` | % Share Tenaga Kerja - Penyediaan Akomodasi dan Makan Minum | province | annual | percent | % Share Tenaga Kerja - Penyediaan Akomodasi dan Makan Minum |
| `emp_share_info_comm_pct_y` | % Share Tenaga Kerja - Informasi dan Komunikasi | province | annual | percent | % Share Tenaga Kerja - Informasi dan Komunikasi |
| `emp_share_finance_pct_y` | % Share Tenaga Kerja - Jasa Keuangan dan Asuransi | province | annual | percent | % Share Tenaga Kerja - Jasa Keuangan dan Asuransi |
| `emp_share_real_estate_pct_y` | % Share Tenaga Kerja - Real Estate | province | annual | percent | % Share Tenaga Kerja - Real Estate |
| `emp_share_business_svc_pct_y` | % Share Tenaga Kerja - Jasa Perusahaan | province | annual | percent | % Share Tenaga Kerja - Jasa Perusahaan |
| `emp_share_public_admin_pct_y` | % Share Tenaga Kerja - Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib | province | annual | percent | % Share Tenaga Kerja - Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib |
| `emp_share_education_pct_y` | % Share Tenaga Kerja - Jasa Pendidikan | province | annual | percent | % Share Tenaga Kerja - Jasa Pendidikan |
| `emp_share_health_pct_y` | % Share Tenaga Kerja - Jasa Kesehatan dan Kegiatan Sosial | province | annual | percent | % Share Tenaga Kerja - Jasa Kesehatan dan Kegiatan Sosial |
| `emp_share_other_svc_pct_y` | % Share Tenaga Kerja - Jasa Lainnya | province | annual | percent | % Share Tenaga Kerja - Jasa Lainnya |
| `emp_share_agri_ppt_chg_y` | (derived: emp_share_agri_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Pertanian, Kehutanan & Perikanan: share_t - share_{t-1} |
| `emp_share_mining_ppt_chg_y` | (derived: emp_share_mining_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Pertambangan & Penggalian: share_t - share_{t-1} |
| `emp_share_manuf_ppt_chg_y` | (derived: emp_share_manuf_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Industri Pengolahan: share_t - share_{t-1} |
| `emp_share_electricity_ppt_chg_y` | (derived: emp_share_electricity_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Pengadaan Listrik & Gas: share_t - share_{t-1} |
| `emp_share_water_waste_ppt_chg_y` | (derived: emp_share_water_waste_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Pengadaan Air, Sampah, Limbah: share_t - share_{t-1} |
| `emp_share_construction_ppt_chg_y` | (derived: emp_share_construction_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Konstruksi: share_t - share_{t-1} |
| `emp_share_trade_ppt_chg_y` | (derived: emp_share_trade_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Perdagangan Besar & Eceran: share_t - share_{t-1} |
| `emp_share_transport_ppt_chg_y` | (derived: emp_share_transport_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Transportasi & Pergudangan: share_t - share_{t-1} |
| `emp_share_accom_food_ppt_chg_y` | (derived: emp_share_accom_food_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Akomodasi & Makan Minum: share_t - share_{t-1} |
| `emp_share_info_comm_ppt_chg_y` | (derived: emp_share_info_comm_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Informasi & Komunikasi: share_t - share_{t-1} |
| `emp_share_finance_ppt_chg_y` | (derived: emp_share_finance_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Jasa Keuangan & Asuransi: share_t - share_{t-1} |
| `emp_share_real_estate_ppt_chg_y` | (derived: emp_share_real_estate_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Real Estate: share_t - share_{t-1} |
| `emp_share_business_svc_ppt_chg_y` | (derived: emp_share_business_svc_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Jasa Perusahaan: share_t - share_{t-1} |
| `emp_share_public_admin_ppt_chg_y` | (derived: emp_share_public_admin_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Administrasi Pemerintahan: share_t - share_{t-1} |
| `emp_share_education_ppt_chg_y` | (derived: emp_share_education_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Jasa Pendidikan: share_t - share_{t-1} |
| `emp_share_health_ppt_chg_y` | (derived: emp_share_health_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Jasa Kesehatan: share_t - share_{t-1} |
| `emp_share_other_svc_ppt_chg_y` | (derived: emp_share_other_svc_pct_y) | province | annual | percentage points | Perubahan tahunan (poin persen) pangsa tenaga kerja sektor Jasa Lainnya: share_t - share_{t-1} |

### Wages (4)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `wage_ump_idr_y` | UMP (IDR) | province | annual | IDR | UMP (IDR) |
| `wage_ump_growth_pct_y` | Growth UMP | province | annual | percent | Growth UMP |
| `wage_avg_employee_idr_y` | Upah buruh/karyawan/pegawai (IDR) | province | annual | IDR | Upah buruh/karyawan/pegawai (IDR) |
| `wage_kaitz_index_y` | Kaitz Index | province | annual | index | Kaitz Index |

### BPJS Ketenagakerjaan (5)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `bpjstk_active_pu_y` | BPJSTK - Peserta Aktif PU | province | annual | count | BPJSTK - Peserta Aktif PU |
| `bpjstk_active_bpu_y` | BPJSTK - Peserta Aktif BPU | province | annual | count | BPJSTK - Peserta Aktif BPU |
| `bpjstk_phk_y` | BPJSTK - PHK | province | annual | count | BPJSTK - PHK |
| `bpjstk_jht_phk_y` | BPJSTK - JHT PHK | province | annual | count | BPJSTK - JHT PHK |
| `bpjstk_jkp_phk_y` | BPJSTK - JKP PHK | province | annual | count | BPJSTK - JKP PHK |

### Manufacturing industry (statistik industri) (44)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `ind_firms_medium_y` | Perusahaan Industri Sedang | province | annual | count | Perusahaan Industri Sedang |
| `ind_firms_large_y` | Perusahaan Industri Besar | province | annual | count | Perusahaan Industri Besar |
| `ind_firms_total_y` | Jumlah Perusahaan | province | annual | count | Jumlah Perusahaan |
| `ind_workers_medium_y` | Tenaga Kerja Industri Sedang | province | annual | count | Tenaga Kerja Industri Sedang |
| `ind_workers_large_y` | Tenaga Kerja Industri Besar | province | annual | count | Tenaga Kerja Industri Besar |
| `ind_workers_prod_y` | Jumlah Tenaga Kerja Produksi | province | annual | count | Jumlah Tenaga Kerja Produksi |
| `ind_workers_nonprod_y` | Jumlah Tenaga Kerja Lainnya | province | annual | count | Jumlah Tenaga Kerja Lainnya |
| `ind_workers_total_y` | Jumlah Tenaga Kerja | province | annual | count | Jumlah Tenaga Kerja |
| `ind_prod_workers_wage_cost_y` | Pengeluaran untuk Pekerja Produksi Upah/Gaji, Upah Lembur, Tunjangan | province | annual | — | Pengeluaran untuk Pekerja Produksi Upah/Gaji, Upah Lembur, Tunjangan |
| `ind_prod_workers_other_cost_y` | Pengeluaran untuk Pekerja Produksi Lainnya | province | annual | — | Pengeluaran untuk Pekerja Produksi Lainnya |
| `ind_prod_workers_total_cost_y` | Jumlah Pengeluaran untuk Pekerja Produksi | province | annual | — | Jumlah Pengeluaran untuk Pekerja Produksi |
| `ind_nonprod_workers_wage_cost_y` | Pengeluaran untuk Pekerja Lainnya Upah/Gaji, Upah Lembur, Tunjangan | province | annual | — | Pengeluaran untuk Pekerja Lainnya Upah/Gaji, Upah Lembur, Tunjangan |
| `ind_nonprod_workers_other_cost_y` | Pengeluaran untuk Pekerja Lainnya Lainnya | province | annual | — | Pengeluaran untuk Pekerja Lainnya Lainnya |
| `ind_nonprod_workers_total_cost_y` | Jumlah Pengeluaran untuk Pekerja Lainnya | province | annual | — | Jumlah Pengeluaran untuk Pekerja Lainnya |
| `ind_laborcost_total_y` | Jumlah Pengeluaran Seluruh Pekerja | province | annual | — | Jumlah Pengeluaran Seluruh Pekerja |
| `ind_input_y` | Biaya Input | province | annual | — | Biaya Input |
| `ind_output_y` | Nilai Output | province | annual | — | Nilai Output |
| `ind_va_mkt_y` | Nilai Tambah (harga pasar) | province | annual | — | Nilai Tambah (harga pasar) |
| `ind_va_fc_y` | Nilai Tambah (biaya faktor produksi) | province | annual | — | Nilai Tambah (biaya faktor produksi) |
| `ind_firms_pmdn_y` | Jumlah Perusahaan PMDN | province | annual | count | Jumlah Perusahaan PMDN |
| `ind_firms_pma_y` | Jumlah Perusahaan PMA | province | annual | count | Jumlah Perusahaan PMA |
| `ind_workers_per_firm_y` | Jumlah Tenaga Kerja/Jumlah Perusahaan | province | annual | count | Jumlah Tenaga Kerja/Jumlah Perusahaan |
| `ind_prod_worker_share_y` | Jumlah Tenaga Kerja Produksi/Jumlah Tenaga Kerja | province | annual | — | Jumlah Tenaga Kerja Produksi/Jumlah Tenaga Kerja |
| `ind_workers_per_input_y` | Jumlah Tenaga Kerja/Biaya Input | province | annual | count | Jumlah Tenaga Kerja/Biaya Input |
| `ind_workers_per_output_y` | Jumlah Tenaga Kerja/Nilai Output | province | annual | count | Jumlah Tenaga Kerja/Nilai Output |
| `ind_workers_per_va_mkt_y` | Jumlah Tenaga Kerja/Nilai Tambah (harga pasar) | province | annual | count | Jumlah Tenaga Kerja/Nilai Tambah (harga pasar) |
| `ind_workers_per_va_fc_y` | Jumlah Tenaga Kerja/Nilai Tambah (biaya faktor produksi) | province | annual | count | Jumlah Tenaga Kerja/Nilai Tambah (biaya faktor produksi) |
| `ind_laborcost_share_input_y` | Biaya Pekerja/Biaya Input | province | annual | — | Biaya Pekerja/Biaya Input |
| `ind_laborcost_share_output_y` | Biaya Pekerja/Nilai Output | province | annual | — | Biaya Pekerja/Nilai Output |
| `ind_laborcost_share_va_mkt_y` | Biaya Pekerja/Nilai Tambah Pasar | province | annual | — | Biaya Pekerja/Nilai Tambah Pasar |
| `ind_laborcost_share_va_fc_y` | Biaya Pekerja/Nilai Tambah Produksi | province | annual | — | Biaya Pekerja/Nilai Tambah Produksi |
| `ind_laborcost_per_wkr_y` | Biaya Pekerja/Tenaga Kerja | province | annual | — | Biaya Pekerja/Tenaga Kerja |
| `ind_output_per_wkr_y` | Nilai Output/Tenaga Kerja | province | annual | — | Nilai Output/Tenaga Kerja |
| `ind_va_mkt_per_wkr_y` | Nilai Tambah Pasar/Tenaga Kerja | province | annual | — | Nilai Tambah Pasar/Tenaga Kerja |
| `ind_va_fc_per_wkr_y` | Nilai Tambah Produksi/Tenaga Kerja | province | annual | — | Nilai Tambah Produksi/Tenaga Kerja |
| `ind_input_share_output_y` | Biaya Input/Nilai Output | province | annual | — | Biaya Input/Nilai Output |
| `ind_va_mkt_share_output_y` | Nilai Tambah Pasar/Nilai Output | province | annual | — | Nilai Tambah Pasar/Nilai Output |
| `ind_va_fc_share_output_y` | Nilai Tambah Produksi/Nilai Output | province | annual | — | Nilai Tambah Produksi/Nilai Output |
| `ind_prod_laborcost_share_y` | Biaya Pekerja Produksi/Total Biaya Pekerja | province | annual | — | Biaya Pekerja Produksi/Total Biaya Pekerja |
| `ind_nonprod_laborcost_share_y` | Biaya Pekerja Lainnya/Total Biaya Pekerja | province | annual | — | Biaya Pekerja Lainnya/Total Biaya Pekerja |
| `ind_prod_wage_per_wkr_y` | Upah Pekerja Produksi/Jumlah Tenaga Kerja Produksi | province | annual | — | Upah Pekerja Produksi/Jumlah Tenaga Kerja Produksi |
| `ind_nonprod_wage_per_wkr_y` | Upah Pekerja Lainnya/Jumlah Tenaga Kerja Lainnya | province | annual | — | Upah Pekerja Lainnya/Jumlah Tenaga Kerja Lainnya |
| `ind_firms_pmdn_share_y` | Proporsi Perusahaan PMDN | province | annual | count | Proporsi Perusahaan PMDN |
| `ind_firms_pma_share_y` | Proporsi Perusahaan PMA | province | annual | count | Proporsi Perusahaan PMA |

### Macro / PDRB (61)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `macro_pmi_manuf_nat` | PMI Manufaktur | national | monthly, quarterly, annual | index | PMI Manufaktur |
| `macro_bi_rate_pct_nat` | BI Rate | national | monthly, quarterly | — | BI Rate |
| `macro_fx_idr_usd_nat` | Kurs | national | monthly, quarterly, annual | IDR per USD | Kurs |
| `macro_pdrb_q` | PDRB (IDR milyar) | province | quarterly | IDR billion | PDRB (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_agri_q` | PDRB Pertanian, Kehutanan dan Perikanan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pertanian, Kehutanan dan Perikanan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_mining_q` | PDRB Pertambangan dan Penggalian (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pertambangan dan Penggalian (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_manuf_q` | PDRB Industri Pengolahan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Industri Pengolahan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_electricity_q` | PDRB Pengadaan Listrik dan Gas (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pengadaan Listrik dan Gas (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_water_waste_q` | PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_construction_q` | PDRB Konstruksi (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Konstruksi (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_trade_q` | PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_transport_q` | PDRB Transportasi dan Pergudangan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Transportasi dan Pergudangan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_accom_food_q` | PDRB Penyediaan Akomodasi dan Makan Minum (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Penyediaan Akomodasi dan Makan Minum (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_info_comm_q` | PDRB Informasi dan Komunikasi (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Informasi dan Komunikasi (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_finance_q` | PDRB Jasa Keuangan dan Asuransi (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Keuangan dan Asuransi (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_real_estate_q` | PDRB Real Estate (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Real Estate (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_business_svc_q` | PDRB Jasa Perusahaan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Perusahaan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_public_admin_q` | PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_education_q` | PDRB Jasa Pendidikan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Pendidikan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_health_q` | PDRB Jasa Kesehatan dan Kegiatan Sosial (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Kesehatan dan Kegiatan Sosial (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_other_svc_q` | PDRB Jasa Lainnya (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Lainnya (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_manuf_share_pct_q` | % PDRB Industri Pengolahan | province | quarterly, annual | percent | % PDRB Industri Pengolahan |
| `macro_pdrb_agri_share_pct_q` | % PDRB Pertanian, Kehutanan dan Perikanan | province | quarterly, annual | percent | % PDRB Pertanian, Kehutanan dan Perikanan |
| `macro_pdrb_svc_share_pct_q` | (derived: sum of 11 service-sector % PDRB) | province | quarterly, annual | percent | (derived: sum of 11 service-sector % PDRB) |
| `macro_pdrb_mining_shr_q` | % PDRB Pertambangan dan Penggalian | province | quarterly, annual | percent | % PDRB Pertambangan dan Penggalian |
| `macro_pdrb_electricity_shr_q` | % PDRB Pengadaan Listrik dan Gas | province | quarterly, annual | percent | % PDRB Pengadaan Listrik dan Gas |
| `macro_pdrb_water_waste_shr_q` | % PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang | province | quarterly, annual | percent | % PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang |
| `macro_pdrb_construction_shr_q` | % PDRB Konstruksi | province | quarterly, annual | percent | % PDRB Konstruksi |
| `macro_pdrb_trade_shr_q` | % PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor | province | quarterly, annual | percent | % PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor |
| `macro_pdrb_transport_shr_q` | % PDRB Transportasi dan Pergudangan | province | quarterly, annual | percent | % PDRB Transportasi dan Pergudangan |
| `macro_pdrb_accom_food_shr_q` | % PDRB Penyediaan Akomodasi dan Makan Minum | province | quarterly, annual | percent | % PDRB Penyediaan Akomodasi dan Makan Minum |
| `macro_pdrb_info_comm_shr_q` | % PDRB Informasi dan Komunikasi | province | quarterly, annual | percent | % PDRB Informasi dan Komunikasi |
| `macro_pdrb_finance_shr_q` | % PDRB Jasa Keuangan dan Asuransi | province | quarterly, annual | percent | % PDRB Jasa Keuangan dan Asuransi |
| `macro_pdrb_real_estate_shr_q` | % PDRB Real Estate | province | quarterly, annual | percent | % PDRB Real Estate |
| `macro_pdrb_business_svc_shr_q` | % PDRB Jasa Perusahaan | province | quarterly, annual | percent | % PDRB Jasa Perusahaan |
| `macro_pdrb_public_admin_shr_q` | % PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib | province | quarterly, annual | percent | % PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib |
| `macro_pdrb_education_shr_q` | % PDRB Jasa Pendidikan | province | quarterly, annual | percent | % PDRB Jasa Pendidikan |
| `macro_pdrb_health_shr_q` | % PDRB Jasa Kesehatan dan Kegiatan Sosial | province | quarterly, annual | percent | % PDRB Jasa Kesehatan dan Kegiatan Sosial |
| `macro_pdrb_other_svc_shr_q` | % PDRB Jasa Lainnya | province | quarterly, annual | percent | % PDRB Jasa Lainnya |
| `macro_pmi_manuf_nat_q` | PMI Manufaktur | national | monthly, quarterly, annual | index | PMI Manufaktur |
| `macro_bi_rate_pct_nat_q` | BI Rate | national | monthly, quarterly | — | BI Rate |
| `macro_fx_idr_usd_nat_q` | Kurs | national | monthly, quarterly, annual | IDR per USD | Kurs |
| `macro_pdrb_idr_billion_y` | PDRB (IDR milyar) | province | annual | IDR billion | PDRB (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_idr_million_y` | PDRB (IDR juta) | province | annual | IDR million | PDRB (IDR juta) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_agri_y` | PDRB Pertanian, Kehutanan dan Perikanan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pertanian, Kehutanan dan Perikanan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_mining_y` | PDRB Pertambangan dan Penggalian (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pertambangan dan Penggalian (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_manuf_y` | PDRB Industri Pengolahan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Industri Pengolahan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_electricity_y` | PDRB Pengadaan Listrik dan Gas (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pengadaan Listrik dan Gas (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_water_waste_y` | PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_construction_y` | PDRB Konstruksi (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Konstruksi (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_trade_y` | PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_transport_y` | PDRB Transportasi dan Pergudangan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Transportasi dan Pergudangan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_accom_food_y` | PDRB Penyediaan Akomodasi dan Makan Minum (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Penyediaan Akomodasi dan Makan Minum (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_info_comm_y` | PDRB Informasi dan Komunikasi (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Informasi dan Komunikasi (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_finance_y` | PDRB Jasa Keuangan dan Asuransi (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Keuangan dan Asuransi (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_real_estate_y` | PDRB Real Estate (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Real Estate (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_business_svc_y` | PDRB Jasa Perusahaan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Perusahaan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_public_admin_y` | PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_education_y` | PDRB Jasa Pendidikan (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Pendidikan (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_health_y` | PDRB Jasa Kesehatan dan Kegiatan Sosial (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Kesehatan dan Kegiatan Sosial (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_other_svc_y` | PDRB Jasa Lainnya (IDR milyar) | province | quarterly, annual | IDR billion | PDRB Jasa Lainnya (IDR milyar) - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_manuf_share_pct_y` | % PDRB Industri Pengolahan | province | quarterly, annual | percent | % PDRB Industri Pengolahan |
| `macro_pdrb_agri_share_pct_y` | % PDRB Pertanian, Kehutanan dan Perikanan | province | quarterly, annual | percent | % PDRB Pertanian, Kehutanan dan Perikanan |
| `macro_pdrb_svc_share_pct_y` | (derived: sum of 11 service-sector % PDRB) | province | quarterly, annual | percent | (derived: sum of 11 service-sector % PDRB) |
| `macro_pdrb_mining_shr_y` | % PDRB Pertambangan dan Penggalian | province | quarterly, annual | percent | % PDRB Pertambangan dan Penggalian |
| `macro_pdrb_electricity_shr_y` | % PDRB Pengadaan Listrik dan Gas | province | quarterly, annual | percent | % PDRB Pengadaan Listrik dan Gas |
| `macro_pdrb_water_waste_shr_y` | % PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang | province | quarterly, annual | percent | % PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang |
| `macro_pdrb_construction_shr_y` | % PDRB Konstruksi | province | quarterly, annual | percent | % PDRB Konstruksi |
| `macro_pdrb_trade_shr_y` | % PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor | province | quarterly, annual | percent | % PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor |
| `macro_pdrb_transport_shr_y` | % PDRB Transportasi dan Pergudangan | province | quarterly, annual | percent | % PDRB Transportasi dan Pergudangan |
| `macro_pdrb_accom_food_shr_y` | % PDRB Penyediaan Akomodasi dan Makan Minum | province | quarterly, annual | percent | % PDRB Penyediaan Akomodasi dan Makan Minum |
| `macro_pdrb_info_comm_shr_y` | % PDRB Informasi dan Komunikasi | province | quarterly, annual | percent | % PDRB Informasi dan Komunikasi |
| `macro_pdrb_finance_shr_y` | % PDRB Jasa Keuangan dan Asuransi | province | quarterly, annual | percent | % PDRB Jasa Keuangan dan Asuransi |
| `macro_pdrb_real_estate_shr_y` | % PDRB Real Estate | province | quarterly, annual | percent | % PDRB Real Estate |
| `macro_pdrb_business_svc_shr_y` | % PDRB Jasa Perusahaan | province | quarterly, annual | percent | % PDRB Jasa Perusahaan |
| `macro_pdrb_public_admin_shr_y` | % PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib | province | quarterly, annual | percent | % PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib |
| `macro_pdrb_education_shr_y` | % PDRB Jasa Pendidikan | province | quarterly, annual | percent | % PDRB Jasa Pendidikan |
| `macro_pdrb_health_shr_y` | % PDRB Jasa Kesehatan dan Kegiatan Sosial | province | quarterly, annual | percent | % PDRB Jasa Kesehatan dan Kegiatan Sosial |
| `macro_pdrb_other_svc_shr_y` | % PDRB Jasa Lainnya | province | quarterly, annual | percent | % PDRB Jasa Lainnya |
| `macro_pdrb_manuf_growth_pct_y` | Laju Pertumbuhan PDB Industri Manufaktur | province | annual | IDR billion | Laju Pertumbuhan PDB Industri Manufaktur - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_per_wkr_y` | PDRB/Pekerja | province | annual | IDR billion | PDRB/Pekerja - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_per_wkr_growth_pct_y` | Laju Pertumbuhan PDB Per Tenaga Kerja | province | annual | IDR billion | Laju Pertumbuhan PDB Per Tenaga Kerja - PDRB Riil (constant price / ADHK) |
| `macro_pdrb_pcap_idr_thousand_y` | PDRB Per Kapita (Ribu Rupiah) | province | annual | IDR thousand | PDRB Per Kapita (Ribu Rupiah) |
| `macro_pmi_manuf_nat_y` | PMI Manufaktur | national | monthly, quarterly, annual | index | PMI Manufaktur |
| `macro_fx_idr_usd_nat_y` | Kurs | national | monthly, quarterly, annual | IDR per USD | Kurs |
| `macro_fed_funds_rate_nat` | Federal Funds Effective Rate (Daily, 7-Day) | national | monthly | percent | Federal Funds Effective Rate (Daily, 7-Day) |
| `macro_bi_rate_pct_nat_y` | BI Rate | national | annual | percent | BI Rate |
| `macro_pdb_idr_billion_nat_y` | PDB (IDR milyar) | national | quarterly, annual | IDR billion | PDB (IDR milyar) |
| `macro_world_gdp_nat_y` | World GDP | national | quarterly, annual | — | World GDP |
| `macro_fed_funds_rate_nat_y` | Federal Funds Effective Rate (End of Period) | national | quarterly, annual | percent | Federal Funds Effective Rate (End of Period) |
| `macro_pdb_idr_billion_nat_q` | PDB (IDR milyar) | national | quarterly, annual | IDR billion | PDB (IDR milyar) |
| `macro_world_gdp_nat_q` | World GDP | national | quarterly, annual | — | World GDP |
| `macro_fed_funds_rate_nat_q` | Federal Funds Effective Rate (End of Period) | national | quarterly, annual | percent | Federal Funds Effective Rate (End of Period) |
| `macro_construction_cost_index_y` | Indeks Kemahalan Konstruksi | province | annual | index | Indeks Kemahalan Konstruksi |
| `macro_pdrb_hh_cons_share_pct_y` | Persentase Pengeluaran Konsumsi Rumah Tangga Atas Dasar Harga Berlaku (persen) | province | annual | percent | Persentase Pengeluaran Konsumsi Rumah Tangga Atas Dasar Harga Berlaku (persen) |
| `macro_pdrb_gov_cons_share_pct_y` | Persentase Pengeluaran Konsumsi Pemerintah Atas Dasar Harga Berlaku (persen) | province | annual | percent | Persentase Pengeluaran Konsumsi Pemerintah Atas Dasar Harga Berlaku (persen) |
| `macro_pdrb_invest_share_pct_y` | Persentase Pembentukan Modal Tetap Bruto Atas Dasar Harga Berlaku (persen) | province | annual | percent | Persentase Pembentukan Modal Tetap Bruto Atas Dasar Harga Berlaku (persen) |
| `macro_fx_vol_sd_nat_y` | (derived: macro_fx_idr_usd_nat) | national | annual | IDR per USD | Volatilitas nilai tukar IDR/USD: simpangan baku (SD) dari 12 kurs bulanan dalam satu tahun kalender |

### Prices (17)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `price_cpi_index` | IHK (2010=100) | province | monthly, quarterly | index | IHK (2010=100) |
| `price_inflation_mom_pct` | Inflasi Bulanan (M-to-M) | province | monthly | percent | Inflasi Bulanan (M-to-M) |
| `price_inflation_yoy_pct` | Inflasi Tahunan (Y-on-Y) | province | monthly | percent | Inflasi Tahunan (Y-on-Y) |
| `price_consumer_change_pct` | Perubahan Harga Konsumen (persen, YoY) | province | monthly, quarterly | percent | Perubahan Harga Konsumen (persen, YoY) |
| `price_brent_usd_bbl_nat` | Harga Minyak Brent (USD/barrel) | national | monthly | USD per barrel | Harga Minyak Brent (USD/barrel) |
| `price_ihpb_nat` | IHPB | national | monthly | — | IHPB |
| `price_producer_index_nat_q` | IHP (2016=100) | national | quarterly, annual | index | IHP (2016=100) |
| `price_producer_change_pct_nat_q` | Perubahan Harga Produsen (%) | national | quarterly, annual | — | Perubahan Harga Produsen (%) |
| `price_cpi_index_q` | IHK (2010=100) | province | monthly, quarterly | index | IHK (2010=100) |
| `price_consumer_change_pct_q` | Perubahan Harga Konsumen | province | monthly, quarterly | percent | Perubahan Harga Konsumen |
| `price_inflation_yoy_q4_pct_y` | Inflasi YoY (per IV) | province | annual | percent | Inflasi YoY (per IV) |
| `price_inflation_yoy_avg_pct_y` | Inflasi YoY (Average) | province | annual | percent | Inflasi YoY (Average) |
| `price_producer_index_nat_y` | IHP (2016=100) | national | quarterly, annual | index | IHP (2016=100) |
| `price_cpi_index_nat_y` | IHK (2010=100) | national | annual | index | IHK (2010=100) |
| `price_producer_change_pct_nat_y` | Perubahan Harga Produsen (%) | national | quarterly, annual | — | Perubahan Harga Produsen (%) |
| `price_consumer_change_pct_nat_y` | Perubahan Harga Konsumen (%) | national | annual | — | Perubahan Harga Konsumen (%) |

### Trade (10)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `trade_export_value` | Nilai Ekspor (USD juta) | province | monthly, annual | — | Nilai Ekspor (USD juta) |
| `trade_import_value` | Nilai Impor (USD juta) | province | monthly, annual | — | Nilai Impor (USD juta) |
| `trade_balance` | Neraca Perdagangan (USD juta) | province | monthly, annual | — | Neraca Perdagangan (USD juta) |
| `trade_export_value_usd_million_q` | Nilai Ekspor (USD juta) | province | quarterly | USD million | Nilai Ekspor (USD juta) |
| `trade_import_value_usd_million_q` | Nilai Impor (USD juta) | province | quarterly | USD million | Nilai Impor (USD juta) |
| `trade_balance_usd_million_q` | Neraca Perdagangan* | province | quarterly | USD million | Neraca Perdagangan* |
| `trade_export_value_bps_y` | Nilai Ekspor BPS (USD juta) | province | annual | — | Nilai Ekspor BPS (USD juta) |
| `trade_export_value_y` | Nilai Ekspor (USD juta) | province | monthly, annual | — | Nilai Ekspor (USD juta) |
| `trade_import_value_y` | Nilai Impor (USD juta) | province | monthly, annual | — | Nilai Impor (USD juta) |
| `trade_balance_y` | Neraca Perdagangan | province | monthly, annual | — | Neraca Perdagangan |

### Finance (14)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `fin_total_credit_idr_billion` | Total Kredit (IDR miliar) | province | monthly, quarterly, annual | IDR billion | Total Kredit (IDR miliar) |
| `fin_npl_idr_billion` | NPL (IDR miliar) | province | monthly, quarterly | IDR billion | NPL (IDR miliar) |
| `fin_npl_ratio_pct` | NPL Ratio | province | monthly, quarterly, annual | percent | NPL Ratio |
| `fin_fdi_usd_million_q` | FDI (USD mn) | province | quarterly | USD million | FDI (USD mn) |
| `fin_fdi_idr_million_q` | FDI (IDR mn) | province | quarterly | IDR million | FDI (IDR mn) |
| `fin_total_credit_idr_billion_q` | Total Credits, End of Quarter (IDR miliar) | province | monthly, quarterly, annual | IDR billion | Total Credits, End of Quarter (IDR miliar) |
| `fin_npl_idr_billion_q` | NPL, End of Quarter (IDR miliar) | province | monthly, quarterly | IDR billion | NPL, End of Quarter (IDR miliar) |
| `fin_npl_ratio_pct_q` | NPL Ratio, End of Quarter | province | monthly, quarterly, annual | percent | NPL Ratio, End of Quarter |
| `fin_fdi_y` | FDI | province | annual | — | FDI |
| `fin_total_credit_idr_billion_y` | Total Credits, End of Year (IDR miliar) | province | monthly, quarterly, annual | IDR billion | Total Credits, End of Year (IDR miliar) |
| `fin_npl_y` | NPL, End of Year (IDR miliar) | province | annual | — | NPL, End of Year (IDR miliar) |
| `fin_npl_ratio_pct_y` | NPL Ratio, End of Year | province | monthly, quarterly, annual | percent | NPL Ratio, End of Year |
| `fin_npl_ratio_2020_pct_y` | NPL Ratio, End of Year (2020) | province | annual | percent | NPL Ratio, End of Year (2020) |
| `fin_npl_ratio_2021_pct_y` | NPL Ratio, End of Year (2021) | province | annual | percent | NPL Ratio, End of Year (2021) |

### Poverty (3)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `pov_line_idr_y` | Garis Kemiskinan - Maret (Rp) | province | annual | IDR | Garis Kemiskinan - Maret (Rp) |
| `pov_headcount_thousand_y` | Jumlah Penduduk Miskin - Maret (ribu) (Ribu) | province | annual | thousand persons | Jumlah Penduduk Miskin - Maret (ribu) (Ribu) |
| `pov_rate_pct_y` | Persentase Penduduk Miskin - Maret | province | annual | percent | Persentase Penduduk Miskin - Maret |

### Growth (derived) (39)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `growth_lab_working_pop_y` | Pertumbuhan Bekerja | province | annual | percent (growth) | Pertumbuhan Bekerja |
| `growth_lab_employee_count_y` | Pertumbuhan Buruh/Karyawan/Pegawai | province | annual | percent (growth) | Pertumbuhan Buruh/Karyawan/Pegawai |
| `growth_lab_unpaid_family_y` | Pertumbuhan Pekerja Keluarga Tidak Dibayar | province | annual | percent (growth) | Pertumbuhan Pekerja Keluarga Tidak Dibayar |
| `growth_lab_formal_share_pct_y` | Pertumbuhan % Pekerja Formal | province | annual | percent | Pertumbuhan % Pekerja Formal |
| `growth_lab_contract_share_pct_y` | Pertumbuhan % Pekerja Memiliki Kontrak Tertulis | province | annual | percent | Pertumbuhan % Pekerja Memiliki Kontrak Tertulis |
| `growth_lab_full_time_share_pct_y` | Pertumbuhan % Pekerja Penuh Waktu | province | annual | percent | Pertumbuhan % Pekerja Penuh Waktu |
| `growth_lab_part_time_share_pct_y` | Pertumbuhan % Pekerja Paruh Waktu | province | annual | percent | Pertumbuhan % Pekerja Paruh Waktu |
| `growth_lab_underemp_share_pct_y` | Pertumbuhan % Setengah Pengangguran | province | annual | percent | Pertumbuhan % Setengah Pengangguran |
| `growth_lab_working_hours_y` | Pertumbuhan Jam Kerja | province | annual | percent (growth) | Pertumbuhan Jam Kerja |
| `growth_lab_tpt_pct_y` | Pertumbuhan TPT | province | annual | percent | Pertumbuhan TPT |
| `growth_lab_tpt_male_pct_y` | Pertumbuhan TPT Laki-laki | province | annual | percent | Pertumbuhan TPT Laki-laki |
| `growth_lab_tpt_female_pct_y` | Pertumbuhan TPT Perempuan | province | annual | percent | Pertumbuhan TPT Perempuan |
| `growth_lab_tpak_pct_y` | Pertumbuhan TPAK | province | annual | percent | Pertumbuhan TPAK |
| `growth_lab_tpak_male_pct_y` | Pertumbuhan TPAK Laki-laki | province | annual | percent | Pertumbuhan TPAK Laki-laki |
| `growth_lab_tpak_female_pct_y` | Pertumbuhan TPAK Perempuan | province | annual | percent | Pertumbuhan TPAK Perempuan |
| `growth_wage_avg_employee_y` | Pertumbuhan Upah | province | annual | percent (growth) | Pertumbuhan Upah |
| `growth_bpjstk_active_pu_y` | Pertumbuhan BPJSTK - Peserta Aktif PU | province | annual | percent (growth) | Pertumbuhan BPJSTK - Peserta Aktif PU |
| `growth_bpjstk_active_bpu_y` | Pertumbuhan BPJSTK - Peserta Aktif BPU | province | annual | percent (growth) | Pertumbuhan BPJSTK - Peserta Aktif BPU |
| `growth_bpjstk_phk_y` | Pertumbuhan BPJSTK - PHK | province | annual | percent (growth) | Pertumbuhan BPJSTK - PHK |
| `growth_bpjstk_jht_phk_y` | Pertumbuhan BPJSTK - JHT PHK | province | annual | percent (growth) | Pertumbuhan BPJSTK - JHT PHK |
| `growth_bpjstk_jkp_phk_y` | Pertumbuhan BPJSTK - JKP PHK | province | annual | percent (growth) | Pertumbuhan BPJSTK - JKP PHK |
| `growth_ind_output_y` | Pertumbuhan Nilai Output | province | annual | percent (growth) | Pertumbuhan Nilai Output |
| `growth_ind_input_y` | Pertumbuhan Biaya Input | province | annual | percent (growth) | Pertumbuhan Biaya Input |
| `growth_ind_va_mkt_y` | Pertumbuhan Nilai Tambah Pasar | province | annual | percent (growth) | Pertumbuhan Nilai Tambah Pasar |
| `growth_ind_va_fc_y` | Pertumbuhan Nilai Tambah Produksi | province | annual | percent (growth) | Pertumbuhan Nilai Tambah Produksi |
| `growth_ind_workers_total_y` | Pertumbuhan Tenaga Kerja | province | annual | percent (growth) | Pertumbuhan Tenaga Kerja |
| `growth_ind_firms_total_y` | Pertumbuhan Jumlah Perusahaan | province | annual | percent (growth) | Pertumbuhan Jumlah Perusahaan |
| `growth_ind_laborcost_total_y` | Pertumbuhan Pengeluaran Tenaga Kerja | province | annual | percent (growth) | Pertumbuhan Pengeluaran Tenaga Kerja |
| `growth_ind_labor_prod_market_y` | Pertumbuhan Produktivitas (Nilai Tambah Pasar) Tenaga Kerja | province | annual | percent (growth) | Pertumbuhan Produktivitas (Nilai Tambah Pasar) Tenaga Kerja |
| `growth_ind_labor_prod_fc_y` | Pertumbuhan Produktivitas (Nilai Tambah Produksi) Tenaga Kerja | province | annual | percent (growth) | Pertumbuhan Produktivitas (Nilai Tambah Produksi) Tenaga Kerja |
| `growth_pdrb_pct_y` | Laju Pertumbuhan PDRB | province | annual | percent | Laju Pertumbuhan PDRB |
| `growth_pdrb_pcap_pct_y` | Laju Pertumbuhan PDRB Per Kapita (Persen) | province | annual | percent | Laju Pertumbuhan PDRB Per Kapita (Persen) |
| `growth_brent_yoy_pct_nat` | (derived: price_brent_usd_bbl_nat) | national | monthly | percent (growth) | Pertumbuhan tahunan (yoy) harga minyak Brent: (Brent_t/Brent_{t-12}-1)*100 |
| `growth_ihpb_yoy_pct_nat` | (derived: price_ihpb_nat) | national | monthly | percent (growth) | Pertumbuhan tahunan (yoy) IHPB / Indeks Harga Perdagangan Besar (wholesale): (IHPB_t/IHPB_{t-12}-1)*100 |
| `growth_npl_yoy_pct` | (derived: fin_npl_idr_billion) | province | monthly | percent (growth) | Pertumbuhan tahunan (yoy) NPL per provinsi: (NPL_t/NPL_{t-12}-1)*100 |
| `growth_export_yoy_pct` | (derived: trade_export_value) | province | monthly | percent (growth) | Pertumbuhan tahunan (yoy) nilai ekspor bulanan: (Ekspor_t/Ekspor_{t-12}-1)*100 |
| `growth_import_yoy_pct` | (derived: trade_import_value) | province | monthly | percent (growth) | Pertumbuhan tahunan (yoy) nilai impor bulanan: (Impor_t/Impor_{t-12}-1)*100 |
| `growth_export_yoy_pct_q` | (derived: trade_export_value_usd_million_q) | province | quarterly | percent (growth) | Pertumbuhan tahunan (yoy) nilai ekspor triwulanan: (Ekspor_Q_t/Ekspor_Q_{t-4}-1)*100 |
| `growth_import_yoy_pct_q` | (derived: trade_import_value_usd_million_q) | province | quarterly | percent (growth) | Pertumbuhan tahunan (yoy) nilai impor triwulanan: (Impor_Q_t/Impor_Q_{t-4}-1)*100 |

### Lagged (derived) (9)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `lag1_phk_y` | Lag_1 PHK | province | annual | — | Lag_1 PHK |
| `lag1_lab_formal_share_pct_y` | Lag_1 % Pekerja Formal | province | annual | percent | Lag_1 % Pekerja Formal |
| `lag1_lab_contract_share_pct_y` | Lag_1 % Pekerja Memiliki Kontrak Tertulis | province | annual | percent | Lag_1 % Pekerja Memiliki Kontrak Tertulis |
| `lag1_wage_ump_growth_pct_y` | Lag_1 Growth UMP | province | annual | percent | Lag_1 Growth UMP |
| `lag1_bpjstk_active_pu_y` | Lag_1 BPJSTK - Peserta Aktif PU | province | annual | — | Lag_1 BPJSTK - Peserta Aktif PU |
| `lag1_bpjstk_active_bpu_y` | Lag_1 BPJSTK - Peserta Aktif BPU | province | annual | — | Lag_1 BPJSTK - Peserta Aktif BPU |
| `lag1_bpjstk_phk_y` | Lag_1 BPJSTK - PHK | province | annual | — | Lag_1 BPJSTK - PHK |
| `lag1_bpjstk_jht_phk_y` | Lag_1 BPJSTK - JHT PHK | province | annual | — | Lag_1 BPJSTK - JHT PHK |
| `lag1_bpjstk_jkp_phk_y` | Lag_1 BPJSTK - JKP PHK | province | annual | — | Lag_1 BPJSTK - JKP PHK |

### Differenced (derived) (2)

| Variable | Source name | Level | Frequency | Unit | Description |
| --- | --- | --- | --- | --- | --- |
| `diffgr_input_minus_output_y` | Selisih Pertumbuhan Biaya Input dan Pertumbuhan Nilai Output | province | annual | percent (growth) | Selisih Pertumbuhan Biaya Input dan Pertumbuhan Nilai Output |
| `diffgr_laborcost_minus_output_y` | Selisih Pertumbuhan Biaya Pekerja dan Nilai Output | province | annual | percent (growth) | Selisih Pertumbuhan Biaya Pekerja dan Nilai Output |
