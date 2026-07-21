*==============================================================
* 01_build_phk_master.do  -  clean PHK master panel (Stata build)
*   data/raw/data_untuk_phk_dashboard.xlsx  ->  data/clean/phk_master.csv
* Grain: one row = province x month. Coverage 2022-2026 (38 x 60 = 2,280).
* NAME-BASED column mapping (hrn): columns are matched by their Excel HEADER
* TEXT, not position -> adding/reordering columns in the workbook no longer breaks
* the build. Per-sector % PDRB shares (17 sectors) are read directly; the services
* aggregate macro_pdrb_svc_share_pct_y is derived as the sum of the 11 service sectors.
* Workbook is split province vs national: national indicators (PMI, BI Rate, Kurs,
* Brent, IHPB, national GDP/PDB, World GDP, Federal Funds Rate) come from the three
* "(..., Nasional)" sheets and are merged by period (section 3b/5). Annual & quarterly
* raw cover 2022-2025; monthly covers 2022-2026.
* Requires Stata 14+.  Run:  do code/01_build_phk_master.do
*==============================================================
version 14
clear all
set more off
global REPO  "/Users/auliamuthia/phk_dashboard"
global RAW   "$REPO/data/raw"
global CLEAN "$REPO/data/clean"
global PHK   "$RAW/data_untuk_phk_dashboard.xlsx"
capture mkdir "$CLEAN"

*==============================================================
* 0. Province x month skeleton: 2022-01 .. 2026-12 (60 months)
*==============================================================
clear
set obs 60
gen long i   = _n
gen year     = 2022 + floor((i-1)/12)
gen month    = mod(i-1,12) + 1
gen quarter  = floor((month-1)/3) + 1
drop i
tempfile yearmonth
save `yearmonth'

*--- helper: rename the column whose row-1 header EXACTLY matches (name-based, position-proof) ---
capture program drop hrn
program define hrn
    syntax anything(name=newname), Header(string)
    * normalize target: newlines/tabs -> space, collapse blanks, trim
    local tgt = strtrim(itrim(subinstr(subinstr(subinstr(`"`header'"',char(10)," ",.),char(13)," ",.),char(9)," ",.)))
    local found 0
    foreach v of varlist _all {
        local h = `v'[1]
        local h = strtrim(itrim(subinstr(subinstr(subinstr(`"`h'"',char(10)," ",.),char(13)," ",.),char(9)," ",.)))
        if `"`h'"' == `"`tgt'"' {
            rename `v' `newname'
            local found 1
            continue, break
        }
    }
    if `found'==0 di as error "  hrn: HEADER NOT FOUND -> `header'"
end

*==============================================================
* 1. Monthly sheet (Database Bulan)  -- name-based renames
*==============================================================
import excel using "$PHK", sheet("Database (Bulan)") clear
hrn province_name, header("Provinsi")
hrn province_code, header("Kode Provinsi")
hrn year, header("Tahun")
hrn month, header("Bulan")
hrn phk_stock, header("PHK (Stock)")
hrn phk_flow, header("PHK (Flow)")
* NOTE: national indicators (PMI, BI Rate, Kurs, Brent, IHPB, Fed Funds) now live
* in the "Database (Bulan, Nasional)" sheet and are merged in at section 3b/5.
hrn price_cpi_index, header("IHK (2010=100)")
hrn price_inflation_mom_pct, header("Inflasi Bulanan (M-to-M)")
hrn price_inflation_yoy_pct, header("Inflasi Tahunan (Y-on-Y)")
hrn price_consumer_change_pct, header("Perubahan Harga Konsumen (persen, YoY)")
hrn trade_export_value, header("Nilai Ekspor (USD juta)")
hrn trade_import_value, header("Nilai Impor (USD juta)")
hrn trade_balance, header("Neraca Perdagangan (USD juta)")
hrn fin_total_credit_idr_billion, header("Total Kredit (IDR miliar)")
hrn fin_npl_idr_billion, header("NPL (IDR miliar)")
hrn fin_npl_ratio_pct, header("NPL Ratio")
keep province_name ///
     province_code year month phk_stock phk_flow price_cpi_index ///
     price_inflation_mom_pct price_inflation_yoy_pct price_consumer_change_pct ///
     trade_export_value trade_import_value trade_balance fin_total_credit_idr_billion ///
     fin_npl_idr_billion fin_npl_ratio_pct
drop in 1
replace province_name = strtrim(province_name)
ds province_name province_code, not
destring `r(varlist)', replace force
drop if missing(year)
gen province_name_std = strtrim(province_name)
drop if province_name_std == ""
keep if inrange(year,2022,2026)
drop province_name province_code
duplicates drop province_name_std year month, force
order province_name_std year month
tempfile monthly
save `monthly'

