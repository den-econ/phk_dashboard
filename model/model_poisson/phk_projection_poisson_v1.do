* ==============================================================================
* Project			: PHK Dashboard
* Description		: Develop Model to Project PHK  
* Stata version		: 16
* Date created		: 13 July 2026 by Bertha
* Last modified		: 13 July 2026 by Bertha
* ==============================================================================

	clear 	all
	set more off
	capture: log close
	set 	scheme 	plotplain 


/********************************************************************
	0. SETUP
********************************************************************/
	
	* Install packages if needed
	cap which ppmlhdfe
	if _rc ssc install ppmlhdfe, replace

	cap which reghdfe
	if _rc ssc install reghdfe, replace

	cap which ftools
	if _rc ssc install ftools, replace

	cap which estout
	if _rc ssc install estout, replace

	cap which winsor2
	if _rc ssc install winsor2, replace

	* User directories
	if "`c(username)'" == "berth" { 																
        gl  root  	"C:\Users\berth\GitHub\phk_dashboard" 
        gl 	data    "$root/data"
        gl  model  	"$root/model/model_poisson"
        gl  output  "$model/output"
        cap mkdir 	"$output"
    } 

    * Log 
    log		using 	"$model/phk_projection_poisson.log", replace


/********************************************************************
	1. MODEL METADATA
********************************************************************/
	
	* Define lags 
	global 	LAGS 1 3 6

	* Dependent variable	
	global 	OUTCOME 		phk_flow
	
	* Control variables 
	
		// Economic Structure
		global 	STRUCTURE ///
		    	macro_pdrb_manuf_share_pct_y ///
		   		lab_formal_share_pct_y ///
		    	lab_contract_share_pct_y ///
		    	macro_pdrb_per_wkr_growth_pct_y ///
		    	wage_ump_growth_pct_y

		// Macro Trigger
		global 	MACRO_GLOBAL ///
				price_brent_usd_bbl_nat 

		global 	MACRO_NATIONAL ///
				macro_bi_rate_pct_nat ///
				macro_fx_idr_usd_nat ///
			    macro_pmi_manuf_nat ///
			    price_ihpb_nat 

		global 	MACRO_PROVINCE ///
			    price_cpi_index ///
			    fin_npl_idr_billion ///
			    trade_export_value ///
		    	trade_import_value 

	global 	TRIGGER $MACRO_GLOBAL $MACRO_NATIONAL $MACRO_PROVINCE


