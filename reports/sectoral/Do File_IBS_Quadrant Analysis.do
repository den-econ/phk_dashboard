* Do File Mapping Kuadran IBS
* Raisa Idris

*=================================
* IBS 2015
*=================================

use "/Users/raisa/Documents/si2015.dta"
renvars _all,lower

*-----------------------------
* By KBLI
*-----------------------------

tostring disic515, replace

gen disic2 = substr(disic515,1,2)
destring disic2, replace

tempfile export import

* Export Share 

preserve

collapse (mean) prprex15, by(disic2)

save `export'

restore


* Import Share

preserve

collapse (sum) rimvcu15 rtlvcu15, by(disic2)

gen import_share = rimvcu15/rtlvcu15

save `import'

restore


* Merge KBLI results

use `export', clear

merge 1:1 disic2 using `import', nogen

format prprex15 %9.2f
format rimvcu15 rtlvcu15 %20.0fc
format import_share %9.4f

order disic2 prprex15 rimvcu15 rtlvcu15 import_share

export excel using "/Users/raisa/Documents/IBS_2015_By_Disic.xlsx", ///
    sheet("KBLI") firstrow(variables) replace
	


*-----------------------------
* By Province
*-----------------------------

use "/Users/raisa/Documents/si2015.dta"
renvars _all,lower

tempfile export import

* Export Share 

preserve

collapse (mean) prprex15, by(dprovi15)

save `export'

restore


* Import Share

preserve

collapse (sum) rimvcu15 rtlvcu15, by(dprovi15)

gen import_share = rimvcu15/rtlvcu15

save `import'

restore

* Merge Province results
use `export', clear

merge 1:1 dprovi15 using `import', nogen

format prprex15 %9.2f
format rimvcu15 rtlvcu15 %20.0fc
format import_share %9.4f

order dprovi15 prprex15 rimvcu15 rtlvcu15 import_share

export excel using "/Users/raisa/Documents/IBS_2015_By_Dprovi.xlsx", ///
    sheet("Province") firstrow(variables) sheetmodify
	
	
*=================================
* IBS 2022
*=================================

use "/Users/raisa/Documents/si2022_rev.dta"
renvars _all,lower

tempfile import export

*-----------------------------
* By KBLI
*-----------------------------

gen import_dummy = (impor==1)
gen export_dummy = (ekspor==1)

preserve

collapse (mean) import_dummy export_dummy, by(disic2)

replace import_dummy = import_dummy*100
replace export_dummy = export_dummy*100

export excel using "/Users/raisa/Documents/IBS_2022_Dummy.xlsx", ///
    sheet("KBLI") firstrow(variables) replace

restore


*-----------------------------
* By Province
*-----------------------------

use "/Users/raisa/Documents/si2022_rev.dta"
renvars _all,lower

tempfile import export

gen import_dummy = (impor==1)
gen export_dummy = (ekspor==1)

preserve

collapse (mean) import_dummy export_dummy, by(dprovi)

replace import_dummy = import_dummy*100
replace export_dummy = export_dummy*100

export excel using "/Users/raisa/Documents/IBS_2022_Dummy_Dprovi.xlsx", ///
    sheet("KBLI") firstrow(variables) replace

restore


clear

*=================================


gen import_dummy = (impor == 1)
gen export_dummy = (ekspor == 1)


* Import
preserve

collapse (mean) import_dummy, by(disic2)

replace import_dummy = import_dummy*100
save `import'

restore

* Export
preserve

collapse (mean) export_dummy, by(disic2)

replace export_dummy = export_dummy*100
save `export'

restore

* Merge
use `import', clear

merge 1:1 disic2 using `export', nogen

format import_dummy export_dummy %9.2f

order disic2 import_dummy export_dummy

export excel using "/Users/raisa/Documents/IBS_2022_Dummy_KBLI.xlsx", ///
    sheet("KBLI") firstrow(variables) replace


*-------------------------------------
* By Province
*-------------------------------------

use "/Users/raisa/Documents/si2022_rev.dta", clear
renvars _all, lower

gen import_dummy = (impor == 1)
gen export_dummy = (ekspor == 1)

* Import
preserve

collapse (mean) import_dummy, by(dprovi)

replace import_dummy = import_dummy*100
save `import'

restore

* Export
preserve

collapse (mean) export_dummy, by(dprovi)

replace export_dummy = export_dummy*100
save `export'

restore

* Merge
use `import', clear

merge 1:1 dprovi using `export', nogen

format import_dummy export_dummy %9.2f

order dprovi import_dummy export_dummy

export excel using "/Users/raisa/Documents/IBS_2022_Dummy_Dprovi.xlsx", ///
    sheet("Province") firstrow(variables) sheetmodify
