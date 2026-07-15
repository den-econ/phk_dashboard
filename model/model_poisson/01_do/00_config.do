
/*******************************************************************************
00. CONFIGURATION
*******************************************************************************/

version     16
clear       all
macro drop _all
set more    off
set seed    123456


/*******************************************************************************
    DIRECTORIES
*******************************************************************************/

* Root directory
global root      "C:\Users\berth\GitHub\phk_dashboard" 

* Input & Output folders
global input     "$root/data/clean"
global project   "$root/model/model_poisson"

* Project subfolders
global dofile    "$project/01_do"
global data      "$project/02_data"
global table     "$project/04_table"
global model     "$project/03_model"
global figure    "$project/05_figure"

* Master panel dataset
global panel     "$data/phk_panel_data.dta"

* Create output folders if they do not exist
capture mkdir   "$dofile"
capture mkdir   "$data"
capture mkdir   "$table"
capture mkdir   "$figure"
capture mkdir   "$model"


/*******************************************************************************
    2. SETTINGS
*******************************************************************************/

* Training period
global TRAIN_START      2023
global TRAIN_END        2024

* Validation period
global VALID_START      2025
global VALID_END        2025

* Forecast horizon
global FORECAST_YEAR    2026
global FORECAST_MONTH   12


/*******************************************************************************
    3. VARIABLES
*******************************************************************************/

* Outcome variable
global  OUTCOME ///
        phk_flow

* Annual structural variables
global  STRUCTURE ///
        log_pdrb_y ///
        manuf_pdrb_share_y ///
        manuf_emp_share_y ///
        formal_lab_share_y ///
        log_wage_ump_y 

        //log_wage_avg_y 
        //agri_emp_share_y ///

    * Monthly macroeconomic variables
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

* Candidate lag specifications
global  LAGS ///
    1 3 6 12


/*******************************************************************************
    4. PACKAGES
*******************************************************************************/

foreach pkg in estout coefplot {

    capture which `pkg'

    if _rc {

        ssc install `pkg', replace

    }

}
