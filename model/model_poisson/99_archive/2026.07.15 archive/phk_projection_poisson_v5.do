* ==============================================================================
* Project           : PHK Dashboard
* Description       : Develop Model to Project PHK  
* Stata version     : 16
* Date created      : 13 July 2026 by Bertha
* Last modified     : 13 July 2026 by Bertha
* ==============================================================================

    clear   all
    set more off
    capture: log close
    set     scheme  plotplain 


/*******************************************************************************
    0. SETUP
*******************************************************************************/
    
    * Install packages if needed
    if _rc ssc install estout, replace
    cap which winsor2
    if _rc ssc install winsor2, replace

    * User directories
    if "`c(username)'" == "berth" {                                                                 
        gl  root    "C:\Users\berth\GitHub\phk_dashboard" 
        gl  data    "$root/data"
        gl  model   "$root/model/model_poisson"
        gl  output  "$model/output"
        cap mkdir   "$output"
    } 

    * Log 
    log     using   "$model/phk_projection_poisson.log", replace


/*******************************************************************************
    1. MODEL METADATA
*******************************************************************************/
    
    * Version
    loc     ver = 1

    * Define lags 
    global  LAGS 1 3 6 12

    * Dependent variable    
    global  OUTCOME phk_flow
    
    * Control variables 
    
        // Economic Structure
        global  STRUCTURE ///
                log_pdrb_y ///
                manuf_pdrb_share_y ///
                manuf_emp_share_y ///
                formal_lab_share_y ///
                log_wage_ump_y 
        
                //log_wage_avg_y 
                //agri_emp_share_y ///

        // Macro Trigger
        global  MACRO_GLOBAL ///
                log_price_brent 

        global  MACRO_NATIONAL ///
                bi_rate_nat ///
                log_fx_idr_usd ///
                pmi_manuf_nat ///
                ihpb_nat 

        global  MACRO_PROVINCE ///
                cpi_index ///
                log_npl  ///
                log_export ///
                log_import 


    global  TRIGGER $MACRO_GLOBAL $MACRO_NATIONAL $MACRO_PROVINCE


/*******************************************************************************
    2. DATA PREPARATION
*******************************************************************************/

    * Import data
    import  delimited "$data/clean/phk_master.csv", clear
    save    "$model/phk_master.dta", replace

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
 

    save    "$output/phk_panel_data.dta", replace
    
    
