* =============================================================================
* Project           : PHK Dashboard
* Description       : Develop Model to Project PHK  
* Stata version     : 16
* Date created      : 13 July 2026 by Bertha
* Last modified     : 13 July 2026 by Bertha
* =============================================================================


*******************************************************************************
*******************************************************************************
//////////////////////////// PREPARE PANEL ////////////////////////////////////
*******************************************************************************
*******************************************************************************

do  "$dofile/00_config.do"

capture log close
set scheme plotplain


/*******************************************************************************
    DATA PREPARATION
*******************************************************************************/

    * Import data
    import  delimited "$input/phk_master.csv", clear
    save    "$data/phk_master.dta", replace

    * Rename variables 
    rename  macro_pdrb_manuf_share_pct_y    manuf_pdrb_share
    rename  macro_pdrb_agri_share_pct_y     agri_pdrb_share
    rename  emp_share_manuf_pct_y           manuf_emp_share
    rename  emp_share_agri_pct_y            agri_emp_share
    rename  lab_formal_share_pct_y          formal_lab_share
    rename  wage_ump_growth_pct_y           min_wage_yoy
    rename  growth_wage_avg_employee_y      avg_wage_yoy
    

    rename  growth_brent_yoy_pct_nat        price_brent_yoy
    rename  macro_bi_rate_pct_nat           bi_rate
    rename  macro_pmi_manuf_nat             pmi_manuf
    rename  growth_ihpb_yoy_pct_nat         ihpb_yoy

    rename  price_inflation_yoy_pct         cpi_yoy
    rename  growth_npl_yoy_pct              npl_yoy
    rename  growth_export_yoy_pct           export_yoy
    rename  growth_import_yoy_pct           import_yoy

    rename  price_cpi_index                 cpi_index
    rename  price_ihpb_nat                  ihpb_index

    gen     log_price_brent                 = ln(price_brent_usd_bbl_nat)
    gen     log_fx_idr_usd                  = ln(macro_fx_idr_usd_nat)
    gen     log_export                      = ln(trade_export_value)
    gen     log_import                      = ln(trade_import_value)
    gen     log_min_wage                    = ln(wage_ump_idr_y) 
    gen     log_npl                         = ln(fin_npl_idr_billion)
    gen     log_cpi                         = ln(cpi_index)
    gen     log_ihpb                        = ln(ihpb_index)


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
    sort    prov_id ym


    * Generate growth variables 
    gen     pdrb_yoy            = 100*(macro_pdrb_idr_billion_y/L12.macro_pdrb_idr_billion_y - 1)
    gen     fx_idr_usd_yoy      = 100*(macro_fx_idr_usd_nat/L12.macro_fx_idr_usd_nat - 1)


    * Generate Three-month moving average (current month + previous 2 months) for export and import with missing values
    gen     export0 = trade_export_value
    gen     export1 = L1.trade_export_value
    gen     export2 = L2.trade_export_value
    egen    export_ma3 = rowmean(export0 export1 export2)
    drop    export0 export1 export2 
    gen     export_ma3_yoy = 100*(export_ma3 - L12.export_ma3)/L12.export_ma3 if L12.export_ma3 > 0


    gen     import0 = trade_import_value
    gen     import1 = L1.trade_import_value
    gen     import2 = L2.trade_import_value
    egen    import_ma3 = rowmean(import0 import1 import2)
    drop    import0 import1 import2
    gen     import_ma3_yoy = 100*(import_ma3 - L12.import_ma3)/L12.import_ma3 if L12.import_ma3 > 0

/*******************************************************************************
    LAGS AND DATA PERIOD
*******************************************************************************/

    keeporder   prov_id year month ym date phk_stock phk_flow ///
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

    
/*******************************************************************************
    INSPECT DATA
*******************************************************************************/

    * Summarize
    sum     prov_id year month ym date phk_stock phk_flow ///
            $STRUCTURE $TRIGGER 


    * Truncate PHK flow if data is negative 
    tab     prov_id phk_flow if phk_flow < 0

    replace phk_flow = 0 if phk_flow < 0
    capture noisily xtsum phk_flow

    * Treat missing data as zero 
    //replace phk_flow = 0 if phk_flow == .
    

    * Drop new provinces due to missing data
    //drop if inlist( prov_id, 92, 95, 96, 97)


    sum     prov_id year month ym date phk_stock phk_flow ///
            $STRUCTURE $TRIGGER L1_* L3_* L6_* L12_*
   
    save    "$panel", replace
    
    
