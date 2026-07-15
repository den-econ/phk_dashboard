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


/********************************************************************
    0. SETUP
********************************************************************/
    
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


/********************************************************************
    1. MODEL METADATA
********************************************************************/
    
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



/********************************************************************
    2. DATA PREPARATION
********************************************************************/

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
    
    
/********************************************************************************
    3. ESTIMATION (SINGLE LAG MODELS) 
********************************************************************************/
    
    use     "$output/phk_panel_data.dta", clear

    * Define sample 
    gen     byte train = inrange(year,2023,2025)
    gen     byte valid = year==2025

    tempname results

    postfile `results' lag rmse mae using ///
            "$output/lag_selection.dta", replace

    eststo  clear 

    foreach L of global LAGS {

        display "==================================================================="
        display "Estimating Lag `L'"
        display "==================================================================="

        local   trigger

        foreach v of global TRIGGER {
            rename  L`L'_`v' L_`v'
            local   trigger `trigger' L_`v'
        }

        // Poisson regression
        eststo  lag_`L' :       poisson  $OUTCOME $STRUCTURE `trigger' i.month i.prov_id if train == 1, ///
                                vce(cluster prov_id)
        
        est     save    "$output/model_lag`L'.ster", replace

        qui     sum     $OUTCOME if _est_lag_`L' == 1
        estadd  local   dv_mean = string(round(r(mean)),"%9.0f")        : lag_`L'

        ereturn list
        estadd  local   p_r2    = string(round(e(r2_p),0.001),"%9.3f")  : lag_`L'
        
        estadd  local   region  "Province"                              : lag_`L'
        estadd  local   time    "Month"                                 : lag_`L'

        // Estimate prediction 
        est     store   lag_`L'

        est     save    "$output/regression_result/lag_`L'.ster", replace

        cap     drop    phk_hat

        predict phk_hat

        capture drop err sqerr abserr 

        gen     err     = phk_flow-phk_hat if valid == 1
        gen     sqerr   = err^2 if valid == 1
        gen     abserr  = abs(err) if valid == 1

        qui     summarize sqerr if valid == 1
        scalar  RMSE    = sqrt(r(mean))

        quietly summarize abserr if valid == 1
        scalar  MAE     = r(mean)

        post    `results'  (`L') (RMSE) (MAE)

        // Save results
        preserve

        keep if valid == 1
        keep    prov_id year month phk_flow phk_hat 
                
        save    "$output/projection_L`L'.dta", replace

        restore

        drop    L_*
    }

    esttab  lag_1 lag_3 lag_6 lag_12, keep($STRUCTURE L_*) ///
            mtitles b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) 

    
    /*
    esttab  lag_1 lag_3 lag_6 lag_12 using "$output/regression_result/lag_estimation_v`ver'.csv", replace ///
            keep($STRUCTURE L_*) ///
            mtitles b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
            stats(N dv_mean p_r2 region time , label("Observations" "DV Mean" "Pseudo R2" "Region FE" "Time FE") fmt(%15.0fc %4.3f 0 0))

    */

    local   note "The dependent variable is the monthly number of layoffs (PHK) by province. Robust standard errors clustered at the province level are reported in parentheses. Columns (1)-(4) report Poisson regression estimates using macroeconomic trigger variables lagged by 1, 3, 6, and 12 months, respectively. Annual structural variables are included contemporaneously in all specifications. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels."  
    local   numbers "& (1) & (2) & (3) & (4) \\ & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule"

    esttab  lag_1 lag_3 lag_6 lag_12 using "$output/regression_result/lag_estimation_v`ver'.tex", ///
            replace style(tex) booktabs cells(b(fmt(3) star) se(par fmt(3))) ///
            keep($STRUCTURE L_*) collabels(none) mlabels(none) nonum nomtitles nodepvars eqlabels(none) ///
            title("Poisson regression estimates for provincial layoff projections") ///
            prehead(`"\begin{table}[H]\centering"' `"\caption{@title}"' `"\small"' `"\renewcommand{\arraystretch}{1.15}"' ///
            `"\begin{adjustbox}{max width=\textwidth}"' `"\begin{tabular}{l*{@E}{c}}"' `"\toprule"') posthead("`numbers'") ///
            refcat( ///
                log_pdrb_y "\addlinespace\textbf{Structure Variables}" ///
                L_log_price_brent "\addlinespace\textbf{Macroeconomic Trigger Variables}", ///
                nolabel) ///
            stats(N dv_mean p_r2 region time, labels("Observations" "DV Mean" "Pseudo R$^2$" "Region FE" "Time FE") fmt(0 3 0 0)) ///
            postfoot(`"\bottomrule"' `"\end{tabular}"' `"\end{adjustbox}"' `"\begin{tablenotes}"' `"\footnotesize"' `"\item \textit{Notes:} `note'"' `"\end{tablenotes}"' `"\end{table}"')

    postclose `results'



/********************************************************************************
    4. ESTIMATION (CUMULATIVE LAG SPECIFICATIONS)
********************************************************************************/

    use "$output/phk_panel_data.dta", clear

    * Training sample
    gen byte train = inrange(year,2023,2025)
    
    * Model metadata
    local model1 "1"
    local model2 "1 3"
    local model3 "1 3 6"
    local model4 "1 3 6 12"

    local modelname1 "Lag 1"
    local modelname2 "Lag 1+3"
    local modelname3 "Lag 1+3+6"
    local modelname4 "Lag 1+3+6+12"

    eststo clear

    * Estimate cumulative lag models
    forvalues i = 1/4 {

        di as text "=========================================================="
        di as text "Estimating `modelname`i''"
        di as text "=========================================================="

        local trigger

        foreach L of local model`i' {

            foreach v of global TRIGGER {

                local trigger `trigger' L`L'_`v'

            }

        }

        quietly poisson ///
            $OUTCOME ///
            $STRUCTURE ///
            `trigger' ///
            i.month i.prov_id ///
            if train, ///
            vce(cluster prov_id)

        estimates store model_`i'

        quietly summarize $OUTCOME if e(sample)

        estadd scalar dv_mean = r(mean)
        estadd scalar p_r2 = e(r2_p)

        estadd local region "Yes"
        estadd local time   "Yes"

    }

    
    * Export regression table

    esttab  model_1 model_2 model_3 model_4, keep($STRUCTURE L*) ///
            mtitles b(3) star(* 0.10 ** 0.05 *** 0.01) 


    *local note "The dependent variable is the monthly number of layoffs (PHK) by province. Robust standard errors clustered at the province level are reported in parentheses. Columns (1)-(4) estimate single-lag specifications using macroeconomic trigger variables lagged by 1, 3, 6, and 12 months, respectively. Columns (5)-(7) estimate cumulative lag specifications. Annual structural variables are included contemporaneously in all specifications. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels, respectively."
    local note ""

    local numbers ///
    "& (1) & (2) & (3) & (4) \\" ///
    "& Lag 1 & Lag 1+3 & Lag 1+3+6 & Lag 1+3+6+12 \\\\ \midrule"

    esttab ///
        model_1 model_2 model_3 model_4 ///
        using "$output/regression_result/model_comparison.tex", ///
        replace ///
        style(tex) ///
        booktabs ///
        cells(b(fmt(3) star)) ///
        keep($STRUCTURE L*) ///
        collabels(none) ///
        mlabels(none) ///
        nonum ///
        nomtitles ///
        nodepvars ///
        eqlabels(none) ///
        label ///
        title("Comparison of alternative lag specifications") ///
        prehead(`"\begin{table}[H]\centering"' ///
                `"\caption{@title}"' ///
                `"\small"' ///
                `"\renewcommand{\arraystretch}{1.15}"' ///
                `"\begin{adjustbox}{max totalsize={\textwidth}{0.90\textheight}}"' ///
                `"\begin{tabular}{p{7cm}*{4}{>{\centering\arraybackslash}p{2.5cm}}}"' ///
                `"\toprule"') ///
        posthead("`numbers'") ///
        refcat( ///
            log_pdrb_y ///
            "\addlinespace\textbf{Structure Variables}" ///
            L1_log_price_brent ///
            "\addlinespace\textbf{Macroeconomic Trigger Variables}", ///
            nolabel) ///
        stats( ///
            N ///
            dv_mean ///
            p_r2 ///
            region ///
            time, ///
            labels( ///
                "Observations" ///
                "Mean monthly PHK" ///
                "Pseudo R$^2$" ///
                "Province FE" ///
                "Month FE") ///
            fmt(%15.0fc %4.2f %4.3f 0 0)) ///
        postfoot(`"\bottomrule"' ///
                 `"\end{tabular}"' ///
                 `"\end{adjustbox}"' ///
                 `"\begin{tablenotes}"' ///
                 `"\footnotesize"' ///
                 `"\end{tablenotes}"' ///
                 `"\end{table}"')


        *cells(b(fmt(3) star) se(par fmt(3))) ///


/*******************************************************************************
    5. PROJECTION TRAIN / VALIDATION (SINGLE-LAG MODELS)
*******************************************************************************/

    use "$output/phk_panel_data.dta", clear

    * Training and validation sample

    gen byte train = inrange(year,2023,2025)
    gen byte valid = year==2025

    * Store validation results

    tempname results

    postfile `results' ///
        lag ///
        N_valid ///
        rmse ///
        mae ///
        using "$output/lag_selection.dta", replace

    eststo clear

    foreach L of global LAGS {

        di
        di "==============================================================="
        di "Estimating Lag `L'"
        di "==============================================================="

        *--------------------------------------------------------------*
        * Lagged trigger variables
        *--------------------------------------------------------------*

        local trigger

        foreach v of global TRIGGER {
            local trigger `trigger' L`L'_`v'
        }

        *--------------------------------------------------------------*
        * Estimate model
        *--------------------------------------------------------------*

        eststo lag_`L': poisson ///
            $OUTCOME ///
            $STRUCTURE ///
            `trigger' ///
            i.month ///
            i.prov_id ///
            if train, ///
            vce(cluster prov_id)

        estadd local p_r2    = string(round(e(r2_p),0.001),"%9.3f")
        estadd local region  "Province"
        estadd local time    "Month"

        *--------------------------------------------------------------*
        * Validation prediction
        *--------------------------------------------------------------*

        capture drop phk_hat err sqerr abserr

        predict double phk_hat if valid

        gen err    = phk_flow - phk_hat if valid & !missing(phk_hat)
        gen sqerr  = err^2               if valid & !missing(phk_hat)
        gen abserr = abs(err)            if valid & !missing(phk_hat)

        quietly count if valid & !missing(phk_hat)
        local N_valid = r(N)

        quietly summarize sqerr if valid & !missing(phk_hat)
        scalar RMSE = sqrt(r(mean))

        quietly summarize abserr if valid & !missing(phk_hat)
        scalar MAE = r(mean)

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


    /********************************************************************************
        6. SELECT BEST MODEL
    ********************************************************************************/

        use     "$output/lag_selection.dta", clear

        sort    rmse
        list

        local   BEST = lag[1]
        display "Best Lag = `BEST'"
        

/*******************************************************************************
    6. PROJECTION (SINGLE-LAG MODELS)
*******************************************************************************/

    use "$output/phk_panel_data.dta", clear

    xtset prov_id ym

    * Forecast horizon
    quietly summarize ym if !missing(phk_flow)
    global LAST_YM = r(max)

    display as text "Latest observed month: " %tm $LAST_YM

    global FC_END = ym(2026,12)
    global FC_HORIZON = $FC_END - $LAST_YM

    * Extend panel
    tsappend, add($FC_HORIZON)

    replace year  = year(dofm(ym))  if missing(year)
    replace month = month(dofm(ym)) if missing(month)

    * Carry forward annual structural variables
    foreach var of global STRUCTURE {

        bysort prov_id (ym): ///
            replace `var' = `var'[_n-1] if missing(`var')

    }

    * Carry forward macro variables

    foreach var of global TRIGGER {

        bysort prov_id (ym): ///
            replace `var' = `var'[_n-1] if missing(`var')

    }

    * Reconstruct lag variables

    sort prov_id ym
    xtset prov_id ym

    foreach L of global LAGS {

        foreach var of global TRIGGER {

            capture drop L`L'_`var'

            gen L`L'_`var' = L`L'.`var'

        }

    }

    * Forecast variables

    gen phk_pred_l1  = .
    gen phk_pred_l3  = .
    gen phk_pred_l6  = .
    gen phk_pred_l12 = .

    local laglist "1 3 6 12"

    * Forecast loop

    foreach L of local laglist {

        di
        di "==============================================================="
        di " Forecast model: Lag `L'"
        di "==============================================================="

        *--------------------------------------------------------------*
        * Build lagged trigger variables
        *--------------------------------------------------------------*

        local trigger

        foreach var of global TRIGGER {

            local trigger `trigger' L`L'_`var'

        }

        *--------------------------------------------------------------*
        * Estimate forecasting model
        *--------------------------------------------------------------*

        quietly poisson ///
            $OUTCOME ///
            $STRUCTURE ///
            `trigger' ///
            i.month ///
            i.prov_id ///
            if year<=2025, ///
            vce(cluster prov_id)

        *--------------------------------------------------------------*
        * Generate projection
        *--------------------------------------------------------------*

        tempvar fit

        quietly predict double `fit'

        replace phk_pred_l`L' = `fit' if year==2026

        *--------------------------------------------------------------*
        * Projection availability
        *--------------------------------------------------------------*

        gen byte phk_pred_l`L'_available = ///
            !missing(phk_pred_l`L')

        *--------------------------------------------------------------*
        * Projection summary
        *--------------------------------------------------------------*

        quietly count if phk_pred_l`L'_available

        di as result ///
            "Projected observations : " ///
            r(N)

        quietly summarize ym if phk_pred_l`L'_available

        di as result ///
            "Projection available through : " ///
            %tm r(max)

        drop `fit'

    }

    * Overall projection summary

    di
    di "==============================================================="
    di " Projection Summary"
    di "==============================================================="

    foreach L of local laglist {

        quietly count if phk_pred_l`L'_available

        di as text ///
            "Lag `L' : " ///
            %4.0f r(N) ///
            " projected observations"

    }

    *====================================================================
    * Save projection dataset
    *====================================================================

    save "$output/phk_projection_2026.dta", replace






/*******************************************************************************
    7. NATIONAL PROJECTION
*******************************************************************************/

    use "$output/phk_projection_2026.dta", clear

    *====================================================================
    * National monthly projection
    *====================================================================

    collapse ///
        (sum) phk_flow ///
              phk_pred_l1 ///
              phk_pred_l3 ///
              phk_pred_l6 ///
              phk_pred_l12, ///
        by(year month ym)

    sort ym

    format ym %tm

    *====================================================================
    * Annual totals
    *====================================================================

    bysort year: egen phk_flow_y     = total(phk_flow)
    bysort year: egen phk_pred_l1_y  = total(phk_pred_l1)
    bysort year: egen phk_pred_l3_y  = total(phk_pred_l3)
    bysort year: egen phk_pred_l6_y  = total(phk_pred_l6)
    bysort year: egen phk_pred_l12_y = total(phk_pred_l12)

    order ///
        year month ym ///
        phk_flow ///
        phk_pred_l1 ///
        phk_pred_l3 ///
        phk_pred_l6 ///
        phk_pred_l12

    save "$output/phk_projection_national.dta", replace

    export excel using ///
        "$output/phk_projection_national.xlsx", ///
        firstrow(variables) replace



/*******************************************************************************
    8. GRAPH
*******************************************************************************/

    use "$output/phk_projection_national.dta", clear

    format ym %tm

    gen phk_actual = phk_flow if year<=2025

    gen phk_lag1 = phk_flow
    replace phk_lag1 = phk_pred_l1 if !missing(phk_pred_l1)

    gen phk_lag3 = phk_flow
    replace phk_lag3 = phk_pred_l3 if !missing(phk_pred_l3)

    gen phk_lag6 = phk_flow
    replace phk_lag6 = phk_pred_l6 if !missing(phk_pred_l6)

    gen phk_lag12 = phk_flow
    replace phk_lag12 = phk_pred_l12 if !missing(phk_pred_l12)

    twoway ///
        (connected phk_actual ym, ///
            lcolor(black) ///
            lwidth(medthick)) ///
        (connected phk_lag1 ym, ///
            lcolor(navy) ///
            lpattern(shortdash)) ///
        (connected phk_lag3 ym, ///
            lcolor(maroon) ///
            lpattern(dash)) ///
        (connected phk_lag6 ym, ///
            lcolor(forest_green) ///
            lpattern(longdash)), ///
        title("National Layoff Projection") ///
        xtitle("") ///
        ytitle("Number of layoffs") ///
        legend(order(1 "Actual" ///
                     2 "Lag 1" ///
                     3 "Lag 3" ///
                     4 "Lag 6" ///
                     5 "Lag 12")) ///
        graphregion(color(white))

    graph export ///
        "$output/phk_projection_comparison.png", ///
        replace width(1800)
