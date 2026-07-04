*==============================================================
* 01_build_baseline_master.do
* One-time baseline merge for the PHK Early Warning Dashboard
* Stata translation of code/01_build_baseline_master.py
* Owner: Muthia
*
* Reads the two raw workbooks, standardizes provinces, builds a
* province-month panel, broadcasts annual and quarterly indicators
* across months, joins MAP structural indicators with a 2024-into-2025
* carry-forward, sets flags, and writes:
*   clean_data/phk_master.csv          curated province-month panel
*   clean_data/annual_full.csv         full annual sheet
*   clean_data/map_kabkot_context.csv  MAP kabupaten and kota rows
*   technical_notes/baseline_merge_notes.md
*
* Run from the repo root, or set REPO to an absolute path below.
* Requires Stata 14 or newer.
*==============================================================
version 14
clear all
set more off

*--- paths ---
global REPO   "."
global RAW    "$REPO/raw_data"
global CLEAN  "$REPO/clean_data"
global NOTES  "$REPO/technical_notes/baseline_merge_notes.md"
global PHK    "$RAW/Data untuk PHK Dashboard.xlsx"
global MAP    "$RAW/MAP_composite_all.xlsx"
global MAPSHT "Sheet 1 - MAP_composite_all"

capture mkdir "$CLEAN"

*==============================================================
* 0. Calendar skeleton pieces: year-month grid (48 rows)
*==============================================================
clear
set obs 48
gen long i = _n
gen year    = 2022 + floor((i-1)/12)
gen month   = mod(i-1,12) + 1
gen quarter = floor((month-1)/3) + 1
drop i
tempfile yearmonth
save `yearmonth'

*==============================================================
* 1. Monthly sheet (Database Bulan)
*    Import without firstrow so messy headers stay intact in row 1,
*    then rename by matching the exact header text.
*==============================================================
import excel using "$PHK", sheet("Database (Bulan)") clear
foreach v of varlist _all {
    local h = strtrim(`v'[1])
    if "`h'"=="Provinsi"                          rename `v' province_std
    if "`h'"=="Tahun"                             rename `v' year
    if "`h'"=="Bulan"                             rename `v' month
    if "`h'"=="PHK (Stock)"                       rename `v' phk_stock
    if "`h'"=="PHK (Flow)"                        rename `v' phk_flow
    if "`h'"=="IHK (2010=100)"                    rename `v' ihk
    if "`h'"=="Inflasi Tahunan (Y-on-Y)"          rename `v' inflasi_yoy
    if "`h'"=="Inflasi Bulanan (M-to-M)"          rename `v' inflasi_mtm
    if "`h'"=="Nilai Ekspor"                      rename `v' nilai_ekspor
    if "`h'"=="Nilai Impor"                       rename `v' nilai_impor
    if "`h'"=="Neraca Perdagangan"                rename `v' neraca_perdagangan
    if "`h'"=="NPL (IDR miliar)"                  rename `v' npl
    if "`h'"=="PMI Manufaktur S&P"                rename `v' pmi_manufaktur_national
    if "`h'"=="BI Rate"                           rename `v' bi_rate_national
    if "`h'"=="Kurs"                              rename `v' kurs_national
    if "`h'"=="Harga Minyak Brent (USD/barrel)"   rename `v' brent_oil_national
    if "`h'"=="IHPB"                              rename `v' ihpb_national
}
keep province_std year month phk_stock phk_flow ihk inflasi_yoy inflasi_mtm ///
     nilai_ekspor nilai_impor neraca_perdagangan npl ///
     pmi_manufaktur_national bi_rate_national kurs_national ///
     brent_oil_national ihpb_national
drop in 1
replace province_std = strtrim(province_std)
destring year month phk_stock phk_flow ihk inflasi_yoy inflasi_mtm ///
         nilai_ekspor nilai_impor neraca_perdagangan npl ///
         pmi_manufaktur_national bi_rate_national kurs_national ///
         brent_oil_national ihpb_national, replace force
tempfile monthly
save `monthly'