*==============================================================
* 2. Annual sheet (Database Tahun)  -- name-based renames + 17 sector shares
*==============================================================
import excel using "$PHK", sheet("Database (Tahun)") clear
hrn province_name, header("Provinsi")
hrn province_code, header("Kode Provinsi")
hrn year, header("Tahun")
hrn phk_y, header("PHK")
hrn lab_formal_share_pct_y, header("% Pekerja Formal")
hrn lab_formal_share_2019_pct_y, header("% Pekerja Formal (2019)")
hrn lab_formal_share_chg_vs2019_y, header("% Pekerja Formal (Growth from 2019, pp)")
hrn lab_contract_workers_y, header("Jumlah Pekerja Memiliki Kontrak Tertulis")
hrn lab_formal_workers_y, header("Jumlah Pekerja Formal")
hrn lab_contract_share_pct_y, header("% Pekerja Memiliki Kontrak Tertulis")
hrn lab_contract_share_2019_pct_y, header("% Pekerja Memiliki Kontrak Tertulis (2019)")
hrn lab_contract_share_chg_vs2019_y, header("% Pekerja Memiliki Kontrak Tertulis (Growth from 2019, pp)")
hrn lab_working_pop_y, header("Jumlah Penduduk Bekerja")
hrn lab_tpt_pct_y, header("% TPT")
hrn lab_tpt_male_pct_y, header("% TPT Laki-laki")
hrn lab_tpt_female_pct_y, header("% TPT Perempuan")
hrn lab_tpak_pct_y, header("% TPAK")
hrn lab_tpak_male_pct_y, header("% TPAK Laki-laki")
hrn lab_tpak_female_pct_y, header("% TPAK Perempuan")
hrn lab_self_employed_y, header("Berusaha Sendiri")
hrn lab_employee_count_y, header("Buruh/karyawan/pegawai")
hrn lab_unpaid_family_y, header("Pekerja Keluarga Tidak Dibayar")
hrn lab_underemployed_workers_y, header("Penduduk Bekerja Setengah Penganggur")
hrn lab_full_time_share_pct_y, header("% Pekerja Penuh Waktu")
hrn lab_part_time_share_pct_y, header("% Pekerja Paruh Waktu")
hrn lab_underemp_share_pct_y, header("% Setengah Pengangguran")
hrn emp_agri_y, header("Tenaga Kerja - Pertanian, Kehutanan dan Perikanan")
hrn emp_mining_y, header("Tenaga Kerja - Pertambangan dan Penggalian")
hrn emp_manuf_y, header("Tenaga Kerja - Industri Pengolahan")
hrn emp_electricity_y, header("Tenaga Kerja - Pengadaan Listrik dan Gas")
hrn emp_water_waste_y, header("Tenaga Kerja - Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang")
hrn emp_construction_y, header("Tenaga Kerja - Konstruksi")
hrn emp_trade_y, header("Tenaga Kerja - Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor")
hrn emp_transport_y, header("Tenaga Kerja - Transportasi dan Pergudangan")
hrn emp_accom_food_y, header("Tenaga Kerja - Penyediaan Akomodasi dan Makan Minum")
hrn emp_info_comm_y, header("Tenaga Kerja - Informasi dan Komunikasi")
hrn emp_finance_y, header("Tenaga Kerja - Jasa Keuangan dan Asuransi")
hrn emp_real_estate_y, header("Tenaga Kerja - Real Estate")
hrn emp_business_svc_y, header("Tenaga Kerja - Jasa Perusahaan")
hrn emp_public_admin_y, header("Tenaga Kerja - Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib")
hrn emp_education_y, header("Tenaga Kerja - Jasa Pendidikan")
hrn emp_health_y, header("Tenaga Kerja - Jasa Kesehatan dan Kegiatan Sosial")
hrn emp_other_svc_y, header("Tenaga Kerja - Jasa Lainnya")
hrn emp_share_agri_pct_y, header("% Share Tenaga Kerja - Pertanian, Kehutanan dan Perikanan")
hrn emp_share_mining_pct_y, header("% Share Tenaga Kerja - Pertambangan dan Penggalian")
hrn emp_share_manuf_pct_y, header("% Share Tenaga Kerja - Industri Pengolahan")
hrn emp_share_electricity_pct_y, header("% Share Tenaga Kerja - Pengadaan Listrik dan Gas")
hrn emp_share_water_waste_pct_y, header("% Share Tenaga Kerja - Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang")
hrn emp_share_construction_pct_y, header("% Share Tenaga Kerja - Konstruksi")
hrn emp_share_trade_pct_y, header("% Share Tenaga Kerja - Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor")
hrn emp_share_transport_pct_y, header("% Share Tenaga Kerja - Transportasi dan Pergudangan")
hrn emp_share_accom_food_pct_y, header("% Share Tenaga Kerja - Penyediaan Akomodasi dan Makan Minum")
hrn emp_share_info_comm_pct_y, header("% Share Tenaga Kerja - Informasi dan Komunikasi")
hrn emp_share_finance_pct_y, header("% Share Tenaga Kerja - Jasa Keuangan dan Asuransi")
hrn emp_share_real_estate_pct_y, header("% Share Tenaga Kerja - Real Estate")
hrn emp_share_business_svc_pct_y, header("% Share Tenaga Kerja - Jasa Perusahaan")
hrn emp_share_public_admin_pct_y, header("% Share Tenaga Kerja - Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib")
hrn emp_share_education_pct_y, header("% Share Tenaga Kerja - Jasa Pendidikan")
hrn emp_share_health_pct_y, header("% Share Tenaga Kerja - Jasa Kesehatan dan Kegiatan Sosial")
hrn emp_share_other_svc_pct_y, header("% Share Tenaga Kerja - Jasa Lainnya")
hrn lab_working_hours_y, header("Jam Kerja")
hrn wage_ump_idr_y, header("UMP (IDR)")
hrn wage_ump_growth_pct_y, header("Growth UMP")
hrn wage_avg_employee_idr_y, header("Upah buruh/karyawan/pegawai (IDR)")
hrn wage_kaitz_index_y, header("Kaitz Index")
hrn lab_nonagri_informal_share_pct_y, header("Proporsi Lapangan Kerja Informal Sektor Non-Pertanian")
hrn lab_informal_share_pct_y, header("Proporsi Lapangan Kerja Informal")
hrn lab_job_seekers_y, header("Pencari Kerja Terdaftar - Jumlah")
hrn lab_vacancies_registered_y, header("Lowongan Kerja Terdaftar - Jumlah")
hrn lab_placements_registered_y, header("Penempatan/Pemenuhan Tenaga Kerja - Jumlah")
hrn bpjstk_active_pu_y, header("BPJSTK - Peserta Aktif PU")
hrn bpjstk_active_bpu_y, header("BPJSTK - Peserta Aktif BPU")
hrn bpjstk_phk_y, header("BPJSTK - PHK")
hrn bpjstk_jht_phk_y, header("BPJSTK - JHT PHK")
hrn bpjstk_jkp_phk_y, header("BPJSTK - JKP PHK")
hrn growth_lab_working_pop_y, header("Pertumbuhan Bekerja")
hrn growth_lab_employee_count_y, header("Pertumbuhan Buruh/Karyawan/Pegawai")
hrn growth_lab_unpaid_family_y, header("Pertumbuhan Pekerja Keluarga Tidak Dibayar")
hrn growth_lab_formal_share_pct_y, header("Pertumbuhan % Pekerja Formal")
hrn growth_lab_contract_share_pct_y, header("Pertumbuhan % Pekerja Memiliki Kontrak Tertulis")
hrn growth_lab_full_time_share_pct_y, header("Pertumbuhan % Pekerja Penuh Waktu")
hrn growth_lab_part_time_share_pct_y, header("Pertumbuhan % Pekerja Paruh Waktu")
hrn growth_lab_underemp_share_pct_y, header("Pertumbuhan % Setengah Pengangguran")
hrn growth_lab_working_hours_y, header("Pertumbuhan Jam Kerja")
hrn growth_lab_tpt_pct_y, header("Pertumbuhan TPT")
hrn growth_lab_tpt_male_pct_y, header("Pertumbuhan TPT Laki-laki")
hrn growth_lab_tpt_female_pct_y, header("Pertumbuhan TPT Perempuan")
hrn growth_lab_tpak_pct_y, header("Pertumbuhan TPAK")
hrn growth_lab_tpak_male_pct_y, header("Pertumbuhan TPAK Laki-laki")
hrn growth_lab_tpak_female_pct_y, header("Pertumbuhan TPAK Perempuan")
hrn growth_wage_avg_employee_y, header("Pertumbuhan Upah")
hrn growth_bpjstk_active_pu_y, header("Pertumbuhan BPJSTK - Peserta Aktif PU")
hrn growth_bpjstk_active_bpu_y, header("Pertumbuhan BPJSTK - Peserta Aktif BPU")
hrn growth_bpjstk_phk_y, header("Pertumbuhan BPJSTK - PHK")
hrn growth_bpjstk_jht_phk_y, header("Pertumbuhan BPJSTK - JHT PHK")
hrn growth_bpjstk_jkp_phk_y, header("Pertumbuhan BPJSTK - JKP PHK")
hrn lag1_phk_y, header("Lag_1 PHK")
hrn lag1_lab_formal_share_pct_y, header("Lag_1 % Pekerja Formal")
hrn lag1_lab_contract_share_pct_y, header("Lag_1 % Pekerja Memiliki Kontrak Tertulis")
hrn lag1_wage_ump_growth_pct_y, header("Lag_1 Growth UMP")
hrn lag1_bpjstk_active_pu_y, header("Lag_1 BPJSTK - Peserta Aktif PU")
hrn lag1_bpjstk_active_bpu_y, header("Lag_1 BPJSTK - Peserta Aktif BPU")
hrn lag1_bpjstk_phk_y, header("Lag_1 BPJSTK - PHK")
hrn lag1_bpjstk_jht_phk_y, header("Lag_1 BPJSTK - JHT PHK")
hrn lag1_bpjstk_jkp_phk_y, header("Lag_1 BPJSTK - JKP PHK")
hrn lab_unemployed_y, header("Jumlah Pengangguran")
hrn lab_unemployed_youth_y, header("Jumlah Penganggur Usia Muda (15-24 tahun)")
hrn lab_unemployed_edu_y, header("Jumlah Penganggur Terdidik (S1/Diploma ke atas)")
hrn lab_unemployed_youth_share_pct_y, header("% Share Penganggur Usia Muda (15-24 tahun)")
hrn lab_unemployed_edu_share_pct_y, header("% Share Penganggur Terdidik (S1/Diploma ke atas)")
hrn lab_above_minwage_share_pct_y, header("% Pekerja di atas UM")
hrn ind_firms_medium_y, header("Perusahaan Industri Sedang")
hrn ind_firms_large_y, header("Perusahaan Industri Besar")
hrn ind_firms_total_y, header("Jumlah Perusahaan")
hrn ind_workers_medium_y, header("Tenaga Kerja Industri Sedang")
hrn ind_workers_large_y, header("Tenaga Kerja Industri Besar")
hrn ind_workers_prod_y, header("Jumlah Tenaga Kerja Produksi")
hrn ind_workers_nonprod_y, header("Jumlah Tenaga Kerja Lainnya")
hrn ind_workers_total_y, header("Jumlah Tenaga Kerja")
hrn ind_prod_workers_wage_cost_y, header("Pengeluaran untuk Pekerja Produksi Upah/Gaji, Upah Lembur, Tunjangan")
hrn ind_prod_workers_other_cost_y, header("Pengeluaran untuk Pekerja Produksi Lainnya")
hrn ind_prod_workers_total_cost_y, header("Jumlah Pengeluaran untuk Pekerja Produksi")
hrn ind_nonprod_workers_wage_cost_y, header("Pengeluaran untuk Pekerja Lainnya Upah/Gaji, Upah Lembur, Tunjangan")
hrn ind_nonprod_workers_other_cost_y, header("Pengeluaran untuk Pekerja Lainnya Lainnya")
hrn ind_nonprod_workers_total_cost_y, header("Jumlah Pengeluaran untuk Pekerja Lainnya")
hrn ind_laborcost_total_y, header("Jumlah Pengeluaran Seluruh Pekerja")
hrn ind_input_y, header("Biaya Input")
hrn ind_output_y, header("Nilai Output")
hrn ind_va_mkt_y, header("Nilai Tambah (harga pasar)")
hrn ind_va_fc_y, header("Nilai Tambah (biaya faktor produksi)")
hrn ind_firms_pmdn_y, header("Jumlah Perusahaan PMDN")
hrn ind_firms_pma_y, header("Jumlah Perusahaan PMA")
hrn ind_workers_per_firm_y, header("Jumlah Tenaga Kerja/Jumlah Perusahaan")
hrn ind_prod_worker_share_y, header("Jumlah Tenaga Kerja Produksi/Jumlah Tenaga Kerja")
hrn ind_workers_per_input_y, header("Jumlah Tenaga Kerja/Biaya Input")
hrn ind_workers_per_output_y, header("Jumlah Tenaga Kerja/Nilai Output")
hrn ind_workers_per_va_mkt_y, header("Jumlah Tenaga Kerja/Nilai Tambah (harga pasar)")
hrn ind_workers_per_va_fc_y, header("Jumlah Tenaga Kerja/Nilai Tambah (biaya faktor produksi)")
hrn ind_laborcost_share_input_y, header("Biaya Pekerja/Biaya Input")
hrn ind_laborcost_share_output_y, header("Biaya Pekerja/Nilai Output")
hrn ind_laborcost_share_va_mkt_y, header("Biaya Pekerja/Nilai Tambah Pasar")
hrn ind_laborcost_share_va_fc_y, header("Biaya Pekerja/Nilai Tambah Produksi")
hrn ind_laborcost_per_wkr_y, header("Biaya Pekerja/Tenaga Kerja")
hrn ind_output_per_wkr_y, header("Nilai Output/Tenaga Kerja")
hrn ind_va_mkt_per_wkr_y, header("Nilai Tambah Pasar/Tenaga Kerja")
hrn ind_va_fc_per_wkr_y, header("Nilai Tambah Produksi/Tenaga Kerja")
hrn ind_input_share_output_y, header("Biaya Input/Nilai Output")
hrn ind_va_mkt_share_output_y, header("Nilai Tambah Pasar/Nilai Output")
hrn ind_va_fc_share_output_y, header("Nilai Tambah Produksi/Nilai Output")
hrn ind_prod_laborcost_share_y, header("Biaya Pekerja Produksi/Total Biaya Pekerja")
hrn ind_nonprod_laborcost_share_y, header("Biaya Pekerja Lainnya/Total Biaya Pekerja")
hrn ind_prod_wage_per_wkr_y, header("Upah Pekerja Produksi/Jumlah Tenaga Kerja Produksi")
hrn ind_nonprod_wage_per_wkr_y, header("Upah Pekerja Lainnya/Jumlah Tenaga Kerja Lainnya")
hrn ind_firms_pmdn_share_y, header("Proporsi Perusahaan PMDN")
hrn ind_firms_pma_share_y, header("Proporsi Perusahaan PMA")
hrn growth_ind_output_y, header("Pertumbuhan Nilai Output")
hrn growth_ind_input_y, header("Pertumbuhan Biaya Input")
hrn growth_ind_va_mkt_y, header("Pertumbuhan Nilai Tambah Pasar")
hrn growth_ind_va_fc_y, header("Pertumbuhan Nilai Tambah Produksi")
hrn growth_ind_workers_total_y, header("Pertumbuhan Tenaga Kerja")
hrn growth_ind_firms_total_y, header("Pertumbuhan Jumlah Perusahaan")
hrn growth_ind_laborcost_total_y, header("Pertumbuhan Pengeluaran Tenaga Kerja")
hrn growth_ind_labor_prod_market_y, header("Pertumbuhan Produktivitas (Nilai Tambah Pasar) Tenaga Kerja")
hrn growth_ind_labor_prod_fc_y, header("Pertumbuhan Produktivitas (Nilai Tambah Produksi) Tenaga Kerja")
hrn diffgr_input_minus_output_y, header("Selisih Pertumbuhan Biaya Input dan Pertumbuhan Nilai Output")
hrn diffgr_laborcost_minus_output_y, header("Selisih Pertumbuhan Biaya Pekerja dan Nilai Output")
hrn macro_pdrb_idr_billion_y, header("PDRB (IDR milyar)")
hrn macro_pdrb_idr_million_y, header("PDRB (IDR juta)")
hrn growth_pdrb_pct_y, header("Laju Pertumbuhan PDRB")
hrn macro_pdrb_agri_y, header("PDRB Pertanian, Kehutanan dan Perikanan (IDR milyar)")
hrn macro_pdrb_mining_y, header("PDRB Pertambangan dan Penggalian (IDR milyar)")
hrn macro_pdrb_manuf_y, header("PDRB Industri Pengolahan (IDR milyar)")
hrn macro_pdrb_electricity_y, header("PDRB Pengadaan Listrik dan Gas (IDR milyar)")
hrn macro_pdrb_water_waste_y, header("PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang (IDR milyar)")
hrn macro_pdrb_construction_y, header("PDRB Konstruksi (IDR milyar)")
hrn macro_pdrb_trade_y, header("PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor (IDR milyar)")
hrn macro_pdrb_transport_y, header("PDRB Transportasi dan Pergudangan (IDR milyar)")
hrn macro_pdrb_accom_food_y, header("PDRB Penyediaan Akomodasi dan Makan Minum (IDR milyar)")
hrn macro_pdrb_info_comm_y, header("PDRB Informasi dan Komunikasi (IDR milyar)")
hrn macro_pdrb_finance_y, header("PDRB Jasa Keuangan dan Asuransi (IDR milyar)")
hrn macro_pdrb_real_estate_y, header("PDRB Real Estate (IDR milyar)")
hrn macro_pdrb_business_svc_y, header("PDRB Jasa Perusahaan (IDR milyar)")
hrn macro_pdrb_public_admin_y, header("PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib (IDR milyar)")
hrn macro_pdrb_education_y, header("PDRB Jasa Pendidikan (IDR milyar)")
hrn macro_pdrb_health_y, header("PDRB Jasa Kesehatan dan Kegiatan Sosial (IDR milyar)")
hrn macro_pdrb_other_svc_y, header("PDRB Jasa Lainnya (IDR milyar)")
hrn macro_pdrb_manuf_growth_pct_y, header("Laju Pertumbuhan PDB Industri Manufaktur")
hrn macro_pdrb_per_wkr_y, header("PDRB/Pekerja")
hrn macro_pdrb_per_wkr_growth_pct_y, header("Laju Pertumbuhan PDB Per Tenaga Kerja")
hrn macro_pdrb_pcap_idr_thousand_y, header("PDRB Per Kapita (Ribu Rupiah)")
hrn growth_pdrb_pcap_pct_y, header("Laju Pertumbuhan PDRB Per Kapita (Persen)")
* NOTE: national annual indicators (PMI, IHP, IHK, price changes, BI Rate, Kurs)
* now live in "Database (Tahun, Nasional)" -> merged in at section 3b/5.
hrn fin_fdi_y, header("FDI")
hrn price_inflation_yoy_q4_pct_y, header("Inflasi YoY (per IV)")
hrn price_inflation_yoy_avg_pct_y, header("Inflasi YoY (Average)")
hrn trade_export_value_bps_y, header("Nilai Ekspor BPS (USD juta)")
hrn trade_export_value_y, header("Nilai Ekspor (USD juta)")
hrn trade_import_value_y, header("Nilai Impor (USD juta)")
hrn trade_balance_y, header("Neraca Perdagangan")
hrn fin_total_credit_idr_billion_y, header("Total Credits, End of Year (IDR miliar)")
hrn fin_npl_y, header("NPL, End of Year (IDR miliar)")
hrn fin_npl_ratio_pct_y, header("NPL Ratio, End of Year")
hrn fin_npl_ratio_2020_pct_y, header("NPL Ratio, End of Year (2020)")
hrn fin_npl_ratio_2021_pct_y, header("NPL Ratio, End of Year (2021)")
hrn macro_construction_cost_index_y, header("Indeks Kemahalan Konstruksi")
hrn macro_pdrb_hh_cons_share_pct_y, header("Persentase Pengeluaran Konsumsi Rumah Tangga Atas Dasar Harga Berlaku (persen)")
hrn macro_pdrb_gov_cons_share_pct_y, header("Persentase Pengeluaran Konsumsi Pemerintah Atas Dasar Harga Berlaku (persen)")
hrn macro_pdrb_invest_share_pct_y, header("Persentase Pembentukan Modal Tetap Bruto Atas Dasar Harga Berlaku (persen)")
hrn pov_line_idr_y, header("Garis Kemiskinan - Maret (Rp)")
hrn pov_headcount_thousand_y, header("Jumlah Penduduk Miskin - Maret (ribu) (Ribu)")
hrn pov_rate_pct_y, header("Persentase Penduduk Miskin - Maret")
* --- 17 per-sector PDRB shares (new, annual) ---
hrn macro_pdrb_agri_share_pct_y, header("% PDRB Pertanian, Kehutanan dan Perikanan")
hrn macro_pdrb_mining_shr_y, header("% PDRB Pertambangan dan Penggalian")
hrn macro_pdrb_manuf_share_pct_y, header("% PDRB Industri Pengolahan")
hrn macro_pdrb_electricity_shr_y, header("% PDRB Pengadaan Listrik dan Gas")
hrn macro_pdrb_water_waste_shr_y, header("% PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang")
hrn macro_pdrb_construction_shr_y, header("% PDRB Konstruksi")
hrn macro_pdrb_trade_shr_y, header("% PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor")
hrn macro_pdrb_transport_shr_y, header("% PDRB Transportasi dan Pergudangan")
hrn macro_pdrb_accom_food_shr_y, header("% PDRB Penyediaan Akomodasi dan Makan Minum")
hrn macro_pdrb_info_comm_shr_y, header("% PDRB Informasi dan Komunikasi")
hrn macro_pdrb_finance_shr_y, header("% PDRB Jasa Keuangan dan Asuransi")
hrn macro_pdrb_real_estate_shr_y, header("% PDRB Real Estate")
hrn macro_pdrb_business_svc_shr_y, header("% PDRB Jasa Perusahaan")
hrn macro_pdrb_public_admin_shr_y, header("% PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib")
hrn macro_pdrb_education_shr_y, header("% PDRB Jasa Pendidikan")
hrn macro_pdrb_health_shr_y, header("% PDRB Jasa Kesehatan dan Kegiatan Sosial")
hrn macro_pdrb_other_svc_shr_y, header("% PDRB Jasa Lainnya")
keep province_name ///
     province_code year phk_y lab_formal_share_pct_y lab_formal_share_2019_pct_y ///
     lab_formal_share_chg_vs2019_y lab_contract_workers_y lab_formal_workers_y ///
     lab_contract_share_pct_y lab_contract_share_2019_pct_y lab_contract_share_chg_vs2019_y ///
     lab_working_pop_y lab_tpt_pct_y lab_tpt_male_pct_y lab_tpt_female_pct_y lab_tpak_pct_y ///
     lab_tpak_male_pct_y lab_tpak_female_pct_y lab_self_employed_y lab_employee_count_y ///
     lab_unpaid_family_y lab_underemployed_workers_y lab_full_time_share_pct_y ///
     lab_part_time_share_pct_y lab_underemp_share_pct_y emp_agri_y emp_mining_y emp_manuf_y ///
     emp_electricity_y emp_water_waste_y emp_construction_y emp_trade_y emp_transport_y ///
     emp_accom_food_y emp_info_comm_y emp_finance_y emp_real_estate_y emp_business_svc_y ///
     emp_public_admin_y emp_education_y emp_health_y emp_other_svc_y emp_share_agri_pct_y ///
     emp_share_mining_pct_y emp_share_manuf_pct_y emp_share_electricity_pct_y ///
     emp_share_water_waste_pct_y emp_share_construction_pct_y emp_share_trade_pct_y ///
     emp_share_transport_pct_y emp_share_accom_food_pct_y emp_share_info_comm_pct_y ///
     emp_share_finance_pct_y emp_share_real_estate_pct_y emp_share_business_svc_pct_y ///
     emp_share_public_admin_pct_y emp_share_education_pct_y emp_share_health_pct_y ///
     emp_share_other_svc_pct_y lab_working_hours_y wage_ump_idr_y wage_ump_growth_pct_y ///
     wage_avg_employee_idr_y wage_kaitz_index_y lab_nonagri_informal_share_pct_y ///
     lab_informal_share_pct_y lab_job_seekers_y lab_vacancies_registered_y ///
     lab_placements_registered_y bpjstk_active_pu_y bpjstk_active_bpu_y bpjstk_phk_y ///
     bpjstk_jht_phk_y bpjstk_jkp_phk_y growth_lab_working_pop_y growth_lab_employee_count_y ///
     growth_lab_unpaid_family_y growth_lab_formal_share_pct_y growth_lab_contract_share_pct_y ///
     growth_lab_full_time_share_pct_y growth_lab_part_time_share_pct_y ///
     growth_lab_underemp_share_pct_y growth_lab_working_hours_y growth_lab_tpt_pct_y ///
     growth_lab_tpt_male_pct_y growth_lab_tpt_female_pct_y growth_lab_tpak_pct_y ///
     growth_lab_tpak_male_pct_y growth_lab_tpak_female_pct_y growth_wage_avg_employee_y ///
     growth_bpjstk_active_pu_y growth_bpjstk_active_bpu_y growth_bpjstk_phk_y ///
     growth_bpjstk_jht_phk_y growth_bpjstk_jkp_phk_y lag1_phk_y lag1_lab_formal_share_pct_y ///
     lag1_lab_contract_share_pct_y lag1_wage_ump_growth_pct_y lag1_bpjstk_active_pu_y ///
     lag1_bpjstk_active_bpu_y lag1_bpjstk_phk_y lag1_bpjstk_jht_phk_y lag1_bpjstk_jkp_phk_y ///
     lab_unemployed_y lab_unemployed_youth_y lab_unemployed_edu_y ///
     lab_unemployed_youth_share_pct_y lab_unemployed_edu_share_pct_y ///
     lab_above_minwage_share_pct_y ind_firms_medium_y ///
     ind_firms_large_y ind_firms_total_y ind_workers_medium_y ind_workers_large_y ///
     ind_workers_prod_y ind_workers_nonprod_y ind_workers_total_y ind_prod_workers_wage_cost_y ///
     ind_prod_workers_other_cost_y ind_prod_workers_total_cost_y ///
     ind_nonprod_workers_wage_cost_y ind_nonprod_workers_other_cost_y ///
     ind_nonprod_workers_total_cost_y ind_laborcost_total_y ind_input_y ind_output_y ///
     ind_va_mkt_y ind_va_fc_y ind_firms_pmdn_y ind_firms_pma_y ind_workers_per_firm_y ///
     ind_prod_worker_share_y ind_workers_per_input_y ind_workers_per_output_y ///
     ind_workers_per_va_mkt_y ind_workers_per_va_fc_y ind_laborcost_share_input_y ///
     ind_laborcost_share_output_y ind_laborcost_share_va_mkt_y ind_laborcost_share_va_fc_y ///
     ind_laborcost_per_wkr_y ind_output_per_wkr_y ind_va_mkt_per_wkr_y ind_va_fc_per_wkr_y ///
     ind_input_share_output_y ind_va_mkt_share_output_y ind_va_fc_share_output_y ///
     ind_prod_laborcost_share_y ind_nonprod_laborcost_share_y ind_prod_wage_per_wkr_y ///
     ind_nonprod_wage_per_wkr_y ind_firms_pmdn_share_y ind_firms_pma_share_y ///
     growth_ind_output_y growth_ind_input_y growth_ind_va_mkt_y growth_ind_va_fc_y ///
     growth_ind_workers_total_y growth_ind_firms_total_y growth_ind_laborcost_total_y ///
     growth_ind_labor_prod_market_y growth_ind_labor_prod_fc_y diffgr_input_minus_output_y ///
     diffgr_laborcost_minus_output_y macro_pdrb_idr_billion_y macro_pdrb_idr_million_y ///
     growth_pdrb_pct_y macro_pdrb_agri_y macro_pdrb_mining_y macro_pdrb_manuf_y ///
     macro_pdrb_electricity_y macro_pdrb_water_waste_y macro_pdrb_construction_y ///
     macro_pdrb_trade_y macro_pdrb_transport_y macro_pdrb_accom_food_y macro_pdrb_info_comm_y ///
     macro_pdrb_finance_y macro_pdrb_real_estate_y macro_pdrb_business_svc_y ///
     macro_pdrb_public_admin_y macro_pdrb_education_y macro_pdrb_health_y ///
     macro_pdrb_other_svc_y macro_pdrb_manuf_growth_pct_y macro_pdrb_per_wkr_y ///
     macro_pdrb_per_wkr_growth_pct_y macro_pdrb_pcap_idr_thousand_y growth_pdrb_pcap_pct_y ///
     fin_fdi_y price_inflation_yoy_q4_pct_y price_inflation_yoy_avg_pct_y ///
     trade_export_value_bps_y trade_export_value_y ///
     trade_import_value_y trade_balance_y fin_total_credit_idr_billion_y fin_npl_y ///
     fin_npl_ratio_pct_y fin_npl_ratio_2020_pct_y fin_npl_ratio_2021_pct_y ///
     macro_construction_cost_index_y ///
     macro_pdrb_hh_cons_share_pct_y macro_pdrb_gov_cons_share_pct_y ///
     macro_pdrb_invest_share_pct_y pov_line_idr_y pov_headcount_thousand_y pov_rate_pct_y ///
     macro_pdrb_agri_share_pct_y macro_pdrb_mining_shr_y macro_pdrb_manuf_share_pct_y ///
     macro_pdrb_electricity_shr_y macro_pdrb_water_waste_shr_y ///
     macro_pdrb_construction_shr_y macro_pdrb_trade_shr_y ///
     macro_pdrb_transport_shr_y macro_pdrb_accom_food_shr_y ///
     macro_pdrb_info_comm_shr_y macro_pdrb_finance_shr_y ///
     macro_pdrb_real_estate_shr_y macro_pdrb_business_svc_shr_y ///
     macro_pdrb_public_admin_shr_y macro_pdrb_education_shr_y ///
     macro_pdrb_health_shr_y macro_pdrb_other_svc_shr_y