/*******************************************************************************
    3. CANDIDATE MODEL ESTIMATION
*******************************************************************************/

    use "$output/phk_panel_data.dta", clear

    xtset prov_id ym

    *====================================================================
    * Training and validation sample
    *====================================================================

    gen byte train = inrange(year,2023,2024)
    gen byte valid = year==2025

    *====================================================================
    * Store model evaluation
    *====================================================================

    tempname results

    postfile `results' ///
        lag ///
        n_valid ///
        rmse ///
        mae ///
        using "$output/lag_selection.dta", replace

    eststo clear

    *====================================================================
    * Candidate models
    *====================================================================

    foreach L of global LAGS {

        di
        di "==============================================================="
        di "Estimating `L'-month lead model"
        di "==============================================================="

        *--------------------------------------------------------------*
        * Construct lagged trigger variables
        *--------------------------------------------------------------*

        local trigger

        foreach v of global TRIGGER {

            local trigger `trigger' L`L'_`v'

        }

        *--------------------------------------------------------------*
        * Estimate model (training sample)
        *--------------------------------------------------------------*

        eststo lag_`L' : poisson ///
            $OUTCOME ///
            $STRUCTURE ///
            `trigger' ///
            i.month ///
            i.prov_id ///
            if train, ///
            vce(cluster prov_id)

        *--------------------------------------------------------------*
        * Validation prediction
        *--------------------------------------------------------------*

        capture drop phk_hat err sqerr abserr

        predict double phk_hat if valid

        gen err    = phk_flow - phk_hat if valid & !missing(phk_hat)
        gen sqerr  = err^2              if valid & !missing(phk_hat)
        gen abserr = abs(err)           if valid & !missing(phk_hat)

        quietly count if valid & !missing(phk_hat)

        local N_valid = r(N)

        quietly summarize sqerr if valid & !missing(phk_hat)

        scalar RMSE = sqrt(r(mean))

        quietly summarize abserr if valid & !missing(phk_hat)

        scalar MAE = r(mean)

        *--------------------------------------------------------------*
        * Store statistics with estimation results
        *--------------------------------------------------------------*

        estadd scalar rmse    = RMSE
        estadd scalar mae     = MAE
        estadd scalar n_valid = `N_valid'

        estadd local region "Province"
        estadd local time   "Month"

        *--------------------------------------------------------------*
        * Store model comparison results
        *--------------------------------------------------------------*

        post `results' ///
            (`L') ///
            (`N_valid') ///
            (RMSE) ///
            (MAE)

        *--------------------------------------------------------------*
        * Save validation prediction
        *--------------------------------------------------------------*

        preserve

            keep if valid

            keep ///
                prov_id ///
                ym ///
                year ///
                month ///
                phk_flow ///
                phk_hat ///
                err ///
                sqerr ///
                abserr

            save "$output/projection_lag`L'.dta", replace

        restore

    }

    postclose `results'



/*******************************************************************************
    4. MODEL EVALUATION AND REGRESSION TABLES
*******************************************************************************/

    global TABLE "$output/Table"

    *====================================================================
    * 4.1 Model Selection
    *====================================================================

    use "$output/lag_selection.dta", clear

    gsort rmse mae

    gen rank = _n

    order rank lag rmse mae n_valid

    list, sep(0)

    save "$output/model_selection.dta", replace

    export excel using ///
        "$output/model_selection.xlsx", ///
        firstrow(variables) replace

    export delimited using ///
        "$output/model_selection.csv", ///
        replace

    display as text "==============================================================="
    display as text "Model ranking based on validation RMSE"
    display as text "==============================================================="

    display as result ///
        "Best forecasting model : Lead " lag[1]

    *====================================================================
    * Common esttab options
    *====================================================================

    local stats ///
        stats( ///
            N ///
            n_valid ///
            p_r2 ///
            rmse ///
            mae ///
            region ///
            time, ///
            labels( ///
                "Training observations" ///
                "Validation observations" ///
                "Pseudo R-squared" ///
                "RMSE" ///
                "MAE" ///
                "Province FE" ///
                "Month FE") ///
            fmt(%15.0fc %15.0fc %6.3f %9.3f %9.3f 0 0))

    local tableopt ///
        keep($STRUCTURE L1_* L3_* L6_* L12_*) ///
        mtitles("Lead 1" "Lead 3" "Lead 6" "Lead 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        label compress nonotes

    local tablenote ///
        addnotes( ///
        "Robust standard errors clustered at the province level.", ///
        "Forecasting model selected based on the lowest validation RMSE.")

    *====================================================================
    * 4.2 Raw Poisson Coefficients
    *====================================================================

    display as text " "
    display as text "Poisson regression coefficients"

    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        `tableopt' ///
        `stats'

    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$TABLE/poisson_coefficients.tex", ///
        replace ///
        booktabs ///
        `tableopt' ///
        `stats' ///
        `tablenote'

    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$TABLE/poisson_coefficients.csv", ///
        replace ///
        `tableopt' ///
        `stats'

    *====================================================================
    * 4.3 Incidence Rate Ratios (IRR)
    *====================================================================

    display as text " "
    display as text "Incidence Rate Ratios"

    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        eform ///
        `tableopt' ///
        `stats'

    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$TABLE/poisson_irr.tex", ///
        replace ///
        booktabs ///
        eform ///
        `tableopt' ///
        `stats' ///
        addnotes( ///
        "Incidence Rate Ratios (IRR).", ///
        "Robust standard errors clustered at the province level.", ///
        "Forecasting model selected based on the lowest validation RMSE.")

    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$TABLE/poisson_irr.csv", ///
        replace ///
        eform ///
        `tableopt' ///
        `stats'


