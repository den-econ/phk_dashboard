* =============================================================================
* Project           : PHK Dashboard
* Description       : Develop Model to Project PHK  
* Stata version     : 16
* Date created      : 13 July 2026 by Bertha
* Last modified     : 13 July 2026 by Bertha
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
    VARIABLES
*******************************************************************************/

    * Outcome variable
    global  OUTCOME ///
            phk_flow

    * Annual structural variables
    global  STRUCTURE ///
            formal_lab_share ///
            manuf_emp_share ///
            agri_emp_share ///
            min_wage_yoy ///
            pdrb_yoy ///
            manuf_pdrb_share
            
            //agri_pdrb_share 
            

            

            //avg_wage_yoy ///
            
            


            


    * Monthly macroeconomic variables
    global  MACRO_GLOBAL ///
            log_price_brent
            //price_brent_yoy
            
             

    global  MACRO_NATIONAL ///
            bi_rate ///
            log_fx_idr_usd ///
            pmi_manuf ///
            ihpb_yoy 
            
            //ihpb_index 
            
            
            

            //fx_idr_usd_yoy ///

            // log_fx_idr_usd ///

    global  MACRO_PROVINCE ///
            cpi_yoy ///
            npl_yoy  ///
            log_export ///
            log_import 
            
            //export_yoy ///
            //import_yoy 

            //cpi_index ///

            
            //log_export ///
            //log_import 

            //export_ma3_yoy ///
            //import_ma3_yoy



    global  TRIGGER $MACRO_GLOBAL $MACRO_NATIONAL $MACRO_PROVINCE

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
