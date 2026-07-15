/*******************************************************************************
02. POISSON SENSITIVITY
*******************************************************************************/

do "$dofile/00_config.do"

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
        using "$data/poisson_model_summary.dta", replace

    foreach L of global LAGS {

        di
        di "==============================================================="
        di "Estimating Poisson Model (Lag `L')"
        di "==============================================================="

        local trigger

        foreach v of global TRIGGER {
            local trigger `trigger' L`L'_`v'
        }

        eststo lag_`L' : ///
            poisson ///
                $OUTCOME ///
                $STRUCTURE ///
                `trigger' ///
                i.month i.prov_id, ///
                vce(cluster prov_id)

        estimates save ///
            "$model/model_lag`L'.ster", replace

        estadd local region "Province" : lag_`L'
        estadd local time   "Month"    : lag_`L'

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
            (`BIC')

    }

    postclose `summary'


/*******************************************************************************
    REGRESSION COEFFICIENTS
*******************************************************************************/

    local report_order

    foreach v of global STRUCTURE {
        local report_order `report_order' `v'
    }

    foreach L of global LAGS {

        foreach v of global TRIGGER {

            local report_order `report_order' L`L'_`v'

        }

    }

    * Preview in Stata
    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        keep(`report_order') ///
        order(`report_order') ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)

    * Export LaTeX
    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_coefficients.tex", ///
        replace ///
        booktabs ///
        label ///
        compress ///
        nonotes ///
        alignment(D{.}{.}{-1}) ///
        keep(`report_order') ///
        order(`report_order') ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats( ///
            N ///
            p_r2 ///
            region ///
            time, ///
            labels( ///
                "Observations" ///
                "Pseudo R-squared" ///
                "Province FE" ///
                "Month FE") ///
            fmt(%15.0fc %9.3f 0 0))

    * Export Excel
    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_coefficients.xlsx", ///
        replace ///
        keep(`report_order') ///
        order(`report_order') ///
        cells(b(fmt(3)) se(par fmt(3))) ///
        stats( ///
            N ///
            p_r2 ///
            region ///
            time, ///
            fmt(%15.0fc %9.3f 0 0))



/*******************************************************************************
    INCIDENCE RATE RATIOS (IRR)
*******************************************************************************/

    * Preview in Stata
    esttab ///
        lag_1 lag_3 lag_6 lag_12, ///
        eform ///
        keep(`report_order') ///
        order(`report_order') ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01)

    * Export LaTeX
    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_irr.tex", ///
        replace ///
        eform ///
        booktabs ///
        label ///
        compress ///
        nonotes ///
        alignment(D{.}{.}{-1}) ///
        keep(`report_order') ///
        order(`report_order') ///
        mtitles("Lag 1" "Lag 3" "Lag 6" "Lag 12") ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats( ///
            N ///
            p_r2 ///
            region ///
            time, ///
            labels( ///
                "Observations" ///
                "Pseudo R-squared" ///
                "Province FE" ///
                "Month FE") ///
            fmt(%15.0fc %9.3f 0 0))

    * Export Excel
    esttab ///
        lag_1 lag_3 lag_6 lag_12 ///
        using "$table/poisson_irr.xlsx", ///
        replace ///
        eform ///
        keep(`report_order') ///
        order(`report_order') ///
        cells(b(fmt(3)) se(par fmt(3))) ///
        stats( ///
            N ///
            p_r2 ///
            region ///
            time, ///
            fmt(%15.0fc %9.3f 0 0))


/*******************************************************************************
    5. MODEL SUMMARY
*******************************************************************************/

    use "$data/poisson_model_summary.dta", clear

    sort lag

    list, noobs

    export excel ///
        using "$table/poisson_model_summary.xlsx", ///
        firstrow(variables) ///
        replace
