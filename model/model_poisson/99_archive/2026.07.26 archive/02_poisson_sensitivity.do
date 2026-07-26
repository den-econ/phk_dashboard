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

    keep if inrange(year, $EST_START, $EST_END)

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

        foreach v of global PRESSURE {
            rename  L`L'_`v' L_`v'
            local   trigger `trigger' L_`v'
        }

        eststo  lag_`L':    poisson $OUTCOME $ECON_STRUCTURE $LABOR_STRUCTURE `trigger' ///
                                    i.prov_id i.month, ///
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
        keep($ECON_STRUCTURE $LABOR_STRUCTURE L_*) ///
        order(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)

    * Export Excel
    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_coefficients.csv", ///
        replace ///
        keep($STRUCTURE L_*) ///
        order(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
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
    local   note "The dependent variable is the monthly number of PHK by province. Columns (1)--(4) report separate Poisson specifications in which all macroeconomic pressure indicators enter at lags of 1, 3, 6, and 12 months, respectively. Provincial economic and labor-market structural controls enter contemporaneously. All specifications include province and calendar-month fixed effects. Standard errors clustered at the province level are reported in parentheses. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels."
    
    local   numbers "& (1) & (2) & (3) & (4) \\ & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule"
    esttab  lag_1 lag_3 lag_6 lag_12 using "$latex/poisson_coefficients_all.tex", ///
            replace style(tex) booktabs cells(b(fmt(3) star) se(par fmt(3))) ///
            keep(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
            order(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
            collabels(none) mlabels(none) nonum nomtitles nodepvars eqlabels(none) ///
            title("Poisson Regression Estimates of PHK on Macroeconomic Pressures") ///
            prehead(`"\begin{table}[H]\centering"' ///
                `"\caption{@title}"' ///
                `"\small"' ///
                `"\renewcommand{\arraystretch}{1.15}"' ///
                `"\begin{adjustbox}{max totalsize={\textwidth}{0.80\textheight}}"' ///
                `"\begin{tabular}{p{7cm}*{4}{>{\centering\arraybackslash}p{2.5cm}}}"' ///
                `"\toprule"') ///
            posthead("`numbers'") ///
            refcat( ///
                L_log_price_brent   "\addlinespace\textbf{Macroeconomic Pressure (with lag)}" ///
                gov_pdrb_share      "\addlinespace\textbf{Provincial Economic Structure}" ///
                unemployment_rate   "\addlinespace\textbf{Provincial Labor Market Structure}", ///
                nolabel) ///
            stats(N dv_mean p_r2 region time, labels("Observations" "Monthly PHK Mean" "Pseudo R$^2$" "Region FE" "Time FE") fmt(0 3 0 0)) ///
            postfoot(`"\bottomrule"' `"\end{tabular}"' `"\end{adjustbox}"' `"\begin{tablenotes}"' `"\footnotesize"' `"\item \textit{Notes:} `note'"' `"\end{tablenotes}"' `"\end{table}"')
    

/*******************************************************************************
    INCIDENCE RATE RATIOS (IRR)
*******************************************************************************/

    * Preview in Stata
    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        eform ///
        keep($ECON_STRUCTURE $LABOR_STRUCTURE L_*) ///
        order(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
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
        keep($ECON_STRUCTURE $LABOR_STRUCTURE L_*) ///
        order(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
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
    "Entries report incidence rate ratios (IRRs), obtained by exponentiating the corresponding Poisson coefficients. Columns (1)--(4) jointly include all macroeconomic pressure indicators at lags of 1, 3, 6, and 12 months, respectively, together with contemporaneous provincial economic and labor-market structural controls, province fixed effects, and calendar-month fixed effects. An IRR above (below) one indicates a positive (negative) conditional association with expected PHK. The magnitude of each IRR should be interpreted according to the unit and transformation of the corresponding explanatory variable. Standard errors clustered at the province level are reported in parentheses. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels."
    
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
        keep($ECON_STRUCTURE $LABOR_STRUCTURE L_*) ///
        order(L_* $ECON_STRUCTURE $LABOR_STRUCTURE) ///
        collabels(none) ///
        mlabels(none) ///
        nonum ///
        nomtitles ///
        nodepvars ///
        eqlabels(none) ///
        title("Incidence Rate Ratios (IRR) from Poisson Regressions of PHK on Macroeconomic Pressures") ///
        prehead(`"\begin{table}[H]\centering"' ///
                `"\caption{@title}"' ///
                `"\small"' ///
                `"\renewcommand{\arraystretch}{1.15}"' ///
                `"\begin{adjustbox}{max totalsize={\textwidth}{0.80\textheight}}"' ///
                `"\begin{tabular}{p{7cm}*{4}{>{\centering\arraybackslash}p{2.5cm}}}"' ///
                `"\toprule"') ///
        posthead("`numbers'") ///
        refcat( ///
            L_log_price_brent   "\addlinespace\textbf{Macroeconomic Pressure (with lag)}" ///
            gov_pdrb_share      "\addlinespace\textbf{Provincial Economic Structure}" ///
            unemployment_rate   "\addlinespace\textbf{Provincial Labor Market Structure}", ///
            nolabel) ///
        stats( ///
            N ///
            dv_mean ///
            p_r2 ///
            region ///
            time, ///
            labels("Observations" ///
                   "Monthly PHK Mean" ///
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

    keep if inrange(year, $EST_START, $EST_END)

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


    foreach macro of global PRESSURE {

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
    EXPORT RESULTS
*******************************************************************************/

    use "$data/macro_sensitivity_results.dta", clear

    *------------------------------------------------------------*
    * Display Variables
    *------------------------------------------------------------*

    * IRR with significance stars
    gen str20 irr_disp = string(irr, "%4.2f") + stars

    * Direction of statistically significant coefficient
    gen str1 sign_disp = ""

    replace sign_disp = "+" if beta > 0 & stars != ""
    replace sign_disp = "-" if beta < 0 & stars != ""

    gen variable_order = .

    local i = 1

    foreach var of global PRESSURE {

        replace variable_order = `i' if indicator == "`var'"

        local ++i
    }


    list indicator if missing(variable_order), noobs

    *------------------------------------------------------------*
    *  EXPORT DASHBOARD CSV : IRR
    *------------------------------------------------------------*

    preserve

        keep indicator lag irr_disp variable_order

        reshape wide irr_disp, ///
            i(indicator variable_order) ///
            j(lag)

        rename irr_disp1  lag1
        rename irr_disp3  lag3
        rename irr_disp6  lag6
        rename irr_disp12 lag12

        * Sort automatically according to $PRESSURE
        sort variable_order

        drop variable_order

        order indicator lag1 lag3 lag6 lag12

        export delimited ///
            using "$table/macro_sensitivity_dashboard.csv", ///
            replace

    restore


    *------------------------------------------------------------*
    *   EXPORT LATEX TABLE : IRR
    *------------------------------------------------------------*

    preserve

        keep indicator lag irr_disp variable_order

        reshape wide irr_disp, ///
            i(indicator variable_order) ///
            j(lag)

        rename irr_disp1  lag1
        rename irr_disp3  lag3
        rename irr_disp6  lag6
        rename irr_disp12 lag12

        sort variable_order

     
        gen str100 indicator_tex = ///
            subinstr(indicator, "_", "\_", .)

        keep indicator_tex lag1 lag3 lag6 lag12

        listtex ///
            indicator_tex lag1 lag3 lag6 lag12 ///
            using "$latex/macro_sensitivity_IRR.tex", ///
            replace ///
            rstyle(tabular) ///
            head("\begin{table}[htbp]" ///
                 "\centering" ///
                 "\caption{Incidence Rate Ratios (IRRs) from Poisson Regressions}" ///
                 "\small" ///
                 "\begin{tabular}{lcccc}" ///
                 "\toprule" ///
                 "Variable & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule") ///
            foot("\bottomrule" ///
                 "\end{tabular}" ///
                 "\vspace{0.2cm}" ///
                 "\begin{minipage}{0.95\linewidth}" ///
                 "\footnotesize" ///
                 "\textit{Notes:} Each cell reports the incidence rate ratio (IRR) from a separate Poisson regression of monthly provincial PHK on the indicated lagged macroeconomic pressure variable, controlling for provincial economic and labor-market structure, province fixed effects, and calendar-month fixed effects. IRRs are obtained by exponentiating the estimated Poisson coefficients. An IRR above (below) one indicates a positive (negative) association with expected PHK. The magnitude of the IRR should be interpreted according to the unit and transformation of each explanatory variable. Standard errors are clustered at the province level. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels." ///
                 "\end{minipage}" ///
                 "\end{table}")

    restore


    *------------------------------------------------------------*
    *   EXPORT LATEX TABLE : SIGN OF EFFECT
    *------------------------------------------------------------*

    preserve

        keep indicator lag sign_disp variable_order

        reshape wide sign_disp, ///
            i(indicator variable_order) ///
            j(lag)

        rename sign_disp1  lag1
        rename sign_disp3  lag3
        rename sign_disp6  lag6
        rename sign_disp12 lag12

        *------------------------------------------------------------*
        * Sort automatically according to $PRESSURE
        *------------------------------------------------------------*

        sort variable_order

        *------------------------------------------------------------*
        * Create separate LaTeX-safe variable name
        *------------------------------------------------------------*

        gen str100 indicator_tex = ///
            subinstr(indicator, "_", "\_", .)

        keep indicator_tex lag1 lag3 lag6 lag12

        listtex ///
            indicator_tex lag1 lag3 lag6 lag12 ///
            using "$latex/macro_sensitivity_sign.tex", ///
            replace ///
            rstyle(tabular) ///
            head("\begin{table}[htbp]" ///
                 "\centering" ///
                 "\caption{Direction of Significant Associations between Lagged Macroeconomic Indicators and PHK}" ///
                 "\small" ///
                 "\begin{tabular}{lcccc}" ///
                 "\toprule" ///
                 "Variable & Lag 1 & Lag 3 & Lag 6 & Lag 12 \\ \midrule") ///
            foot("\bottomrule" ///
                 "\end{tabular}" ///
                 "\vspace{0.2cm}" ///
                 "\begin{minipage}{0.95\linewidth}" ///
                 "\footnotesize" ///
                 "\textit{Notes:} Each cell summarizes the estimated association from a separate Poisson regression of monthly provincial PHK on the indicated lagged macroeconomic pressure variable, controlling for provincial economic and labor-market structure, province fixed effects, and calendar-month fixed effects. '+' ('-') denotes a positive (negative) association statistically significant at the 10\% level or better. Blank cells denote estimates that are not statistically significant at the 10\% level." ///
                 "\end{minipage}" ///
                 "\end{table}")

    restore

