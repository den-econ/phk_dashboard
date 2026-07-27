* =============================================================================
* Project           : PHK Dashboard
* Description       : Develop Model to Project PHK  
* Stata version     : 16
* Date created      : 13 July 2026 by Bertha
* Last modified     : 26 July 2026 by Bertha
* =============================================================================


*******************************************************************************
*******************************************************************************
//////////////////////////// CONFIGURATION ////////////////////////////////////
*******************************************************************************
*******************************************************************************

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
    global dofile   "$project/01_do"
    global data     "$project/02_data"
    global model    "$project/03_model"
    global table    "$project/04_table"
    global latex     "$project/05_latex"
    global figure   "$project/06_figure"

    * Master panel dataset
    global panel     "$data/phk_panel_data.dta"

    * Create output folders if they do not exist
    capture mkdir   "$dofile"
    capture mkdir   "$data"
    capture mkdir   "$model"
    capture mkdir   "$table"
    capture mkdir   "$latex"
    capture mkdir   "$figure"
    


/*******************************************************************************
    SETTINGS
*******************************************************************************/

    * Estimation period
    global EST_START        2023
    global EST_END          2025


/*******************************************************************************
    VARIABLES
*******************************************************************************/

    * Outcome variable
    global  OUTCOME ///
            phk_flow

    * Economic Structure (Province)
    global  ECON_STRUCTURE ///
            gov_pdrb_share ///
            export_pdrb_share ///
            import_pdrb_share ///
            manuf_pdrb_share ///
            agri_pdrb_share 

    * Labor Structure (Province)
    global  LABOR_STRUCTURE ///
            formal_lab_share ///
            manuf_emp_share ///
            full_time_share ///
            underemployment_share ///
            log_avg_wage       
   
    * Monthly macroeconomic variables
    global  MACRO_GLOBAL ///
            log_price_brent 
            
            //price_brent_yoy             

    global  MACRO_NATIONAL ///
            pmi_manuf ///
            bi_rate ///
            log_fx_idr_usd ///
            ihpb_index  ///
            log_car_sales 

            // fx_volatility ///
            // ihpb_yoy ///
            // car_sales_yoy

    global  MACRO_PROVINCE ///
            log_export 

            // export_yoy 
            // cpi_yoy ///            
            // npl_ratio ///
            // log_import

    
    global  STRUCTURE $ECON_STRUCTURE $LABOR_STRUCTURE 
    global  PRESSURE $MACRO_GLOBAL $MACRO_NATIONAL $MACRO_PROVINCE

    * Candidate lag specifications
    global  LAGS ///
            1 3 6 12


/*******************************************************************************
    PACKAGES
*******************************************************************************/

    foreach pkg in estout coefplot {

        capture which `pkg'

        if _rc {

            ssc install `pkg', replace

        }

    }