drop in 1
replace province_name = strtrim(province_name)
ds province_name province_code, not
destring `r(varlist)', replace force
* derive services-aggregate % PDRB share (sum of the 11 service sectors)
egen double macro_pdrb_svc_share_pct_y = rowtotal(macro_pdrb_trade_shr_y macro_pdrb_transport_shr_y macro_pdrb_accom_food_shr_y macro_pdrb_info_comm_shr_y macro_pdrb_finance_shr_y macro_pdrb_real_estate_shr_y macro_pdrb_business_svc_shr_y macro_pdrb_public_admin_shr_y macro_pdrb_education_shr_y macro_pdrb_health_shr_y macro_pdrb_other_svc_shr_y), missing
drop if missing(year)
gen province_name_std = strtrim(province_name)
drop if province_name_std == ""
keep if inrange(year,2022,2026)
* province_code lookup (kept as TEXT, one row per province) -> merged onto the master
tempfile provcode
preserve
    keep province_name_std province_code
    drop if missing(province_code)
    duplicates drop
    tostring province_code, replace force
    save `provcode'
restore
drop province_name province_code
duplicates drop province_name_std year, force
order province_name_std year
tempfile annual
save `annual'

*==============================================================
* 3. Quarterly sheet (Database Triwulan)  -- name-based renames + 17 sector shares
*==============================================================
import excel using "$PHK", sheet("Database (Triwulan)") clear
hrn province_name, header("Provinsi")
hrn province_code, header("Kode Provinsi")
hrn year, header("Tahun")
hrn quarter, header("Triwulan")
hrn quarter_end_month_label, header("Bulan")
hrn phk_stock_q, header("PHK (Stock)")
hrn phk_flow_q, header("PHK (Flow)")
hrn macro_pdrb_q, header("PDRB (IDR milyar)")
hrn macro_pdrb_agri_q, header("PDRB Pertanian, Kehutanan dan Perikanan (IDR milyar)")
hrn macro_pdrb_mining_q, header("PDRB Pertambangan dan Penggalian (IDR milyar)")
hrn macro_pdrb_manuf_q, header("PDRB Industri Pengolahan (IDR milyar)")
hrn macro_pdrb_electricity_q, header("PDRB Pengadaan Listrik dan Gas (IDR milyar)")
hrn macro_pdrb_water_waste_q, header("PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang (IDR milyar)")
hrn macro_pdrb_construction_q, header("PDRB Konstruksi (IDR milyar)")
hrn macro_pdrb_trade_q, header("PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor (IDR milyar)")
hrn macro_pdrb_transport_q, header("PDRB Transportasi dan Pergudangan (IDR milyar)")
hrn macro_pdrb_accom_food_q, header("PDRB Penyediaan Akomodasi dan Makan Minum (IDR milyar)")
hrn macro_pdrb_info_comm_q, header("PDRB Informasi dan Komunikasi (IDR milyar)")
hrn macro_pdrb_finance_q, header("PDRB Jasa Keuangan dan Asuransi (IDR milyar)")
hrn macro_pdrb_real_estate_q, header("PDRB Real Estate (IDR milyar)")
hrn macro_pdrb_business_svc_q, header("PDRB Jasa Perusahaan (IDR milyar)")
hrn macro_pdrb_public_admin_q, header("PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib (IDR milyar)")
hrn macro_pdrb_education_q, header("PDRB Jasa Pendidikan (IDR milyar)")
hrn macro_pdrb_health_q, header("PDRB Jasa Kesehatan dan Kegiatan Sosial (IDR milyar)")
hrn macro_pdrb_other_svc_q, header("PDRB Jasa Lainnya (IDR milyar)")
* NOTE: national quarterly indicators (PMI, IHP, producer change, BI Rate, Kurs)
* now live in "Database (Triwulan, Nasional)" -> merged in at section 3b/5.
hrn fin_fdi_usd_million_q, header("FDI (USD mn)")
hrn fin_fdi_idr_million_q, header("FDI (IDR mn)")
hrn lab_working_pop_q, header("Jumlah Penduduk Bekerja")
hrn price_cpi_index_q, header("IHK (2010=100)")
hrn price_consumer_change_pct_q, header("Perubahan Harga Konsumen")
hrn trade_export_value_usd_million_q, header("Nilai Ekspor (USD juta)")
hrn trade_import_value_usd_million_q, header("Nilai Impor (USD juta)")
hrn trade_balance_usd_million_q, header("Neraca Perdagangan*")
hrn fin_total_credit_idr_billion_q, header("Total Credits, End of Quarter (IDR miliar)")
hrn fin_npl_idr_billion_q, header("NPL, End of Quarter (IDR miliar)")
hrn fin_npl_ratio_pct_q, header("NPL Ratio, End of Quarter")
* --- 17 per-sector PDRB shares (new, quarterly) ---
hrn macro_pdrb_agri_share_pct_q, header("% PDRB Pertanian, Kehutanan dan Perikanan")
hrn macro_pdrb_mining_shr_q, header("% PDRB Pertambangan dan Penggalian")
hrn macro_pdrb_manuf_share_pct_q, header("% PDRB Industri Pengolahan")
hrn macro_pdrb_electricity_shr_q, header("% PDRB Pengadaan Listrik dan Gas")
hrn macro_pdrb_water_waste_shr_q, header("% PDRB Pengadaan Air, Pengelolaan Sampah, Limbah dan Daur Ulang")
hrn macro_pdrb_construction_shr_q, header("% PDRB Konstruksi")
hrn macro_pdrb_trade_shr_q, header("% PDRB Perdagangan Besar dan Eceran, Reparasi Mobil dan Sepeda Motor")
hrn macro_pdrb_transport_shr_q, header("% PDRB Transportasi dan Pergudangan")
hrn macro_pdrb_accom_food_shr_q, header("% PDRB Penyediaan Akomodasi dan Makan Minum")
hrn macro_pdrb_info_comm_shr_q, header("% PDRB Informasi dan Komunikasi")
hrn macro_pdrb_finance_shr_q, header("% PDRB Jasa Keuangan dan Asuransi")
hrn macro_pdrb_real_estate_shr_q, header("% PDRB Real Estate")
hrn macro_pdrb_business_svc_shr_q, header("% PDRB Jasa Perusahaan")
hrn macro_pdrb_public_admin_shr_q, header("% PDRB Administrasi Pemerintahan, Pertahanan dan Jaminan Sosial Wajib")
hrn macro_pdrb_education_shr_q, header("% PDRB Jasa Pendidikan")
hrn macro_pdrb_health_shr_q, header("% PDRB Jasa Kesehatan dan Kegiatan Sosial")
hrn macro_pdrb_other_svc_shr_q, header("% PDRB Jasa Lainnya")
keep province_name ///
     province_code year quarter quarter_end_month_label phk_stock_q phk_flow_q macro_pdrb_q ///
     macro_pdrb_agri_q macro_pdrb_mining_q macro_pdrb_manuf_q macro_pdrb_electricity_q ///
     macro_pdrb_water_waste_q macro_pdrb_construction_q macro_pdrb_trade_q ///
     macro_pdrb_transport_q macro_pdrb_accom_food_q macro_pdrb_info_comm_q macro_pdrb_finance_q ///
     macro_pdrb_real_estate_q macro_pdrb_business_svc_q macro_pdrb_public_admin_q ///
     macro_pdrb_education_q macro_pdrb_health_q macro_pdrb_other_svc_q ///
     fin_fdi_usd_million_q fin_fdi_idr_million_q lab_working_pop_q price_cpi_index_q ///
     price_consumer_change_pct_q trade_export_value_usd_million_q ///
     trade_import_value_usd_million_q trade_balance_usd_million_q ///
     fin_total_credit_idr_billion_q fin_npl_idr_billion_q fin_npl_ratio_pct_q ///
     macro_pdrb_agri_share_pct_q ///
     macro_pdrb_mining_shr_q macro_pdrb_manuf_share_pct_q ///
     macro_pdrb_electricity_shr_q macro_pdrb_water_waste_shr_q ///
     macro_pdrb_construction_shr_q macro_pdrb_trade_shr_q ///
     macro_pdrb_transport_shr_q macro_pdrb_accom_food_shr_q ///
     macro_pdrb_info_comm_shr_q macro_pdrb_finance_shr_q ///
     macro_pdrb_real_estate_shr_q macro_pdrb_business_svc_shr_q ///
     macro_pdrb_public_admin_shr_q macro_pdrb_education_shr_q ///
     macro_pdrb_health_shr_q macro_pdrb_other_svc_shr_q
drop in 1
replace province_name = strtrim(province_name)
gen _q = .
replace _q = 1 if inlist(strtrim(quarter),"I","1")
replace _q = 2 if inlist(strtrim(quarter),"II","2")
replace _q = 3 if inlist(strtrim(quarter),"III","3")
replace _q = 4 if inlist(strtrim(quarter),"IV","4")
drop quarter
rename _q quarter
ds province_name province_code quarter_end_month_label quarter, not
destring `r(varlist)', replace force
* derive services-aggregate % PDRB share (quarterly)
egen double macro_pdrb_svc_share_pct_q = rowtotal(macro_pdrb_trade_shr_q macro_pdrb_transport_shr_q macro_pdrb_accom_food_shr_q macro_pdrb_info_comm_shr_q macro_pdrb_finance_shr_q macro_pdrb_real_estate_shr_q macro_pdrb_business_svc_shr_q macro_pdrb_public_admin_shr_q macro_pdrb_education_shr_q macro_pdrb_health_shr_q macro_pdrb_other_svc_shr_q), missing
drop if missing(year)
gen province_name_std = strtrim(province_name)
drop if province_name_std == ""
keep if inrange(year,2022,2026)
drop province_name province_code quarter_end_month_label
duplicates drop province_name_std year quarter, force
order province_name_std year quarter
tempfile quarterly
save `quarterly'

*==============================================================
* 3b. National indicator sheets (denormalized to province grain in the
*     workbook). Collapse each to one row per period (values are identical
*     across provinces) and merge by period only at section 5.
*==============================================================
* --- Monthly national (Database Bulan, Nasional) ---
import excel using "$PHK", sheet("Database (Bulan, Nasional)") clear
hrn year, header("Tahun")
hrn month, header("Bulan")
hrn macro_pmi_manuf_nat, header("PMI Manufaktur")
hrn macro_bi_rate_pct_nat, header("BI Rate")
hrn macro_fx_idr_usd_nat, header("Kurs")
hrn price_brent_usd_bbl_nat, header("Harga Minyak Brent (USD/barrel)")
hrn price_ihpb_nat, header("IHPB")
hrn macro_fed_funds_rate_nat, header("Federal Funds Effective Rate (Daily, 7-Day)")
keep year month macro_pmi_manuf_nat macro_bi_rate_pct_nat macro_fx_idr_usd_nat ///
     price_brent_usd_bbl_nat price_ihpb_nat macro_fed_funds_rate_nat
drop in 1
destring, replace force
collapse (mean) macro_pmi_manuf_nat macro_bi_rate_pct_nat macro_fx_idr_usd_nat ///
     price_brent_usd_bbl_nat price_ihpb_nat macro_fed_funds_rate_nat, by(year month)
tempfile monthly_nat
save `monthly_nat'