*==============================================================
* 2. Annual sheet (Database Tahun), curated columns
*==============================================================
import excel using "$PHK", sheet("Database (Tahun)") clear
foreach v of varlist _all {
    local h = strtrim(`v'[1])
    if "`h'"=="Provinsi"                          rename `v' province_std
    if "`h'"=="Tahun"                             rename `v' year
    if "`h'"=="PHK"                               rename `v' annual_phk
    if "`h'"=="% Pekerja Formal"                  rename `v' pct_pekerja_formal
    if "`h'"=="% TPT"                             rename `v' tpt
    if "`h'"=="% TPAK"                            rename `v' tpak
    if "`h'"=="Proporsi Lapangan Kerja Informal"  rename `v' proporsi_informal
    if "`h'"=="UMP (IDR)"                         rename `v' ump_ribu_idr
    if "`h'"=="Growth UMP"                        rename `v' growth_ump
    if "`h'"=="Kaitz Index"                       rename `v' kaitz_index
    if "`h'"=="Manufacturing Share"               rename `v' manufacturing_share
}
keep province_std year annual_phk pct_pekerja_formal tpt tpak ///
     proporsi_informal ump_ribu_idr growth_ump kaitz_index manufacturing_share
drop in 1
replace province_std = strtrim(province_std)
destring year annual_phk pct_pekerja_formal tpt tpak proporsi_informal ///
         ump_ribu_idr growth_ump kaitz_index manufacturing_share, replace force
tempfile annual
save `annual'

*==============================================================
* 3. Quarterly sheet (Database Triwulan), curated columns
*==============================================================
import excel using "$PHK", sheet("Database (Triwulan)") clear
foreach v of varlist _all {
    local h = strtrim(`v'[1])
    if "`h'"=="Provinsi"                 rename `v' province_std
    if "`h'"=="Tahun"                    rename `v' year
    if "`h'"=="Triwulan"                 rename `v' quarter_roman
    if "`h'"=="PDRB (IDR mn)"            rename `v' pdrb
    if "`h'"=="FDI (IDR mn)"             rename `v' fdi_idr
    if "`h'"=="Jumlah Penduduk Bekerja"  rename `v' jumlah_penduduk_bekerja
}
keep province_std year quarter_roman pdrb fdi_idr jumlah_penduduk_bekerja
drop in 1
replace province_std = strtrim(province_std)
gen quarter = .
replace quarter = 1 if inlist(strtrim(quarter_roman),"I","1")
replace quarter = 2 if inlist(strtrim(quarter_roman),"II","2")
replace quarter = 3 if inlist(strtrim(quarter_roman),"III","3")
replace quarter = 4 if inlist(strtrim(quarter_roman),"IV","4")
drop quarter_roman
destring year pdrb fdi_idr jumlah_penduduk_bekerja, replace force
tempfile quarterly
save `quarterly'

*==============================================================
* 4. MAP sheet, province rows only.
*    Header sits on row 2, so start the range at A2.
*    MAP headers are clean, so firstrow is safe here.
*==============================================================
import excel using "$MAP", sheet("$MAPSHT") cellrange(A2) firstrow case(preserve) clear
keep if name=="Provinsi"
keep if year>=2022 & year<=2024

* canonical province name
gen province_std = proper(id_label)
replace province_std = "DKI Jakarta"     if upper(id_label)=="DKI JAKARTA"
replace province_std = "DI Yogyakarta"   if upper(id_label)=="DI YOGYAKARTA"
replace province_std = "Bangka Belitung" if upper(id_label)=="KEPULAUAN BANGKA BELITUNG"

* province code from MAP id (first two digits), authoritative and unique
gen province_code = string(floor(id/100),"%02.0f")

rename threshold_skortotal map_skortotal
rename threshold_status    map_threshold_status
rename nonpkwtt            map_nonpkwtt
rename wageump             map_wageump
rename laborinten          map_laborinten
rename formalgrowth        map_formalgrowth
rename pdrbgrowth          map_pdrbgrowth
rename informal            map_informal
rename manufacture         map_manufacture

keep province_std province_code year map_skortotal map_threshold_status ///
     map_nonpkwtt map_wageump map_laborinten map_formalgrowth ///
     map_pdrbgrowth map_informal map_manufacture
gen map_year_used = year

* carry the 2024 MAP values into 2025, keeping map_year_used at 2024
preserve
    keep if year==2024
    replace year = 2025
    tempfile map2025
    save `map2025'
restore
append using `map2025'
tempfile mapprov
save `mapprov'

*==============================================================
* 5. Build the 38 x 48 skeleton and merge everything on
*==============================================================
use `monthly', clear
keep province_std
duplicates drop
cross using `yearmonth'
gen date = string(year) + "-" + string(month,"%02.0f") + "-01"

merge 1:1 province_std year month using `monthly',    keep(master match) nogen
merge m:1 province_std year        using `annual',     keep(master match) nogen
merge m:1 province_std year quarter using `quarterly', keep(master match) nogen
merge m:1 province_std year        using `mapprov',    keep(master match) nogen

