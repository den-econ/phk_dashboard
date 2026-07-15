/*******************************************************************************
01. PREPARE PANEL
*******************************************************************************/

do  "$dofile/00_config.do"

capture log close
set scheme plotplain


/*******************************************************************************
    DATA PREPARATION
*******************************************************************************/

    * Import data
    import  delimited "$input/phk_master.csv", clear
    save    "$data/phk_master.dta", replace

    * Generate variables 
    gen     log_pdrb_y                      = ln(macro_pdrb_idr_billion_y)
    rename  macro_pdrb_manuf_share_pct_y    manuf_pdrb_share_y
    rename  emp_share_manuf_pct_y           manuf_emp_share_y
    rename  emp_share_agri_pct_y            agri_emp_share_y
    rename  lab_formal_share_pct_y          formal_lab_share_y
    gen     log_wage_ump_y                  = ln(wage_ump_idr_y) 
    gen     log_wage_avg_y                  = ln(wage_avg_employee_idr_y) 
    
    gen     log_price_brent                 = ln(price_brent_usd_bbl_nat)
    rename  macro_bi_rate_pct_nat           bi_rate_nat
    gen     log_fx_idr_usd                  = ln(macro_fx_idr_usd_nat)
    rename  macro_pmi_manuf_nat             pmi_manuf_nat
    gen     log_npl                         = ln(fin_npl_idr_billion)
    gen     log_export                      = ln(trade_export_value)
    gen     log_import                      = ln(trade_import_value)

    rename  price_cpi_index                 cpi_index
    rename  price_ihpb_nat                  ihpb_nat

    * Generate province id
    rename  province_code prov_id

    capture label drop prov_lbl
    levelsof prov_id, local(provs)

    foreach p of local provs {
        quietly levelsof province_name_std if prov_id==`p', local(name) clean
        label define prov_lbl `p' "`name'", add
    }

    label values prov_id prov_lbl
    
    * Set up panel data 
    sort    prov_id year month
    gen     ym = ym(year, month)
    format  ym %tm

    xtset   prov_id ym


    keeporder prov_id year month ym date phk_stock phk_flow ///
            $STRUCTURE $TRIGGER


    * Construct lag for 1, 3, 6, and 12 months 
    foreach L of global LAGS {
        foreach v of global TRIGGER {
            capture drop L`L'_`v'
            gen L`L'_`v' = L`L'.`v'
        }
    }


    * Keep only 2023 data onwards 
    keep    if year >= 2023

    * Truncate PHK flow if data is negative 
    tab     prov_id phk_flow if phk_flow < 0

    replace phk_flow = 0 if phk_flow < 0
    capture noisily xtsum phk_flow

    * Treat missing data as zero 
    replace phk_flow = 0 if phk_flow == .
 

    save    "$panel", replace
    
    