* --- Annual national (Database Tahun, Nasional) ---
import excel using "$PHK", sheet("Database (Tahun, Nasional)") clear
hrn year, header("Tahun")
hrn macro_pmi_manuf_nat_y, header("PMI Manufaktur")
hrn price_producer_index_nat_y, header("IHP (2016=100)")
hrn price_cpi_index_nat_y, header("IHK (2010=100)")
hrn price_producer_change_pct_nat_y, header("Perubahan Harga Produsen (%)")
hrn price_consumer_change_pct_nat_y, header("Perubahan Harga Konsumen (%)")
hrn macro_bi_rate_pct_nat_y, header("BI Rate")
hrn macro_fx_idr_usd_nat_y, header("Kurs")
hrn macro_pdb_idr_billion_nat_y, header("PDB (IDR milyar)")
hrn macro_world_gdp_nat_y, header("World GDP")
hrn macro_fed_funds_rate_nat_y, header("Federal Funds Effective Rate (End of Period)")
keep year macro_pmi_manuf_nat_y price_producer_index_nat_y price_cpi_index_nat_y ///
     price_producer_change_pct_nat_y price_consumer_change_pct_nat_y macro_bi_rate_pct_nat_y ///
     macro_fx_idr_usd_nat_y macro_pdb_idr_billion_nat_y macro_world_gdp_nat_y ///
     macro_fed_funds_rate_nat_y
