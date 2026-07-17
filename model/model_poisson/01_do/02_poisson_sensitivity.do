* =============================================================================
* Project           : PHK Dashboard
* Description       : Develop Model to Project PHK  
* Stata version     : 16
* Date created      : 13 July 2026 by Bertha
* Last modified     : 13 July 2026 by Bertha
* =============================================================================


*******************************************************************************
*******************************************************************************
///////////////////////// MACRO SENSITIVITY ///////////////////////////////////
*******************************************************************************
*******************************************************************************

do "$dofile/00_config.do"
do "$dofile/01_prepare_panel.do"

capture log close
set more off


/*******************************************************************************
    LOAD PANEL
*******************************************************************************/

    use "$panel", clear

    keep if inrange(year, $TRAIN_START, $VALID_END)

    xtset prov_id ym


/*******************************************************************************
    ESTIMATE POISSON MODELS
*******************************************************************************/

    eststo clear

    tempname summary

    postfile `summary' ///
        lag ///
        N ///
        p_r2 ///
        ll ///
        aic ///
        bic ///
        rmse ///
        mae ///
        using "$data/poisson_model_summary.dta", replace

    foreach L of global LAGS {

        di
        di "==============================================================="
        di "Estimating Poisson Model (Lag `L')"
        di "==============================================================="

        local trigger

        foreach v of global TRIGGER {
            rename  L`L'_`v' L_`v'
            local   trigger `trigger' L_`v'
        }

        eststo  lag_`L' : poisson $OUTCOME $STRUCTURE `trigger' i.month i.prov_id, ///
                vce(cluster prov_id)

        est     save "$model/model_lag`L'.ster", replace

        qui     sum     $OUTCOME if _est_lag_`L' == 1
        estadd  local   dv_mean = string(round(r(mean)),"%9.0f")        : lag_`L'
        estadd  local   p_r2    = string(round(e(r2_p),0.001),"%9.3f")  : lag_`L'

        estadd  local   region "Province"                               : lag_`L'
        estadd  local   time   "Month"                                  : lag_`L'


        cap     drop    phk_hat
        predict phk_hat

        capture drop err sqerr abserr 

        gen     err     = phk_flow-phk_hat 
        gen     sqerr   = err^2 
        gen     abserr  = abs(err) 

        qui     summarize sqerr 
        scalar  RMSE    = sqrt(r(mean))

        quietly summarize abserr 
        scalar  MAE     = r(mean)


        quietly estat ic

        matrix IC = r(S)

        local AIC = IC[1,5]
        local BIC = IC[1,6]

        post `summary' ///
            (`L') ///
            (e(N)) ///
            (e(r2_p)) ///
            (e(ll)) ///
            (`AIC') ///
            (`BIC') ///
            (RMSE) ///
            (MAE)

        // Save results
        preserve

        keep    prov_id year month phk_flow phk_hat 
                
        save    "$data/projection_L`L'.dta", replace

        restore

        drop    L_*

    }

    postclose `summary'


/*******************************************************************************
    REGRESSION COEFFICIENTS
*******************************************************************************/

    * Preview in Stata
    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        keep($STRUCTURE L_*) ///
        order($STRUCTURE L_*) ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)

    * Export Excel
    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_coefficients.csv", ///
        replace ///
        keep($STRUCTURE L_*) ///
        order($STRUCTURE L_*) ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats( ///
            N ///
            dv_mean ///
            p_r2 ///
            region ///
            time, ///
            labels("Observations" ///
                   "Monthly PHK Mean" ///
                   "Pseudo R2" ///
                   "Region FE" ///
                   "Time FE") ///
            fmt(%15.0fc %9.0f %9.3f 0 0))


    * Export LaTeX
    local   note "The dependent variable is the monthly number of layoffs (PHK) by province. Robust standard errors clustered at the province level are reported in parentheses. Columns (1)-(4) report Poisson regression estimates using macroeconomic trigger variables lagged by 1, 3, 6, and 12 months, respectively. Annual structural variables are included contemporaneously in all specifications. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels."  
    
    
    local   numbers "& (1) & (2) & (3) \\ & Lag 1 & Lag 3 & Lag 6 \\ \midrule"

    esttab  lag_1 lag_3 lag_6 using "$latex/poisson_coefficients.tex", ///
            replace style(tex) booktabs cells(b(fmt(3) star) se(par fmt(3))) ///
            keep($STRUCTURE L_*) collabels(none) mlabels(none) nonum nomtitles nodepvars eqlabels(none) ///
            title("Poisson regression estimates for provincial layoff projections") ///
            prehead(`"\begin{table}[H]\centering"' `"\caption{@title}"' `"\small"' `"\renewcommand{\arraystretch}{1.15}"' ///
            `"\begin{adjustbox}{max width=\textwidth}"' `"\begin{tabular}{l*{@E}{c}}"' `"\toprule"') posthead("`numbers'") ///
            refcat( ///
                formal_lab_share "\addlinespace\textbf{Structure Variables}" ///
                L_log_price_brent   "\addlinespace\textbf{Macroeconomic Trigger Variables}", ///
                nolabel) ///
            stats(N dv_mean p_r2 region time, labels("Observations" "DV Mean" "Pseudo R$^2$" "Region FE" "Time FE") fmt(0 3 0 0)) ///
            postfoot(`"\bottomrule"' `"\end{tabular}"' `"\end{adjustbox}"' `"\begin{tablenotes}"' `"\footnotesize"' `"\item \textit{Notes:} `note'"' `"\end{tablenotes}"' `"\end{table}"')
    
    


    local   numbers "& (1) & (2) & (3) & (4) \\ & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule"

    esttab  lag_1 lag_3 lag_6 lag_12 using "$latex/poisson_coefficients_all.tex", ///
            replace style(tex) booktabs cells(b(fmt(3) star) se(par fmt(3))) ///
            keep($STRUCTURE L_*) collabels(none) mlabels(none) nonum nomtitles nodepvars eqlabels(none) ///
            title("Poisson regression estimates for provincial layoff projections") ///
            prehead(`"\begin{table}[H]\centering"' `"\caption{@title}"' `"\small"' `"\renewcommand{\arraystretch}{1.15}"' ///
            `"\begin{adjustbox}{max width=\textwidth}"' `"\begin{tabular}{l*{@E}{c}}"' `"\toprule"') posthead("`numbers'") ///
            refcat( ///
                formal_lab_share "\addlinespace\textbf{Structure Variables}" ///
                L_log_price_brent  "\addlinespace\textbf{Macroeconomic Trigger Variables}", ///
                nolabel) ///
            stats(N dv_mean p_r2 region time, labels("Observations" "DV Mean" "Pseudo R$^2$" "Region FE" "Time FE") fmt(0 3 0 0)) ///
            postfoot(`"\bottomrule"' `"\end{tabular}"' `"\end{adjustbox}"' `"\begin{tablenotes}"' `"\footnotesize"' `"\item \textit{Notes:} `note'"' `"\end{tablenotes}"' `"\end{table}"')
    
    


/*******************************************************************************
    INCIDENCE RATE RATIOS (IRR)
*******************************************************************************/

    * Preview in Stata
    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        eform ///
        keep($STRUCTURE L_*) ///
        order($STRUCTURE L_*) ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        cells(b(star fmt(2)) se(par fmt(2))) ///
        star(* 0.10 ** 0.05 *** 0.01)

    *-------------------------------*
    * Export CSV
    *-------------------------------*

    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_IRR.csv", ///
        replace ///
        eform ///
        keep($STRUCTURE L_*) ///
        order($STRUCTURE L_*) ///
        cells(b(star fmt(2)) se(par fmt(2))) ///
        stats( ///
            N ///
            dv_mean ///
            p_r2 ///
            region ///
            time, ///
            labels("Observations" ///
                   "Monthly PHK Mean" ///
                   "Pseudo R2" ///
                   "Region FE" ///
                   "Time FE") ///
            fmt(%15.0fc %9.0f %9.3f 0 0))

*-------------------------------*
* Export LaTeX
*-------------------------------*

    local note ///
    "Reported coefficients are Incidence Rate Ratios (IRRs), obtained by exponentiating the estimated Poisson coefficients. An IRR greater than one indicates that an increase in the explanatory variable is associated with a higher expected number of layoffs, while an IRR below one indicates a lower expected number of layoffs, holding other variables constant. Robust standard errors clustered at the province level are reported in parentheses. Columns (1)--(4) report specifications using macroeconomic trigger variables lagged by 1, 3, 6, and 12 months, respectively. Annual structural variables are included contemporaneously in all specifications. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels."

      local numbers ///
    "& (1) & (2) & (3) \\" ///
    "& Lag 1 & Lag 3 & Lag 6 \\ \midrule"

    esttab ///
        lag_1 lag_3 lag_6 ///
        using "$latex/poisson_IRR.tex", ///
        replace ///
        eform ///
        style(tex) ///
        booktabs ///
        cells(b(fmt(2) star) se(par fmt(2))) ///
        keep($STRUCTURE L_*) ///
        order($STRUCTURE L_*) ///
        collabels(none) ///
        mlabels(none) ///
        nonum ///
        nomtitles ///
        nodepvars ///
        eqlabels(none) ///
        title("Incidence Rate Ratios (IRR) from Poisson regressions for provincial layoff projections") ///
        prehead(`"\begin{table}[H]\centering"' ///
                `"\caption{@title}"' ///
                `"\small"' ///
                `"\renewcommand{\arraystretch}{1.15}"' ///
                `"\begin{adjustbox}{max width=\textwidth}"' ///
                `"\begin{tabular}{l*{@E}{c}}"' ///
                `"\toprule"') ///
        posthead("`numbers'") ///
        refcat( ///
            formal_lab_share "\addlinespace\textbf{Structure Variables}" ///
            L_log_price_brent  "\addlinespace\textbf{Macroeconomic Trigger Variables}", ///
            nolabel) ///
        stats( ///
            N ///
            dv_mean ///
            p_r2 ///
            region ///
            time, ///
            labels("Observations" ///
                   "DV Mean" ///
                   "Pseudo R$^2$" ///
                   "Region FE" ///
                   "Time FE") ///
            fmt(0 0 3 0 0)) ///
        postfoot(`"\bottomrule"' ///
                 `"\end{tabular}"' ///
                 `"\end{adjustbox}"' ///
                 `"\begin{tablenotes}"' ///
                 `"\footnotesize"' ///
                 `"\item \textit{Notes:} `note'"' ///
                 `"\end{tablenotes}"' ///
                 `"\end{table}"')


    
    local numbers ///
    "& (1) & (2) & (3) & (4) \\" ///
    "& Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule"

    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$latex/poisson_IRR_all.tex", ///
        replace ///
        eform ///
        style(tex) ///
        booktabs ///
        cells(b(fmt(2) star) se(par fmt(2))) ///
        keep($STRUCTURE L_*) ///
        order($STRUCTURE L_*) ///
        collabels(none) ///
        mlabels(none) ///
        nonum ///
        nomtitles ///
        nodepvars ///
        eqlabels(none) ///
        title("Incidence Rate Ratios (IRR) from Poisson regressions for provincial layoff projections") ///
        prehead(`"\begin{table}[H]\centering"' ///
                `"\caption{@title}"' ///
                `"\small"' ///
                `"\renewcommand{\arraystretch}{1.15}"' ///
                `"\begin{adjustbox}{max width=\textwidth}"' ///
                `"\begin{tabular}{l*{@E}{c}}"' ///
                `"\toprule"') ///
        posthead("`numbers'") ///
        refcat( ///
            formal_lab_share "\addlinespace\textbf{Structure Variables}" ///
            L_log_price_brent  "\addlinespace\textbf{Macroeconomic Trigger Variables}", ///
            nolabel) ///
        stats( ///
            N ///
            dv_mean ///
            p_r2 ///
            region ///
            time, ///
            labels("Observations" ///
                   "DV Mean" ///
                   "Pseudo R$^2$" ///
                   "Region FE" ///
                   "Time FE") ///
            fmt(0 0 3 0 0)) ///
        postfoot(`"\bottomrule"' ///
                 `"\end{tabular}"' ///
                 `"\end{adjustbox}"' ///
                 `"\begin{tablenotes}"' ///
                 `"\footnotesize"' ///
                 `"\item \textit{Notes:} `note'"' ///
                 `"\end{tablenotes}"' ///
                 `"\end{table}"')



/*******************************************************************************
    MACRO SENSITIVITY ANALYSIS
    One Poisson model for each macro indicator
*******************************************************************************/

    use "$panel", clear

    keep if inrange(year, $TRAIN_START, $VALID_END)

    eststo clear

    tempname results

    postfile `results' ///
        str30 indicator ///
        lag ///
        beta ///
        irr ///
        se ///
        ll95 ///
        ul95 ///
        z ///
        pvalue ///
        str3 stars ///
        N ///
        pseudo_r2 ///
        using "$data/macro_sensitivity_results.dta", replace


    foreach macro of global TRIGGER {

        di
        di "========================================================="
        di "Macro Indicator : `macro'"
        di "========================================================="

        foreach L of global LAGS {

            preserve

            rename L`L'_`macro' L_macro

            qui eststo `macro'_L`L' : poisson /// 
                $OUTCOME ///
                $STRUCTURE ///
                L_macro ///
                i.month ///
                i.prov_id, ///
                vce(cluster prov_id)

            *-------------------------------*
            * Extract coefficient
            *-------------------------------*

            scalar beta = _b[L_macro]
            scalar se   = _se[L_macro]

            scalar irr  = exp(beta)
            scalar lb   = exp(beta - 1.96*se)
            scalar ub   = exp(beta + 1.96*se)

            scalar z    = beta/se
            scalar p    = 2*normal(-abs(z))
            scalar pr2  = e(r2_p)

            local stars ""

            if (p < 0.10) local stars "*"
            if (p < 0.05) local stars "**"
            if (p < 0.01) local stars "***"

            post `results' ///
                ("`macro'") ///
                (`L') ///
                (beta) ///
                (irr) ///
                (se) ///
                (lb) ///
                (ub) ///
                (z) ///
                (p) ///
                ("`stars'") ///
                (e(N)) ///
                (pr2)

            restore

        }

    }

    postclose `results'



/*******************************************************************************
    LOAD RESULTS
*******************************************************************************/

    use "$data/macro_sensitivity_results.dta", clear

    /*******************************************************************************
        DISPLAY VARIABLES
    *******************************************************************************/

    * IRR with significance stars
    gen irr_disp = string(irr,"%4.2f") + stars

    * Direction of coefficient (+/-) with significance stars
    gen sign_disp = ""

    replace sign_disp = "+" if beta > 0 & stars != ""
    replace sign_disp = "-" if beta < 0 & stars != ""
    replace sign_disp = ""  if stars == ""


    /*******************************************************************************
        EXPORT DASHBOARD CSV (IRR)
    *******************************************************************************/

    preserve

    keep indicator lag irr_disp

    reshape wide irr_disp, i(indicator) j(lag)

    rename irr_disp1  lag1
    rename irr_disp3  lag3
    rename irr_disp6  lag6
    rename irr_disp12 lag12

    *------------------------------------------------------------*
    * Add variable order here later
    *------------------------------------------------------------*

    sort indicator

    export delimited ///
        using "$table/macro_sensitivity_dashboard.csv", ///
        replace

    restore


/*******************************************************************************
    EXPORT LATEX TABLE : IRR ONLY
*******************************************************************************/
    ***
    replace indicator = subinstr(indicator, "_", "\_", .)
    ***
    preserve

    keep indicator lag irr_disp

    reshape wide irr_disp, i(indicator) j(lag)

    rename irr_disp1  lag1
    rename irr_disp3  lag3
    rename irr_disp6  lag6
    rename irr_disp12 lag12

*------------------------------------------------------------*
* Add variable order here later
*------------------------------------------------------------*

    //sort indicator

    keep indicator lag1 lag3 lag6 lag12

    listtex ///
    indicator lag1 lag3 lag6 lag12 ///
    using "$latex/macro_sensitivity_IRR.tex", ///
    replace ///
    rstyle(tabular) ///
    head("\begin{table}[htbp]" ///
     "\centering" ///
     "\caption{Incidence Rate Ratios (IRRs) from Poisson regressions}" ///
     "\small" ///
     "\begin{tabular}{lcccc}" ///
     "\toprule" ///
     "Variable & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule") ///
    foot("\bottomrule" ///
     "\end{tabular}" ///
     "\vspace{0.2cm}" ///
     "\begin{minipage}{0.95\linewidth}" ///
     "\footnotesize" ///
     "\textit{Notes:} Entries are incidence rate ratios (IRRs). Each row reports a separate Poisson regression including one macroeconomic indicator (with respective lag), structural provincial controls, province fixed effects, and month fixed effects. Standard errors are clustered at the province level. *, ** and *** denote significance at the 10\%, 5\% and 1\% levels." ///
     "\end{minipage}" ///
     "\end{table}")

    restore


/*******************************************************************************
    EXPORT LATEX TABLE : SIGN OF EFFECT
*******************************************************************************/

    preserve

    keep indicator lag sign_disp

    reshape wide sign_disp, i(indicator) j(lag)

    rename sign_disp1  lag1
    rename sign_disp3  lag3
    rename sign_disp6  lag6
    rename sign_disp12 lag12

    *------------------------------------------------------------*
    * Add variable order here later
    *------------------------------------------------------------*

    //sort indicator

    keep indicator lag1 lag3 lag6 lag12

    listtex ///
        indicator lag1 lag3 lag6 lag12 ///
        using "$latex/macro_sensitivity_sign.tex", ///
        replace ///
        rstyle(tabular) ///
        head("\begin{table}[htbp]" ///
             "\centering" ///
             "\caption{Direction of Significant Effects from Poisson Regressions}" ///
             "\small" ///
             "\begin{tabular}{lcccc}" ///
             "\toprule" ///
             "Variable & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule") ///
        foot("\bottomrule" ///
             "\end{tabular}" ///
             "\vspace{0.2cm}" ///
             "\begin{minipage}{0.95\linewidth}" ///
             "\footnotesize" ///
             "\textit{Notes:} '+' ('-') denotes a positive (negative) statistically significant coefficient. Blank cells indicate that the estimated coefficient is not statistically significant." ///
             "\end{minipage}" ///
             "\end{table}")

    restore


* ######################################################################################################################################

0


/*******************************************************************************
    PREPARE RESULTS FOR REPORTING
*******************************************************************************/

    use "$data/macro_sensitivity_results.dta", clear

    *------------------------------------------------------------*
    * Indicator labels
    *------------------------------------------------------------*

    replace indicator = "Brent Oil Price"          if indicator=="price_brent_yoy"
    replace indicator = "BI Rate"                  if indicator=="bi_rate"
    replace indicator = "Exchange Rate (IDR/USD)"  if indicator=="fx_idr_usd_yoy"
    replace indicator = "Manufacturing PMI"        if indicator=="pmi_manuf"
    replace indicator = "Wholesale Price Index"    if indicator=="ihpb_yoy"
    replace indicator = "Consumer Price Index"     if indicator=="cpi_yoy"
    replace indicator = "Non-Performing Loans"     if indicator=="npl_yoy"
    replace indicator = "Exports"                  if indicator=="export_yoy"
    replace indicator = "Imports"                  if indicator=="import_yoy"

    *------------------------------------------------------------*
    * Dashboard display
    *------------------------------------------------------------*

    gen irr_disp = string(irr,"%4.2f") + stars

    *------------------------------------------------------------*
    * Confidence interval
    *------------------------------------------------------------*

    gen ci = "(" + ///
             string(ll95,"%4.2f") + ///
             ", " + ///
             string(ul95,"%4.2f") + ///
             ")"


    /*******************************************************************************
        EXPORT DASHBOARD CSV
    *******************************************************************************/

    preserve

    keep indicator lag irr_disp

    reshape wide irr_disp, i(indicator) j(lag)

    rename irr_disp1  lag1
    rename irr_disp3  lag3
    rename irr_disp6  lag6
    rename irr_disp12 lag12

    gen order = .

    replace order = 1 if indicator=="Brent Oil Price"
    replace order = 2 if indicator=="BI Rate"
    replace order = 3 if indicator=="Exchange Rate (IDR/USD)"
    replace order = 4 if indicator=="Manufacturing PMI"
    replace order = 5 if indicator=="Wholesale Price Index"
    replace order = 6 if indicator=="Consumer Price Index"
    replace order = 7 if indicator=="Non-Performing Loans"
    replace order = 8 if indicator=="Exports"
    replace order = 9 if indicator=="Imports"

    sort order
    drop order

    export delimited ///
        using "$table/macro_sensitivity_dashboard.csv", ///
        replace

    restore


    /*******************************************************************************
        EXPORT LATEX TABLE
    *******************************************************************************/

    preserve

    keep indicator lag irr_disp ci

    reshape wide ///
        irr_disp ///
        ci, ///
        i(indicator) ///
        j(lag)

    gen lag1  = irr_disp1  + char(10) + ci1
    gen lag3  = irr_disp3  + char(10) + ci3
    gen lag6  = irr_disp6  + char(10) + ci6
    gen lag12 = irr_disp12 + char(10) + ci12

    gen order = .

    replace order = 1 if indicator=="Brent Oil Price"
    replace order = 2 if indicator=="BI Rate"
    replace order = 3 if indicator=="Exchange Rate (IDR/USD)"
    replace order = 4 if indicator=="Manufacturing PMI"
    replace order = 5 if indicator=="Wholesale Price Index"
    replace order = 6 if indicator=="Consumer Price Index"
    replace order = 7 if indicator=="Non-Performing Loans"
    replace order = 8 if indicator=="Exports"
    replace order = 9 if indicator=="Imports"

    sort order
    drop order

    keep indicator lag1 lag3 lag6 lag12

    listtex ///
        indicator lag1 lag3 lag6 lag12  ///
        using "$latex/macro_sensitivity_dashboard.tex", ///
        replace ///
        rstyle(tabular) ///
        head("\begin{table}[htbp]" ///
             "\centering" ///
             "\caption{Incidence Rate Ratios (IRRs) from Poisson regressions for macro sensitivity analysis}" ///
             "\small" ///
             "\begin{tabular}{lcccc}" ///
             "\toprule" ///
             "Indicator & Lag 1 & Lag 3 & Lag 6 \\ \midrule") ///
        foot("\bottomrule" ///
             "\end{tabular}" ///
             "\vspace{0.2cm}" ///
             "\begin{minipage}{0.95\linewidth}" ///
             "\footnotesize" ///
             "\textit{Notes:} Each row reports the result from a separate Poisson regression including one macroeconomic indicator, structural variables, province fixed effects, and month fixed effects. Entries are Incidence Rate Ratios (IRRs), with 95\% confidence intervals shown beneath. Standard errors are clustered at the province level. *, **, and *** denote significance at the 10\%, 5\%, and 1\% levels." ///
             "\end{minipage}" ///
             "\end{table}")

    restore
