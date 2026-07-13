*==============================================================
* 01_build_phk_master.do   -  clean PHK master panel (Stata build)
*   data/raw/data_untuk_phk_dashboard.xlsx  ->  data/clean/phk_master.csv
* Grain    : one row = province x month.  Coverage: 2022-2025 (38 x 48 = 1,824).
* Source   : ONLY "Data untuk PHK Dashboard.xlsx" (3 sheets). MAP is NOT merged.
* Columns renamed by Excel POSITION. Names carry meaning: _q quarterly, _y annual,
* none = monthly; _nat = national, else province. Monthly enters directly;
* quarterly repeats over its 3 months; annual over its 12. Units taken AS-IS.
* NOTE: PDRB is in IDR milyar (billion) at both quarterly and annual grain; the 17
*       sectors sum to the total, and sum(4 quarters) == annual (both verified).
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
* 0. Province x month skeleton: 2022-01 .. 2025-12 (48 months)
*==============================================================
clear
set obs 48
gen long i   = _n
gen year     = 2022 + floor((i-1)/12)
gen month    = mod(i-1,12) + 1
gen quarter  = floor((month-1)/3) + 1
drop i
tempfile yearmonth
save `yearmonth'

*==============================================================
* 1. Monthly sheet (Database Bulan)
*==============================================================
import excel using "$PHK", sheet("Database (Bulan)") clear
rename A province_name
rename B province_code
rename C year
rename D month
rename F phk_stock
rename G phk_flow
rename H macro_pmi_manuf_nat
rename I price_cpi_index
rename J price_inflation_mom_pct
rename K price_inflation_yoy_pct
rename L price_consumer_change_pct
rename M trade_export_value
rename N trade_import_value
rename O trade_balance
rename P fin_npl_idr_billion
rename Q macro_bi_rate_pct_nat
rename R macro_fx_idr_usd_nat
rename S price_brent_usd_bbl_nat
rename T price_ihpb_nat
keep province_name province_code year month phk_stock phk_flow macro_pmi_manuf_nat price_cpi_index ///
     price_inflation_mom_pct price_inflation_yoy_pct price_consumer_change_pct trade_export_value ///
     trade_import_value trade_balance fin_npl_idr_billion macro_bi_rate_pct_nat macro_fx_idr_usd_nat ///
     price_brent_usd_bbl_nat price_ihpb_nat
drop in 1
replace province_name = strtrim(province_name)
ds province_name province_code, not
destring `r(varlist)', replace force
drop if missing(year)
gen province_name_std = strtrim(province_name)
drop if province_name_std == ""
keep if inrange(year,2022,2025)
drop province_name province_code
duplicates drop province_name_std year month, force
order province_name_std year month
tempfile monthly
save `monthly'

*==============================================================
* 2. Annual sheet (Database Tahun)  -- units taken as-is (no conversion)
*==============================================================
import excel using "$PHK", sheet("Database (Tahun)") clear
rename A province_name
rename B province_code
rename C year
rename D phk_y
rename E lab_formal_share_pct_y
rename F lab_formal_share_2019_pct_y
rename G lab_formal_share_chg_vs2019_y
rename H lab_contract_workers_y
rename I lab_formal_workers_y
rename J lab_contract_share_pct_y
rename K lab_contract_share_2019_pct_y
rename L lab_contract_share_chg_vs2019_y
rename M lab_working_pop_y
rename N lab_tpt_pct_y
rename O lab_tpt_male_pct_y
rename P lab_tpt_female_pct_y
rename Q lab_tpak_pct_y
rename R lab_tpak_male_pct_y
rename S lab_tpak_female_pct_y
rename T lab_self_employed_y
rename U lab_employee_count_y
rename V lab_unpaid_family_y
rename W lab_underemployed_workers_y
rename X lab_full_time_share_pct_y
rename Y lab_part_time_share_pct_y
rename Z lab_underemp_share_pct_y
rename AA emp_agri_y
rename AB emp_mining_y
rename AC emp_manuf_y
rename AD emp_electricity_y
rename AE emp_water_waste_y
rename AF emp_construction_y
rename AG emp_trade_y
rename AH emp_transport_y
rename AI emp_accom_food_y
rename AJ emp_info_comm_y
rename AK emp_finance_y
rename AL emp_real_estate_y
rename AM emp_business_svc_y
rename AN emp_public_admin_y
rename AO emp_education_y
rename AP emp_health_y
rename AQ emp_other_svc_y
rename AR emp_share_agri_pct_y
rename AS emp_share_mining_pct_y
rename AT emp_share_manuf_pct_y
rename AU emp_share_electricity_pct_y
rename AV emp_share_water_waste_pct_y
rename AW emp_share_construction_pct_y
rename AX emp_share_trade_pct_y
rename AY emp_share_transport_pct_y
rename AZ emp_share_accom_food_pct_y
rename BA emp_share_info_comm_pct_y
rename BB emp_share_finance_pct_y
rename BC emp_share_real_estate_pct_y
rename BD emp_share_business_svc_pct_y
rename BE emp_share_public_admin_pct_y
rename BF emp_share_education_pct_y
rename BG emp_share_health_pct_y
rename BH emp_share_other_svc_pct_y
rename BI lab_working_hours_y
rename BJ wage_ump_idr_y
rename BK wage_ump_growth_pct_y
rename BL wage_avg_employee_idr_y
rename BM wage_kaitz_index_y
rename BN lab_nonagri_informal_share_pct_y
rename BO lab_informal_share_pct_y
rename BP lab_job_seekers_y
rename BQ lab_vacancies_registered_y
rename BR lab_placements_registered_y
rename BS bpjstk_active_pu_y
rename BT bpjstk_active_bpu_y
rename BU bpjstk_phk_y
rename BV bpjstk_jht_phk_y
rename BW bpjstk_jkp_phk_y
rename BX growth_lab_working_pop_y
rename BY growth_lab_employee_count_y
rename BZ growth_lab_unpaid_family_y
rename CA growth_lab_formal_share_pct_y
rename CB growth_lab_contract_share_pct_y
rename CC growth_lab_full_time_share_pct_y
rename CD growth_lab_part_time_share_pct_y
rename CE growth_lab_underemp_share_pct_y
rename CF growth_lab_working_hours_y
rename CG growth_lab_tpt_pct_y
rename CH growth_lab_tpt_male_pct_y
rename CI growth_lab_tpt_female_pct_y
rename CJ growth_lab_tpak_pct_y
rename CK growth_lab_tpak_male_pct_y
rename CL growth_lab_tpak_female_pct_y
rename CM growth_wage_avg_employee_y
rename CN growth_bpjstk_active_pu_y
rename CO growth_bpjstk_active_bpu_y
rename CP growth_bpjstk_phk_y
rename CQ growth_bpjstk_jht_phk_y
rename CR growth_bpjstk_jkp_phk_y
rename CS lag1_phk_y
rename CT lag1_lab_formal_share_pct_y
rename CU lag1_lab_contract_share_pct_y
rename CV lag1_wage_ump_growth_pct_y
rename CW lag1_bpjstk_active_pu_y
rename CX lag1_bpjstk_active_bpu_y
rename CY lag1_bpjstk_phk_y
rename CZ lag1_bpjstk_jht_phk_y
rename DA lag1_bpjstk_jkp_phk_y
rename DB ind_firms_medium_y
rename DC ind_firms_large_y
rename DD ind_firms_total_y
rename DE ind_workers_medium_y
rename DF ind_workers_large_y
rename DG ind_workers_prod_y
rename DH ind_workers_nonprod_y
rename DI ind_workers_total_y
rename DJ ind_prod_workers_wage_cost_y
rename DK ind_prod_workers_other_cost_y
rename DL ind_prod_workers_total_cost_y
rename DM ind_nonprod_workers_wage_cost_y
rename DN ind_nonprod_workers_other_cost_y
rename DO ind_nonprod_workers_total_cost_y
rename DP ind_laborcost_total_y
rename DQ ind_input_y
rename DR ind_output_y
rename DS ind_va_mkt_y
rename DT ind_va_fc_y
rename DU ind_firms_pmdn_y
rename DV ind_firms_pma_y
rename DW ind_workers_per_firm_y
rename DX ind_prod_worker_share_y
rename DY ind_workers_per_input_y
rename DZ ind_workers_per_output_y
rename EA ind_workers_per_va_mkt_y
rename EB ind_workers_per_va_fc_y
rename EC ind_laborcost_share_input_y
rename ED ind_laborcost_share_output_y
rename EE ind_laborcost_share_va_mkt_y
rename EF ind_laborcost_share_va_fc_y
rename EG ind_laborcost_per_wkr_y
rename EH ind_output_per_wkr_y
rename EI ind_va_mkt_per_wkr_y
rename EJ ind_va_fc_per_wkr_y
rename EK ind_input_share_output_y
rename EL ind_va_mkt_share_output_y
rename EM ind_va_fc_share_output_y
rename EN ind_prod_laborcost_share_y
rename EO ind_nonprod_laborcost_share_y
rename EP ind_prod_wage_per_wkr_y
rename EQ ind_nonprod_wage_per_wkr_y
rename ER ind_firms_pmdn_share_y
rename ES ind_firms_pma_share_y
rename ET growth_ind_output_y
rename EU growth_ind_input_y
rename EV growth_ind_va_mkt_y
rename EW growth_ind_va_fc_y
rename EX growth_ind_workers_total_y
rename EY growth_ind_firms_total_y
rename EZ growth_ind_laborcost_total_y
rename FA growth_ind_labor_prod_market_y
rename FB growth_ind_labor_prod_fc_y
rename FC diffgr_input_minus_output_y
rename FD diffgr_laborcost_minus_output_y
rename FE macro_pdrb_idr_billion_y
rename FF macro_pdrb_idr_million_y
rename FG macro_pdrb_agri_y
rename FH macro_pdrb_mining_y
rename FI macro_pdrb_manuf_y
rename FJ macro_pdrb_electricity_y
rename FK macro_pdrb_water_waste_y
rename FL macro_pdrb_construction_y
rename FM macro_pdrb_trade_y
rename FN macro_pdrb_transport_y
rename FO macro_pdrb_accom_food_y
rename FP macro_pdrb_info_comm_y
rename FQ macro_pdrb_finance_y
rename FR macro_pdrb_real_estate_y
rename FS macro_pdrb_business_svc_y
rename FT macro_pdrb_public_admin_y
rename FU macro_pdrb_education_y
rename FV macro_pdrb_health_y
rename FW macro_pdrb_other_svc_y
rename FX macro_pdrb_manuf_share_pct_y
rename FY macro_pdrb_agri_share_pct_y
rename FZ macro_pdrb_svc_share_pct_y
rename GA macro_pdrb_manuf_growth_pct_y
rename GB macro_pdrb_per_wkr_y
rename GC macro_pdrb_per_wkr_growth_pct_y
rename GD macro_pmi_manuf_nat_y
rename GE fin_fdi_y
rename GF price_inflation_yoy_q4_pct_y
rename GG price_inflation_yoy_avg_pct_y
rename GH price_producer_index_nat_y
rename GI price_cpi_index_nat_y
rename GJ price_producer_change_pct_nat_y
rename GK price_consumer_change_pct_nat_y
rename GL trade_export_value_bps_y
rename GM trade_export_value_y
rename GN trade_import_value_y
rename GO trade_balance_y
rename GP fin_npl_y
rename GQ macro_bi_rate_avg_pct_nat_y
rename GR macro_fx_idr_usd_nat_y
rename GS macro_consumer_conf_nat_y
keep province_name province_code year phk_y lab_formal_share_pct_y lab_formal_share_2019_pct_y ///
     lab_formal_share_chg_vs2019_y lab_contract_workers_y lab_formal_workers_y lab_contract_share_pct_y ///
     lab_contract_share_2019_pct_y lab_contract_share_chg_vs2019_y lab_working_pop_y lab_tpt_pct_y ///
     lab_tpt_male_pct_y lab_tpt_female_pct_y lab_tpak_pct_y lab_tpak_male_pct_y lab_tpak_female_pct_y ///
     lab_self_employed_y lab_employee_count_y lab_unpaid_family_y lab_underemployed_workers_y ///
     lab_full_time_share_pct_y lab_part_time_share_pct_y lab_underemp_share_pct_y emp_agri_y emp_mining_y ///
     emp_manuf_y emp_electricity_y emp_water_waste_y emp_construction_y emp_trade_y emp_transport_y ///
     emp_accom_food_y emp_info_comm_y emp_finance_y emp_real_estate_y emp_business_svc_y emp_public_admin_y ///
     emp_education_y emp_health_y emp_other_svc_y emp_share_agri_pct_y emp_share_mining_pct_y ///
     emp_share_manuf_pct_y emp_share_electricity_pct_y emp_share_water_waste_pct_y ///
     emp_share_construction_pct_y emp_share_trade_pct_y emp_share_transport_pct_y emp_share_accom_food_pct_y ///
     emp_share_info_comm_pct_y emp_share_finance_pct_y emp_share_real_estate_pct_y ///
     emp_share_business_svc_pct_y emp_share_public_admin_pct_y emp_share_education_pct_y ///
     emp_share_health_pct_y emp_share_other_svc_pct_y lab_working_hours_y wage_ump_idr_y ///
     wage_ump_growth_pct_y wage_avg_employee_idr_y wage_kaitz_index_y lab_nonagri_informal_share_pct_y ///
     lab_informal_share_pct_y lab_job_seekers_y lab_vacancies_registered_y lab_placements_registered_y ///
     bpjstk_active_pu_y bpjstk_active_bpu_y bpjstk_phk_y bpjstk_jht_phk_y bpjstk_jkp_phk_y ///
     growth_lab_working_pop_y growth_lab_employee_count_y growth_lab_unpaid_family_y ///
     growth_lab_formal_share_pct_y growth_lab_contract_share_pct_y growth_lab_full_time_share_pct_y ///
     growth_lab_part_time_share_pct_y growth_lab_underemp_share_pct_y growth_lab_working_hours_y ///
     growth_lab_tpt_pct_y growth_lab_tpt_male_pct_y growth_lab_tpt_female_pct_y growth_lab_tpak_pct_y ///
     growth_lab_tpak_male_pct_y growth_lab_tpak_female_pct_y growth_wage_avg_employee_y ///
     growth_bpjstk_active_pu_y growth_bpjstk_active_bpu_y growth_bpjstk_phk_y growth_bpjstk_jht_phk_y ///
     growth_bpjstk_jkp_phk_y lag1_phk_y lag1_lab_formal_share_pct_y lag1_lab_contract_share_pct_y ///
     lag1_wage_ump_growth_pct_y lag1_bpjstk_active_pu_y lag1_bpjstk_active_bpu_y lag1_bpjstk_phk_y ///
     lag1_bpjstk_jht_phk_y lag1_bpjstk_jkp_phk_y ind_firms_medium_y ind_firms_large_y ind_firms_total_y ///
     ind_workers_medium_y ind_workers_large_y ind_workers_prod_y ind_workers_nonprod_y ind_workers_total_y ///
     ind_prod_workers_wage_cost_y ind_prod_workers_other_cost_y ind_prod_workers_total_cost_y ///
     ind_nonprod_workers_wage_cost_y ind_nonprod_workers_other_cost_y ind_nonprod_workers_total_cost_y ///
     ind_laborcost_total_y ind_input_y ind_output_y ind_va_mkt_y ind_va_fc_y ind_firms_pmdn_y ///
     ind_firms_pma_y ind_workers_per_firm_y ind_prod_worker_share_y ind_workers_per_input_y ///
     ind_workers_per_output_y ind_workers_per_va_mkt_y ind_workers_per_va_fc_y ind_laborcost_share_input_y ///
     ind_laborcost_share_output_y ind_laborcost_share_va_mkt_y ind_laborcost_share_va_fc_y ///
     ind_laborcost_per_wkr_y ind_output_per_wkr_y ind_va_mkt_per_wkr_y ind_va_fc_per_wkr_y ///
     ind_input_share_output_y ind_va_mkt_share_output_y ind_va_fc_share_output_y ind_prod_laborcost_share_y ///
     ind_nonprod_laborcost_share_y ind_prod_wage_per_wkr_y ind_nonprod_wage_per_wkr_y ind_firms_pmdn_share_y ///
     ind_firms_pma_share_y growth_ind_output_y growth_ind_input_y growth_ind_va_mkt_y growth_ind_va_fc_y ///
     growth_ind_workers_total_y growth_ind_firms_total_y growth_ind_laborcost_total_y ///
     growth_ind_labor_prod_market_y growth_ind_labor_prod_fc_y diffgr_input_minus_output_y ///
     diffgr_laborcost_minus_output_y macro_pdrb_idr_billion_y macro_pdrb_idr_million_y macro_pdrb_agri_y ///
     macro_pdrb_mining_y macro_pdrb_manuf_y macro_pdrb_electricity_y macro_pdrb_water_waste_y ///
     macro_pdrb_construction_y macro_pdrb_trade_y macro_pdrb_transport_y macro_pdrb_accom_food_y ///
     macro_pdrb_info_comm_y macro_pdrb_finance_y macro_pdrb_real_estate_y macro_pdrb_business_svc_y ///
     macro_pdrb_public_admin_y macro_pdrb_education_y macro_pdrb_health_y macro_pdrb_other_svc_y ///
     macro_pdrb_manuf_share_pct_y macro_pdrb_agri_share_pct_y macro_pdrb_svc_share_pct_y ///
     macro_pdrb_manuf_growth_pct_y macro_pdrb_per_wkr_y macro_pdrb_per_wkr_growth_pct_y ///
     macro_pmi_manuf_nat_y fin_fdi_y price_inflation_yoy_q4_pct_y price_inflation_yoy_avg_pct_y ///
     price_producer_index_nat_y price_cpi_index_nat_y price_producer_change_pct_nat_y ///
     price_consumer_change_pct_nat_y trade_export_value_bps_y trade_export_value_y trade_import_value_y ///
     trade_balance_y fin_npl_y macro_bi_rate_avg_pct_nat_y macro_fx_idr_usd_nat_y macro_consumer_conf_nat_y
drop in 1
replace province_name = strtrim(province_name)
ds province_name province_code, not
destring `r(varlist)', replace force
drop if missing(year)
gen province_name_std = strtrim(province_name)
drop if province_name_std == ""
keep if inrange(year,2022,2025)
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
* 3. Quarterly sheet (Database Triwulan)
*==============================================================
import excel using "$PHK", sheet("Database (Triwulan)") clear
rename A province_name
rename B province_code
rename C year
rename D quarter
rename E quarter_end_month_label
rename F phk_stock_q
rename G phk_flow_q
rename H macro_pdrb_q
rename I macro_pdrb_agri_q
rename J macro_pdrb_mining_q
rename K macro_pdrb_manuf_q
rename L macro_pdrb_electricity_q
rename M macro_pdrb_water_waste_q
rename N macro_pdrb_construction_q
rename O macro_pdrb_trade_q
rename P macro_pdrb_transport_q
rename Q macro_pdrb_accom_food_q
rename R macro_pdrb_info_comm_q
rename S macro_pdrb_finance_q
rename T macro_pdrb_real_estate_q
rename U macro_pdrb_business_svc_q
rename V macro_pdrb_public_admin_q
rename W macro_pdrb_education_q
rename X macro_pdrb_health_q
rename Y macro_pdrb_other_svc_q
rename Z macro_pdrb_manuf_share_pct_q
rename AA macro_pdrb_agri_share_pct_q
rename AB macro_pdrb_svc_share_pct_q
rename AC macro_pmi_manuf_nat_q
rename AD fin_fdi_usd_million_q
rename AE fin_fdi_idr_million_q
rename AF lab_working_pop_q
rename AG price_producer_index_nat_q
rename AH price_producer_change_pct_nat_q
rename AI price_producer_ceic_pct_nat_q
rename AJ price_cpi_index_q
rename AK price_consumer_change_pct_q
rename AL trade_export_value_usd_million_q
rename AM trade_import_value_usd_million_q
rename AN trade_balance_usd_million_q
rename AO fin_npl_idr_billion_q
rename AP macro_bi_rate_pct_nat_q
rename AQ macro_fx_idr_usd_nat_q
keep province_name province_code year quarter quarter_end_month_label phk_stock_q phk_flow_q macro_pdrb_q ///
     macro_pdrb_agri_q macro_pdrb_mining_q macro_pdrb_manuf_q macro_pdrb_electricity_q ///
     macro_pdrb_water_waste_q macro_pdrb_construction_q macro_pdrb_trade_q macro_pdrb_transport_q ///
     macro_pdrb_accom_food_q macro_pdrb_info_comm_q macro_pdrb_finance_q macro_pdrb_real_estate_q ///
     macro_pdrb_business_svc_q macro_pdrb_public_admin_q macro_pdrb_education_q macro_pdrb_health_q ///
     macro_pdrb_other_svc_q macro_pdrb_manuf_share_pct_q macro_pdrb_agri_share_pct_q ///
     macro_pdrb_svc_share_pct_q macro_pmi_manuf_nat_q fin_fdi_usd_million_q fin_fdi_idr_million_q ///
     lab_working_pop_q price_producer_index_nat_q price_producer_change_pct_nat_q ///
     price_producer_ceic_pct_nat_q price_cpi_index_q price_consumer_change_pct_q ///
     trade_export_value_usd_million_q trade_import_value_usd_million_q trade_balance_usd_million_q ///
     fin_npl_idr_billion_q macro_bi_rate_pct_nat_q macro_fx_idr_usd_nat_q
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
drop if missing(year)
gen province_name_std = strtrim(province_name)
drop if province_name_std == ""
keep if inrange(year,2022,2025)
drop province_name province_code quarter_end_month_label
duplicates drop province_name_std year quarter, force
order province_name_std year quarter
tempfile quarterly
save `quarterly'

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

*==============================================================
* 6. Order, checks, export
*==============================================================
order province_name_std province_code year month date quarter, first
sort province_name_std year month
isid province_name_std year month
export delimited using "$CLEAN/phk_master.csv", replace
qui count
display as result "Done. phk_master rows: `r(N)' (expect 1824)."
qui ds
display as result "columns: `: word count `r(varlist)'' (expect 257)."

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