drop in 1
destring, replace force
collapse (mean) macro_pmi_manuf_nat_y price_producer_index_nat_y price_cpi_index_nat_y ///
     price_producer_change_pct_nat_y price_consumer_change_pct_nat_y macro_bi_rate_pct_nat_y ///
     macro_fx_idr_usd_nat_y macro_pdb_idr_billion_nat_y macro_world_gdp_nat_y ///
     macro_fed_funds_rate_nat_y, by(year)
tempfile annual_nat
save `annual_nat'

* --- Quarterly national (Database Triwulan, Nasional) ---
import excel using "$PHK", sheet("Database (Triwulan, Nasional)") clear
hrn year, header("Tahun")
hrn quarter, header("Triwulan")
hrn macro_pmi_manuf_nat_q, header("PMI Manufaktur")
hrn price_producer_index_nat_q, header("IHP (2016=100)")
hrn price_producer_change_pct_nat_q, header("Perubahan Harga Produsen (%)")
hrn macro_bi_rate_pct_nat_q, header("BI Rate")
hrn macro_fx_idr_usd_nat_q, header("Kurs")
hrn macro_pdb_idr_billion_nat_q, header("PDB (IDR milyar)")
hrn macro_world_gdp_nat_q, header("World GDP")
hrn macro_fed_funds_rate_nat_q, header("Federal Funds Effective Rate (End of Period)")
keep year quarter macro_pmi_manuf_nat_q price_producer_index_nat_q ///
     price_producer_change_pct_nat_q macro_bi_rate_pct_nat_q macro_fx_idr_usd_nat_q ///
     macro_pdb_idr_billion_nat_q macro_world_gdp_nat_q macro_fed_funds_rate_nat_q
drop in 1
* normalize quarter (roman/arabic) -> 1..4
replace quarter = strtrim(quarter)
gen _q = .
replace _q = 1 if inlist(quarter,"I","1")
replace _q = 2 if inlist(quarter,"II","2")
replace _q = 3 if inlist(quarter,"III","3")
replace _q = 4 if inlist(quarter,"IV","4")
drop quarter
rename _q quarter
destring, replace force
collapse (mean) macro_pmi_manuf_nat_q price_producer_index_nat_q ///
     price_producer_change_pct_nat_q macro_bi_rate_pct_nat_q macro_fx_idr_usd_nat_q ///
     macro_pdb_idr_billion_nat_q macro_world_gdp_nat_q macro_fed_funds_rate_nat_q, by(year quarter)
tempfile quarterly_nat
save `quarterly_nat'