*==============================================================
* 6. Flags and provenance
*==============================================================
egen _nann = rownonmiss(annual_phk pct_pekerja_formal tpt tpak ///
      proporsi_informal ump_ribu_idr growth_ump kaitz_index manufacturing_share)
gen annual_indicator_repeated_monthly = _nann>0
drop _nann

egen _nq = rownonmiss(pdrb fdi_idr jumlah_penduduk_bekerja)
gen quarterly_indicator_repeated_monthly = _nq>0
drop _nq

gen admin_mapping_status = "matched"
replace admin_mapping_status = "new_province_no_map" ///
    if inlist(province_std,"Papua Selatan","Papua Tengah","Papua Pegunungan","Papua Barat Daya")

gen phk_reporting_status = "no_data"
replace phk_reporting_status = "reported" if !missing(phk_flow) | !missing(phk_stock)

bysort year month: egen phk_period_reporting_count = total(!missing(phk_flow))

gen province_name_original = province_std
gen baseline_merge_source  = "Database Bulan + Tahun + Triwulan + MAP"
gen data_version           = "baseline-v1"
gen last_updated           = string(date(c(current_date),"DMY"), "%tdCCYY!-NN!-DD")
gen source_file            = "Data untuk PHK Dashboard.xlsx, MAP_composite_all.xlsx"

*==============================================================
* 7. Order, check, export the master
*==============================================================
order province_name_original province_std province_code year month date quarter ///
      phk_stock phk_flow ihk inflasi_yoy inflasi_mtm ///
      nilai_ekspor nilai_impor neraca_perdagangan npl ///
      pmi_manufaktur_national bi_rate_national kurs_national ///
      brent_oil_national ihpb_national ///
      phk_period_reporting_count ///
      annual_phk pct_pekerja_formal tpt tpak proporsi_informal ///
      ump_ribu_idr growth_ump kaitz_index manufacturing_share ///
      pdrb fdi_idr jumlah_penduduk_bekerja ///
      map_skortotal map_threshold_status map_nonpkwtt map_wageump ///
      map_laborinten map_formalgrowth map_pdrbgrowth map_informal map_manufacture ///
      annual_indicator_repeated_monthly quarterly_indicator_repeated_monthly ///
      map_year_used admin_mapping_status phk_reporting_status ///
      baseline_merge_source data_version last_updated source_file

sort province_std year month
isid province_std year month

* counts for the notes file
qui count
local nrows = r(N)
qui egen _pt = tag(province_std)
qui count if _pt
local nprov = r(N)
drop _pt
qui egen _dt = tag(date)
qui count if _dt
local nmonths = r(N)
drop _dt
qui count if !missing(phk_flow)
local nflow = r(N)
qui count if admin_mapping_status=="new_province_no_map"
local nnew = r(N)
qui count if year==2025 & map_year_used==2024
local ncarry = r(N)

export delimited using "$CLEAN/phk_master.csv", replace

*==============================================================
* 8. annual_full.csv (full annual sheet)
*    Note: Stata sanitizes the 183 headers into valid names, so
*    column names here differ from the exact source strings.
*==============================================================
import excel using "$PHK", sheet("Database (Tahun)") firstrow case(preserve) clear
export delimited using "$CLEAN/annual_full.csv", replace

*==============================================================
* 9. map_kabkot_context.csv (MAP kabupaten and kota rows)
*==============================================================
import excel using "$MAP", sheet("$MAPSHT") cellrange(A2) firstrow case(preserve) clear
keep if name=="Kabkot"
export delimited using "$CLEAN/map_kabkot_context.csv", replace

*==============================================================
* 10. Baseline merge notes
*==============================================================
file open nf using "$NOTES", write replace
file write nf "# Baseline merge notes (Stata build)" _n _n
file write nf "Data version: baseline-v1" _n _n
file write nf "phk_master.csv rows: `nrows'" _n
file write nf "Provinces: `nprov'" _n
file write nf "Months: `nmonths'" _n
file write nf "Rows with PHK flow reported: `nflow'" _n
file write nf "Rows flagged new_province_no_map: `nnew'" _n
file write nf "Rows using carried-forward MAP (2025): `ncarry'" _n _n
file write nf "Province codes derived from MAP id. The four new Papua provinces" _n
file write nf "have no MAP row, so their code is blank and admin_mapping_status" _n
file write nf "is new_province_no_map. MAP structural data ends in 2024 and is" _n
file write nf "carried into 2025 with map_year_used recording the source year." _n
file close nf

display as result "Done. Master rows: `nrows', provinces: `nprov', months: `nmonths'."