/********************************************************************
	2. CREATE PANEL DATA
********************************************************************/
	
	* Import data
	import 	delimited "$data/clean/phk_master.csv", clear
	save   	"$model/phk_master.dta", replace

	* Generate province id
	rename province_code prov_id

	capture label drop prov_lbl
	levelsof prov_id, local(provs)

	foreach p of local provs {
	    quietly levelsof province_name_std if prov_id==`p', local(name) clean
	    label define prov_lbl `p' "`name'", add
	}

	label values prov_id prov_lbl

	keeporder prov_id year month date phk_stock phk_flow ///
		 	$STRUCTURE $TRIGGER

	* Set up panel data 
	sort  	prov_id year month
	gen 	ym = ym(year, month)
	format 	ym %tm

	xtset 	prov_id ym

	* Define sample 
	gen 	byte train = inrange(year,2023,2024)
	gen 	byte valid = year==2025

	* Construct lag for 1, 3, and 6 months 
	foreach L of global LAGS {
	    foreach v of global TRIGGER {
	        capture drop L`L'_`v'
	        gen L`L'_`v' = L`L'.`v'
	    }
	}

	* Summarize
	misstable summarize phk_flow $STRUCTURE $TRIGGER
	summ 	phk_flow

	foreach v of global STRUCTURE {
	    	capture noisily xtsum `v'
	}

	foreach v of global TRIGGER {
	    	capture noisily xtsum `v'
	}

	* Truncate PHK flow if data is negative 
	tab 	prov_id phk_flow if phk_flow < 0

	replace phk_flow = 0 if phk_flow < 0
	capture noisily xtsum phk_flow

	save   	"$output/phk_panel_data.dta", replace

	
/********************************************************************************
	3. MODEL COMPARISON
********************************************************************************/

	tempname results

	postfile `results' lag rmse mae using ///
	    	"$output/lag_selection.dta", replace

	foreach L of global LAGS {

	    display "==================================================================="
	    display "Estimating Lag `L'"
	    display "==================================================================="

	    local 	trigger

	    foreach v of global TRIGGER {
	        local trigger `trigger' L`L'_`v'
	    }

	    // Poisson regression
	    poisson  $OUTCOME $STRUCTURE `trigger' i.month i.prov_id if train == 1, ///
	        	vce(cluster prov_id)

	    // Estimate prediction 
	    est 	save 	model_lag`L', replace
	    est 	clear

	    est 	use 	model_lag`L'
	    cap 	drop 	phk_hat

	    predict phk_hat
	    //predict xb, xb
	    //gen 	phk_hat = exp(xb)

	    capture drop err sqerr abserr 

	    gen 	err 	= phk_flow-phk_hat if valid == 1
	    gen 	sqerr 	= err^2 if valid == 1
	    gen 	abserr 	= abs(err) if valid == 1

	    qui 	summarize sqerr if valid == 1
	    scalar 	RMSE 	= sqrt(r(mean))

	    quietly summarize abserr if valid == 1
	    scalar 	MAE 	= r(mean)

	    post 	`results'  (`L') (RMSE) (MAE)

	    // Save results
	    preserve

	    keep if valid == 1

	    keep 	prov_id year month phk_flow phk_hat 
	    
	    save 	"$output/projection_L`L'.dta", replace
	    export 	excel using "$output/projection_L`L'.dta", firstrow(variables) replace

	    restore
	}


	postclose `results'


/********************************************************************************
	6. SELECT BEST MODEL
********************************************************************************/

	use 	"$output/lag_selection.dta", clear

	sort 	rmse
	list

	local 	BEST = lag[1]
	display "Best Lag = `BEST'"


/********************************************************************************
	7. FINAL MODEL
********************************************************************************/

	use    	"$output/phk_panel_data.dta", clear

	keep  	if year>=2023

	local 	trigger
	foreach v of global TRIGGER {
	    local trigger `trigger' L`BEST'_`v'
	}

	poisson  $OUTCOME $STRUCTURE `trigger' i.month i.prov_id, ///
	        	vce(cluster prov_id)

	est 	save "$output/phk_model_final.ster", replace


/********************************************************************************
	8. PROVINCIAL PROJECTION
********************************************************************************/
	
	* PHK projection by province
	capture drop phk_projection
	predict phk_projection

	replace phk_projection = round(phk_projection)
	format 	phk_projection %12.0f

	* Annual total actual PHK
	bysort 	year prov_id: egen phk_flow_y = total(phk_flow)

	* Annual total projected PHK
	bysort 	year prov_id: egen phk_projection_y = total(phk_projection)

	keep 	prov_id year month phk_flow phk_projection phk_flow_y phk_projection_y
	save 	"$output/province_projection.dta", replace

	preserve
	collapse (first) phk_flow_y phk_projection_y, by(year prov_id)
	save 	"$output/province_projection_annual.dta", replace
	restore


/********************************************************************************
 	9. NATIONAL PROJECTION
********************************************************************************/
	
	* PHK projection at national level
	collapse (sum) phk_flow phk_projection, by(year month)
	
	* Annual total actual PHK
	bysort year: egen phk_flow_y = total(phk_flow)

	* Annual total projected PHK
	bysort year: egen phk_projection_y = total(phk_projection)

	keep 	year month phk_flow phk_projection phk_flow_y phk_projection_y
	save 	"$output/national_projection.dta", replace



/********************************************************************************
 	10. ANALYSIS
********************************************************************************/