*==============================================================
* 4. Province list = union across the three sheets
*==============================================================
use `monthly', clear
keep province_name_std
tempfile provs
append using `annual'
append using `quarterly'
keep province_name_std
duplicates drop
save `provs'

*==============================================================
* 5. Build province-month master; monthly 1:1, quarterly m:1, annual m:1
*==============================================================
use `provs', clear
cross using `yearmonth'
gen date = string(year) + "-" + string(month,"%02.0f") + "-01"
merge m:1 province_name_std           using `provcode',  keep(master match) nogen
merge 1:1 province_name_std year month   using `monthly',   keep(master match) nogen
merge m:1 province_name_std year quarter using `quarterly', keep(master match) nogen
merge m:1 province_name_std year         using `annual',    keep(master match) nogen
* national indicators: keyed by period only (values common to all provinces)
merge m:1 year month   using `monthly_nat',   keep(master match) nogen
merge m:1 year quarter using `quarterly_nat', keep(master match) nogen
merge m:1 year         using `annual_nat',    keep(master match) nogen

*==============================================================
* 5a. Broadcast pre-panel NPL-ratio references (2020/2021) to all province rows.
*     Yearly reference values (no 2020/2021 rows exist) -> store each as a
*     province-constant so they are available for building lagged variables.
*==============================================================
foreach c in fin_npl_ratio_2020_pct_y fin_npl_ratio_2021_pct_y {
    bysort province_name_std: egen double _bc = max(`c')
    replace `c' = _bc
    drop _bc
}

*==============================================================
* 5b. Derived macro-trigger transforms (%yoy growth, ppt change, FX volatility)
*     Computed on the assembled monthly panel. L12 = 12 months back
*     (= same month last year for monthly series; same quarter for broadcast _q;
*      same year for broadcast _y). yoy needs t-12 -> 2022 missing (starts 2023).
*==============================================================
egen _provid = group(province_name_std)
gen  _tm     = ym(year, month)
tsset _provid _tm

* %yoy growth (monthly)
gen growth_brent_yoy_pct_nat = (price_brent_usd_bbl_nat/L12.price_brent_usd_bbl_nat - 1)*100
gen growth_ihpb_yoy_pct_nat  = (price_ihpb_nat/L12.price_ihpb_nat - 1)*100
gen growth_npl_yoy_pct       = (fin_npl_idr_billion/L12.fin_npl_idr_billion - 1)*100
gen growth_export_yoy_pct    = (trade_export_value/L12.trade_export_value - 1)*100
gen growth_import_yoy_pct    = (trade_import_value/L12.trade_import_value - 1)*100

* %yoy growth (quarterly, from broadcast _q columns; L12 = same quarter last year)
gen growth_export_yoy_pct_q  = (trade_export_value_usd_million_q/L12.trade_export_value_usd_million_q - 1)*100
gen growth_import_yoy_pct_q  = (trade_import_value_usd_million_q/L12.trade_import_value_usd_million_q - 1)*100

* Employment-share year-on-year change in PERCENTAGE POINTS (annual, 17 sectors)
foreach s in agri mining manuf electricity water_waste construction trade ///
    transport accom_food info_comm finance real_estate business_svc      ///
    public_admin education health other_svc {
    gen emp_share_`s'_ppt_chg_y = emp_share_`s'_pct_y - L12.emp_share_`s'_pct_y
}

* FX volatility: SD of the 12 monthly FX values within each calendar year (annual, national)
bysort _provid year: egen macro_fx_vol_sd_nat_y = sd(macro_fx_idr_usd_nat)

drop _provid _tm

*==============================================================
* 6. Order, checks, export
*==============================================================
order province_name_std province_code year month date quarter, first
sort province_name_std year month
isid province_name_std year month
export delimited using "$CLEAN/phk_master.csv", replace
qui count
display as result "Done. phk_master rows: `r(N)' (expect 2280)."
qui ds
display as result "columns: `: word count `r(varlist)'' (expect ~341; +1 new lab var (% Pekerja di atas UM))."

*==============================================================
* 7. Variable-level flag table (1/0), one row per indicator.
*==============================================================
qui ds province_name_std province_code year month date quarter, not
local vars `r(varlist)'
local n : word count `vars'
clear
set obs `n'
gen str40 variable      = ""
gen byte  data_bulanan  = 0
gen byte  data_triwulan = 0
gen byte  data_tahunan  = 0
gen byte  data_provinsi = 0
gen byte  data_nasional = 0
local i = 0
foreach v of local vars {
    local ++i
    qui replace variable = "`v'" in `i'
    if      regexm("`v'","_q$") qui replace data_triwulan = 1 in `i'
    else if regexm("`v'","_y$") qui replace data_tahunan  = 1 in `i'
    else                        qui replace data_bulanan  = 1 in `i'
    if strpos("`v'","_nat") > 0 qui replace data_nasional = 1 in `i'
    else                        qui replace data_provinsi = 1 in `i'
}
export delimited using "$CLEAN/phk_variable_flags.csv", replace
display as result "wrote phk_variable_flags.csv (`n' variables)."
