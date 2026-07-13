* ==============================================================================
*
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
	1. LOAD DATA
********************************************************************/
	import 	delimited "$data/clean/phk_master.csv", clear
	save   	"$model/phk_master.dta", replace
	tempfile master
	save 	`master', replace

	import 	delimited "$data/clean/phk_variable_flags.csv", clear
	save   	"$model/phk_variable_flags.dta", replace
	tempfile flags
	save 	`flags', replace

	use 	`master', clear


/********************************************************************
	2. VARIABLE GROUPS
********************************************************************/
	
	* Economic Structure
	global 	STRUCTURE ///
		    macro_pdrb_manuf_share_pct_y ///
		    lab_formal_share_pct_y ///
		    lab_contract_share_pct_y ///
		    macro_pdrb_per_wkr_growth_pct_y ///
		    wage_ump_growth_pct_y

	* Macro Trigger
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


	keeporder province_name_std year quarter month date phk_stock phk_flow ///
			 $STRUCTURE $TRIGGER 


/********************************************************************
	3. PANEL PREPARATION
********************************************************************/
	
	* Keep based on availability of PHK data 
	keep 	if year>=2022

	* Set up panel data 
	***
	egen 	prov_id = group(province_name_std), label
	***
	gen 	ym = ym(year, month)
	format 	ym %tm

	xtset 	prov_id ym


/********************************************************************
	4. DATA QUALITY
********************************************************************/
	
	* Summarize
	misstable summarize phk_flow $STRUCTURE $TRIGGER

	summ phk_flow

	foreach v of global STRUCTURE {
	    capture noisily xtsum `v'
	}

	foreach v of global TRIGGER {
	    capture noisily xtsum `v'
	}

	* Truncate PHK flow if data is negative 
	tab 	province_name_std phk_flow if phk_flow < 0

	replace phk_flow = 0 if phk_flow < 0
	capture noisily xtsum phk_flow


/********************************************************************
	5. CONSTRUCT LAGS
********************************************************************/
	
	* Construct lag for 1, 3, and 6 months 

	foreach L in 1 3 6 {

	    foreach x of global TRIGGER {

	        capture confirm variable `x'
	        if !_rc {
	            gen L`L'_`x' = L`L'.`x'
	        }
	    }
	}
	

/********************************************************************
	6. TRAIN / TEST SPLIT
********************************************************************/
	
	* Keep the data starting the year in which PHK information is complete 
	drop if year < 2023
	replace phk_flow = 0 if month == 1 & phk_flow ==.

	* Identify train and test period 
	gen 	train = year<=2024
	gen 	test  = year==2025


/********************************************************************
7. LAG SELECTION
********************************************************************/
	
	tempname results
	postfile `results' str5 lag double rmse mae using ///
	"$output/lag_selection.dta", replace

	foreach lag in 1 3 6 {

	    ppmlhdfe ///
	        phk_flow ///
	        $STRUCTURE ///
	        L`lag'_price_brent_usd_bbl_nat ///
	        L`lag'_macro_bi_rate_pct_nat ///
	        L`lag'_macro_fx_idr_usd_nat ///
	        L`lag'_macro_pmi_manuf_nat ///
	        L`lag'_price_ihpb_nat ///
	        L`lag'_price_cpi_index  ///
	        L`lag'_fin_npl_idr_billion ///
	        L`lag'_trade_export_value  ///
	        L`lag'_trade_import_value ///
	        if train, ///
	        absorb(prov_id year) ///
	        cluster(prov_id)

	    predict phk_hat_`lag' if test, mu

	    gen err = phk_flow-phk_hat_`lag' if test
	    gen abs_err = abs(err)

	    quietly summarize abs_err if test
	    local mae = r(mean)

	    gen sq = err^2 if test
	    quietly summarize sq if test
	    local rmse = sqrt(r(mean))

	    post `results' ("L`lag'") (`rmse') (`mae')

	    drop err abs_err sq
	}

	postclose `results'




0
	

  	log  	close 



