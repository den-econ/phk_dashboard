/*******************************************************************************
03. POISSON FORECAST
*******************************************************************************/

do "$dofile/00_config.do"

capture log close
set more off

use "$panel", clear

xtset prov_id ym


/*******************************************************************************
    TRAIN / VALIDATION SPLIT
*******************************************************************************/

    capture drop train valid

    gen train = inrange(year, $TRAIN_START, $TRAIN_END)

    gen valid = inrange(year, $VALID_START, $VALID_END)

    tab year train

    tab year valid


/*******************************************************************************
    MODEL COMPARISON
*******************************************************************************/

    tempname results

    postfile `results' ///
        lag ///
        rmse ///
        mae ///
        using "$data/lag_selection.dta", replace

    foreach L of global LAGS {

        di
        di "==============================================================="
        di "Estimating Lag `L'"
        di "==============================================================="

        *--------------------------------------------------------------
        * Lagged trigger variables
        *--------------------------------------------------------------

        local trigger

        foreach v of global TRIGGER {

            local trigger `trigger' L`L'_`v'

        }

        *--------------------------------------------------------------
        * Estimate Poisson model
        *--------------------------------------------------------------

        quietly poisson ///
            $OUTCOME ///
            $STRUCTURE ///
            `trigger' ///
            i.month ///
            i.prov_id ///
            if train == 1, ///
            vce(cluster prov_id)

        *--------------------------------------------------------------
        * Validation prediction
        *--------------------------------------------------------------

        capture drop phk_hat

        predict phk_hat, n

        *--------------------------------------------------------------
        * Forecast accuracy
        *--------------------------------------------------------------

        capture drop err sqerr abserr

        gen err    = phk_flow - phk_hat if valid == 1
        gen sqerr  = err^2              if valid == 1
        gen abserr = abs(err)           if valid == 1

        quietly summarize sqerr if valid == 1

        scalar RMSE = sqrt(r(mean))

        quietly summarize abserr if valid == 1

        scalar MAE = r(mean)

        post `results' ///
            (`L') ///
            (RMSE) ///
            (MAE)

        *--------------------------------------------------------------
        * Save validation prediction
        *--------------------------------------------------------------

        preserve

            keep if valid == 1

            keep ///
                prov_id ///
                year ///
                month ///
                ym ///
                phk_flow ///
                phk_hat

            save ///
                "$data/validation_lag`L'.dta", ///
                replace

        restore

    }

    postclose `results'


/*******************************************************************************
    SELECT BEST MODEL
*******************************************************************************/

    use "$data/lag_selection.dta", clear

    sort rmse mae

    list, noobs

    global BEST_LAG = lag[1]

    display "==============================================================="
    display "Best forecasting model: Lag $BEST_LAG"
    display "==============================================================="

    export excel ///
        using "$table/lag_selection.xlsx", ///
        firstrow(variables) ///
        replace


/*******************************************************************************
    FORECAST PREPARATION
*******************************************************************************/

    use "$panel", clear

    xtset prov_id ym

    *-----------------------------------------------------------------------
    * Last observed month
    *-----------------------------------------------------------------------

    quietly summarize ym if !missing(phk_flow)

    global LAST_YM = r(max)

    global FC_END = ym($FORECAST_YEAR,$FORECAST_MONTH)

    global FC_HORIZON = $FC_END-$LAST_YM

    display "Forecast horizon = " $FC_HORIZON " month(s)"

    *-----------------------------------------------------------------------
    * Extend panel
    *-----------------------------------------------------------------------

    tsappend, add($FC_HORIZON)

    replace year  = year(dofm(ym)) if missing(year)
    replace month = month(dofm(ym)) if missing(month)

    sort prov_id ym

    xtset prov_id ym

    *-----------------------------------------------------------------------
    * Carry forward explanatory variables
    *-----------------------------------------------------------------------

    foreach var of global STRUCTURE {

        by prov_id (ym): ///
            replace `var'=`var'[_n-1] if missing(`var')

    }

    foreach var of global TRIGGER {

        by prov_id (ym): ///
            replace `var'=`var'[_n-1] if missing(`var')

    }

    *-----------------------------------------------------------------------
    * Reconstruct lagged variables
    *-----------------------------------------------------------------------

    foreach L of global LAGS {

        foreach var of global TRIGGER {

            capture drop L`L'_`var'

            gen L`L'_`var' = L`L'.`var'

        }

    }


/*******************************************************************************
    FINAL MODEL
*******************************************************************************/

    local L = $BEST_LAG

    local trigger

    foreach v of global TRIGGER {

        local trigger `trigger' L`L'_`v'

    }

    poisson ///
        $OUTCOME ///
        $STRUCTURE ///
        `trigger' ///
        i.month ///
        i.prov_id ///
        if year <= $VALID_END, ///
        vce(cluster prov_id)

    estimates save ///
        "$model/final_poisson_model.ster", ///
        replace


/*******************************************************************************
    PROVINCIAL FORECAST
*******************************************************************************/

    capture drop phk_projection

    predict phk_projection, n

    replace phk_projection = . ///
        if ym <= $LAST_YM

    replace phk_projection = round(phk_projection)

    format phk_projection %12.0f

    save ///
        "$data/phk_projection_panel.dta", ///
        replace


    preserve

    keep if ym > $LAST_YM

    collapse ///
        (sum) phk_projection, ///
        by(prov_id year month ym)

    save ///
        "$data/phk_projection_province.dta", ///
        replace

    export excel ///
        using "$table/phk_projection_province.xlsx", ///
        firstrow(variables) ///
        replace

    restore

    *-----------------------------------------------------------------------
    * Top 10 provinces
    *-----------------------------------------------------------------------

    preserve

        keep if year == $FORECAST_YEAR

        collapse ///
            (sum) phk_projection, ///
            by(prov_id)

        gsort -phk_projection

        gen rank = _n

        keep if rank <= 10

        order ///
            rank ///
            prov_id ///
            phk_projection

        list, noobs sep(0)

        export excel ///
            using "$table/phk_projection_top10.xlsx", ///
            firstrow(variables) ///
            replace

    restore


/*******************************************************************************
    NATIONAL FORECAST
*******************************************************************************/

    preserve

    keep if ym > $LAST_YM

    collapse ///
        (sum) phk_projection, ///
        by(year month ym)

    save ///
        "$data/phk_projection_national.dta", ///
        replace

    export excel ///
        using "$table/phk_projection_national.xlsx", ///
        firstrow(variables) ///
        replace

    restore


/*******************************************************************************
    FORECAST GRAPHS
*******************************************************************************/

preserve

    collapse ///
        (sum) phk_flow phk_projection, ///
        by(ym)

    twoway ///
        (line phk_flow ym ///
            if ym <= $LAST_YM, ///
            lwidth(medthick)) ///
        (line phk_projection ym ///
            if ym > $LAST_YM, ///
            lpattern(dash) ///
            lwidth(medthick)), ///
        xtitle("") ///
        ytitle("Number of Layoffs") ///
        title("National Layoff Projection") ///
        legend(order(1 "Actual" 2 "Forecast"))

    graph export ///
        "$figure/phk_projection_national.png", ///
        replace

    restore