/*******************************************************************************
    5. FORECAST DATASET PREPARATION
*******************************************************************************/

    use "$output/phk_panel_data.dta", clear

    xtset prov_id ym

    *====================================================================
    * Forecast horizon
    *====================================================================

    quietly summarize ym if !missing(phk_flow)

    global LAST_YM = r(max)

    display as text "Latest observed month : " %tm $LAST_YM

    * User-defined forecast end month
    global FC_END = ym(2026,12)

    global FC_HORIZON = $FC_END - $LAST_YM

    display as text "Forecast end month    : " %tm $FC_END
    display as text "Forecast horizon      : " $FC_HORIZON " month(s)"

    *====================================================================
    * Extend panel
    *====================================================================

    tsappend, add($FC_HORIZON)

    replace year  = year(dofm(ym))  if missing(year)
    replace month = month(dofm(ym)) if missing(month)

    sort prov_id ym
    xtset prov_id ym

    *====================================================================
    * Carry forward annual structural variables
    *====================================================================

    foreach var of global STRUCTURE {

        bysort prov_id (ym): ///
            replace `var' = `var'[_n-1] if missing(`var')

    }

    *====================================================================
    * Carry forward macroeconomic indicators
    *
    * Assumption:
    * Future macroeconomic indicators remain at their latest
    * observed value throughout the forecast horizon.
    *====================================================================

    foreach var of global TRIGGER {

        bysort prov_id (ym): ///
            replace `var' = `var'[_n-1] if missing(`var')

    }

    *====================================================================
    * Reconstruct lagged macroeconomic indicators
    *====================================================================

    foreach L of global LAGS {

        foreach var of global TRIGGER {

            capture drop L`L'_`var'

            gen L`L'_`var' = L`L'.`var'

        }

    }

    *====================================================================
    * Initialize forecast variable
    *====================================================================

    capture drop phk_projection

    gen phk_projection = .

    label variable phk_projection ///
        "Projected monthly layoffs"

    *====================================================================
    * Diagnostics
    *====================================================================

    display as text "==============================================================="
    display as text "Forecast panel summary"
    display as text "==============================================================="

    tab year

    summ ym

    count if year==2026

    display as result ///
        "Forecast observations : " r(N)

    *====================================================================
    * Save forecasting panel
    *====================================================================

    save "$output/phk_projection_2026.dta", replace



/*******************************************************************************
    6. FINAL FORECASTING MODEL
*******************************************************************************/

    *====================================================================
    * Retrieve selected forecasting model
    *====================================================================

    use "$output/model_selection.dta", clear

    local BEST    = lag[1]
    local RMSE    = rmse[1]
    local MAE     = mae[1]
    local N_VALID = n_valid[1]

    display as text "==============================================================="
    display as result "Selected forecasting model : Lead `BEST'"
    display as result "Validation RMSE            : " %9.3f `RMSE'
    display as result "Validation MAE             : " %9.3f `MAE'
    display as result "Validation observations    : " %12.0fc `N_VALID'
    display as text "==============================================================="


    *====================================================================
    * Load forecasting dataset
    *====================================================================

    use "$output/phk_projection_2026.dta", clear

    xtset prov_id ym


    *====================================================================
    * Construct selected trigger variables
    *====================================================================

    local trigger

    foreach var of global TRIGGER {

        local trigger `trigger' L`BEST'_`var'

    }

    display as text "Selected trigger variables"

    display as result "`trigger'"


    *====================================================================
    * Estimate final model
    *====================================================================

    eststo clear

    eststo final : poisson ///
        $OUTCOME ///
        $STRUCTURE ///
        `trigger' ///
        i.month ///
        i.prov_id ///
        if year<=2025, ///
        vce(cluster prov_id)

    display as text " "

    display as text "Final model summary"

    display as result ///
        "Estimation sample : " %12.0fc e(N)

    display as result ///
        "Pseudo R-squared  : " %6.3f e(r2_p)


    *====================================================================
    * Save final model
    *====================================================================

    estimates save ///
        "$output/phk_model_final.ster", ///
        replace


    *====================================================================
    * Final regression table (Coefficient)
    *====================================================================

    esttab final, ///
        keep($STRUCTURE L`BEST'_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)

    esttab final ///
        using "$TABLE/final_model.tex", ///
        replace ///
        booktabs ///
        label ///
        compress ///
        nonotes ///
        keep($STRUCTURE L`BEST'_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        addnotes( ///
        "Selected forecasting model: Lead `BEST'.", ///
        "Robust standard errors clustered at the province level.")

    esttab final ///
        using "$TABLE/final_model.csv", ///
        replace ///
        keep($STRUCTURE L`BEST'_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)


    *====================================================================
    * Final regression table (IRR)
    *====================================================================

    esttab final, ///
        eform ///
        keep($STRUCTURE L`BEST'_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)

    esttab final ///
        using "$TABLE/final_model_irr.tex", ///
        replace ///
        eform ///
        booktabs ///
        label ///
        compress ///
        nonotes ///
        keep($STRUCTURE L`BEST'_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        addnotes( ///
        "Incidence Rate Ratios (IRR).", ///
        "Selected forecasting model: Lead `BEST'.", ///
        "Robust standard errors clustered at the province level.")

    esttab final ///
        using "$TABLE/final_model_irr.csv", ///
        replace ///
        eform ///
        keep($STRUCTURE L`BEST'_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)


    *====================================================================
    * Forecast
    *====================================================================

    capture drop phk_projection

    predict double phk_projection if e(sample) | year==2026

    replace phk_projection = . if year<=2025

    replace phk_projection = round(phk_projection)

    format phk_projection %12.0fc

    label variable phk_projection ///
        "Projected monthly layoffs"


    *====================================================================
    * Forecast diagnostics
    *====================================================================

    display as text " "

    display as text "Forecast summary"

    quietly count if year==2026 & !missing(phk_projection)

    display as result ///
        "Projected observations : " %12.0fc r(N)

    quietly summarize phk_projection if year==2026

    display as result ///
        "Mean projection        : " %12.2f r(mean)

    display as result ///
        "Median projection      : " %12.2f r(p50)

    display as result ///
        "Minimum projection     : " %12.2f r(min)

    display as result ///
        "Maximum projection     : " %12.2f r(max)


    *====================================================================
    * Top projected provinces
    *====================================================================

    preserve

    collapse (sum) phk_projection, by(prov_id)

    gsort -phk_projection

    display as text " "

    display as text "Top 10 projected provinces"

    list ///
        prov_id ///
        phk_projection ///
        in 1/10, ///
        noobs abbreviate(24)

    restore


    *====================================================================
    * Save forecasting dataset
    *====================================================================

    save "$output/phk_projection_2026.dta", replace



/*******************************************************************************
    7. PROVINCIAL FORECAST
*******************************************************************************/

    use "$output/phk_projection_2026.dta", clear

    *====================================================================
    * Monthly provincial projection
    *====================================================================

    keeporder ///
        prov_id ///
        ym ///
        year ///
        month ///
        phk_flow ///
        phk_projection

    sort prov_id ym

    save ///
        "$output/phk_projection_province_monthly.dta", ///
        replace

    export excel ///
        using "$output/phk_projection_province_monthly.xlsx", ///
        firstrow(variables) replace


    *====================================================================
    * Annual provincial projection
    *====================================================================

    preserve

    collapse ///
        (sum) phk_flow phk_projection, ///
        by(prov_id year)

    rename phk_flow actual_layoffs

    rename phk_projection projected_layoffs

    gen projection_gap = ///
        projected_layoffs - actual_layoffs

    gen projection_growth = ///
        100*(projected_layoffs-actual_layoffs)/actual_layoffs ///
        if actual_layoffs>0

    format actual_layoffs projected_layoffs %12.0fc
    format projection_growth %9.2f

    gsort year -projected_layoffs

    display as text " "

    display as text "Top projected provinces"

    list ///
        prov_id ///
        projected_layoffs ///
        if year==2026 ///
        in 1/10, ///
        noobs abbreviate(24)

    save ///
        "$output/phk_projection_province_annual.dta", ///
        replace

    export excel ///
        using "$output/phk_projection_province_annual.xlsx", ///
        firstrow(variables) replace

    restore



/*******************************************************************************
    8. NATIONAL FORECAST
*******************************************************************************/

    use "$output/phk_projection_2026.dta", clear

    *====================================================================
    * Monthly national projection
    *====================================================================

    collapse ///
        (sum) phk_flow phk_projection, ///
        by(ym year month)

    rename phk_flow actual_layoffs
    rename phk_projection projected_layoffs

    order ///
        ym ///
        year ///
        month ///
        actual_layoffs ///
        projected_layoffs

    sort ym

    *====================================================================
    * Annual totals
    *====================================================================

    bysort year: egen actual_layoffs_y    = total(actual_layoffs)
    bysort year: egen projected_layoffs_y = total(projected_layoffs)

    *====================================================================
    * Cumulative totals
    *====================================================================

    bysort year (ym): gen actual_cumulative    = sum(actual_layoffs)
    bysort year (ym): gen projected_cumulative = sum(projected_layoffs)

    *====================================================================
    * Month-on-month growth
    *====================================================================

    tsset ym

    gen actual_growth = ///
        100*(actual_layoffs-L.actual_layoffs)/L.actual_layoffs ///
        if L.actual_layoffs>0

    gen projected_growth = ///
        100*(projected_layoffs-L.projected_layoffs)/L.projected_layoffs ///
        if L.projected_layoffs>0

    format ///
        actual_layoffs ///
        projected_layoffs ///
        actual_layoffs_y ///
        projected_layoffs_y ///
        actual_cumulative ///
        projected_cumulative %12.0fc

    format ///
        actual_growth ///
        projected_growth %9.2f

    label variable actual_layoffs       "Actual monthly layoffs"
    label variable projected_layoffs    "Projected monthly layoffs"
    label variable actual_layoffs_y     "Annual actual layoffs"
    label variable projected_layoffs_y  "Annual projected layoffs"

    *====================================================================
    * Diagnostics
    *====================================================================

    display as text "==============================================================="
    display as text "National projection summary"
    display as text "==============================================================="

    list ///
        year ///
        month ///
        actual_layoffs ///
        projected_layoffs ///
        if year>=2025, ///
        noobs

    display as text " "

    display as result ///
        "Projected national layoffs (2026): " ///
        %12.0fc projected_layoffs_y[_N]

    *====================================================================
    * Save monthly dataset
    *====================================================================

    save ///
        "$output/phk_projection_national.dta", ///
        replace

    export excel ///
        using "$output/phk_projection_national.xlsx", ///
        firstrow(variables) replace


    *====================================================================
    * Annual national projection
    *====================================================================

    preserve

    collapse ///
        (first) ///
        actual_layoffs_y ///
        projected_layoffs_y, ///
        by(year)

    rename actual_layoffs_y actual_layoffs
    rename projected_layoffs_y projected_layoffs

    gen projection_gap = ///
        projected_layoffs - actual_layoffs

    gen projection_growth = ///
        100*(projected_layoffs-actual_layoffs)/actual_layoffs ///
        if actual_layoffs>0

    format actual_layoffs projected_layoffs %12.0fc
    format projection_growth %9.2f

    save ///
        "$output/phk_projection_national_annual.dta", ///
        replace

    export excel ///
        using "$output/phk_projection_national_annual.xlsx", ///
        firstrow(variables) replace

    restore


/*******************************************************************************
    9. FIGURES
*******************************************************************************/

    global GRAPH "$output/Figure"

    *====================================================================
    * 9.1 National Monthly Forecast
    *====================================================================

    use "$output/phk_projection_national.dta", clear

    twoway ///
        (line actual_layoffs ym if year<=2025, ///
            lcolor(navy) ///
            lwidth(medthick)) ///
        (line projected_layoffs ym if year==2026, ///
            lcolor(maroon) ///
            lpattern(dash) ///
            lwidth(medthick)), ///
        ///
        xtitle("") ///
        ytitle("Number of Layoffs") ///
        xlabel(, format(%tmMon_CCYY) angle(45)) ///
        ylabel(, format(%12.0fc)) ///
        legend( ///
            order(1 "Actual" 2 "Projected") ///
            position(6) ///
            rows(1)) ///
        title("National Layoff Projection") ///
        graphregion(color(white))

    graph export ///
        "$GRAPH/national_projection.png", ///
        width(2400) replace


    *====================================================================
    * 9.2 National Cumulative Forecast
    *====================================================================

    twoway ///
        (line actual_cumulative ym if year<=2025, ///
            lcolor(navy) ///
            lwidth(medthick)) ///
        (line projected_cumulative ym if year==2026, ///
            lcolor(maroon) ///
            lpattern(dash) ///
            lwidth(medthick)), ///
        ///
        xtitle("") ///
        ytitle("Cumulative Layoffs") ///
        xlabel(, format(%tmMon_CCYY) angle(45)) ///
        ylabel(, format(%12.0fc)) ///
        legend( ///
            order(1 "Actual" 2 "Projected") ///
            position(6) ///
            rows(1)) ///
        title("National Cumulative Layoff Projection") ///
        graphregion(color(white))

    graph export ///
        "$GRAPH/national_projection_cumulative.png", ///
        width(2400) replace


    *====================================================================
    * 9.3 Top 10 Projected Provinces
    *====================================================================

    use "$output/phk_projection_province_annual.dta", clear

    keep if year==2026

    gsort -projected_layoffs

    keep in 1/10

    graph hbar ///
        projected_layoffs, ///
        over(prov_id, sort(1) descending) ///
        ytitle("Projected Layoffs") ///
        title("Top 10 Projected Provinces") ///
        blabel(bar, format(%12.0fc)) ///
        graphregion(color(white))

    graph export ///
        "$GRAPH/top10_provinces.png", ///
        width(2400) replace
