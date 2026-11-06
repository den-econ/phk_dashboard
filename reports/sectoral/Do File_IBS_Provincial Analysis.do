* Do File Mapping Data IBS
* Provincial Analysis
* Raisa Idris

*=================================
* IBS 2022
*=================================

use "/Users/raisa/Documents/IBS_dta/si2022.dta", clear
renvars _all, lower

tempfile import energy labour

* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(dprovi)
gen import_share = rimvcu/rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list dprovi rimvcu rtlvcu import_share, sepby(dprovi)

save `import'

restore


* Energy Cost 

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu
collapse (sum) energy_cost rtlvcu, by(dprovi)
gen energy_share = energy_cost/rtlvcu

format energy_cost %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu energy_share, sepby(dprovi)

drop rtlvcu

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu
collapse (sum) labour_cost rtlvcu, by(dprovi)
gen labour_intensity = labour_cost/rtlvcu

format labour_cost %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu labour_intensity, sepby(dprovi)

drop rtlvcu

save `labour'

restore

* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi rimvcu rtlvcu import_share energy_cost energy_share labour_cost labour_intensity

export excel using "/Users/raisa/Documents/IBS_2022_sepby_dprovi.xlsx", ///
    firstrow(variables) replace
	
	
*=================================
* IBS 2015
*=================================

use "/Users/raisa/Documents/IBS_dta/si2015.dta", clear
renvars _all, lower

tempfile export import energy labour

* Export Share 

preserve

collapse (mean) prprex15, by(dprovi)
format prprex15 %9.2f
list dprovi prprex15

save `export'

restore


* Import Share

preserve

collapse (sum) rimvcu15 rtlvcu15, by(dprovi)
gen import_share = rimvcu15/rtlvcu15

format rimvcu15 rtlvcu15 %20.0fc
format import_share %9.4f

list dprovi rimvcu15 rtlvcu15 import_share, sepby(dprovi)

save `import'

restore


* Energy Cost 

preserve

gen energy_cost = efuvcu15 + eplvcu15 + enpvcu15
collapse (sum) energy_cost rtlvcu15, by(dprovi)
gen energy_share = energy_cost/rtlvcu15

format energy_cost %20.0fc
format rtlvcu15 %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu15 energy_share, sepby(dprovi)

drop rtlvcu15

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu15 + zndvcu15
collapse (sum) labour_cost rtlvcu15, by(dprovi)
gen labour_intensity = labour_cost/rtlvcu15

format labour_cost %20.0fc
format rtlvcu15 %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu15 labour_intensity, sepby(dprovi)

drop rtlvcu15

save `labour'

restore

* Merge All Results

use `export', clear

merge 1:1 dprovi using `import', nogen
merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi ///
      prprex15 ///
      rimvcu15 rtlvcu15 import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/IBS_2015_sepby_dprovi.xlsx", ///
    firstrow(variables) replace


*=================================
* IBS 2017
*=================================

use "/Users/raisa/Documents/IBS_dta/si2017.dta", clear
rename Year year_survey
renvars _all,lower

tempfile import energy labour

* Import Share

preserve

collapse (sum) rimvcu17 rtlvcu17, by(dprovi)
gen import_share = rimvcu17/rtlvcu17

format rimvcu17 rtlvcu17 %20.0fc
format import_share %9.4f

list dprovi rimvcu17 rtlvcu17 import_share, sepby(dprovi)

save `import'

restore

* Energy Cost

preserve

gen energy_cost = efuvcu17 + eplvcu17 + enpvcu17
collapse (sum) energy_cost rtlvcu17, by(dprovi)
gen energy_share = energy_cost/rtlvcu17

format energy_cost %20.0fc
format rtlvcu17 %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu17 energy_share, sepby(dprovi)

drop rtlvcu17

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu17 + zndvcu17
collapse (sum) labour_cost rtlvcu17, by(dprovi)
gen labour_intensity = labour_cost/rtlvcu17

format labour_cost %20.0fc
format rtlvcu17 %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu17 labour_intensity, sepby(dprovi)

drop rtlvcu17

save `labour'

restore

* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi ///
      rimvcu17 rtlvcu17 import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/IBS_2017_sepby_dprovi.xlsx", ///
    firstrow(variables) replace
	
	
*=================================
* IBS 2018
*=================================

use "/Users/raisa/Documents/IBS_dta/si2018.dta", clear
renvars _all, lower

tempfile import energy labour

* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(dprovi)

gen import_share = rimvcu/rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list dprovi rimvcu rtlvcu import_share, sepby(dprovi)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(dprovi)

gen energy_share = energy_cost/rtlvcu

format energy_cost %20.0fc
format rtlvcu %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu energy_share, sepby(dprovi)

drop rtlvcu

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(dprovi)

gen labour_intensity = labour_cost/rtlvcu

format labour_cost %20.0fc
format rtlvcu %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu labour_intensity, sepby(dprovi)

drop rtlvcu

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/IBS_2018_sepby_dprovi.xlsx", ///
    firstrow(variables) replace

*=================================
* IBS 2019
*=================================

use "/Users/raisa/Documents/IBS_dta/si2019.dta", clear
renvars _all, lower

tempfile import energy labour


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(dprovi)

gen import_share = rimvcu/rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list dprovi rimvcu rtlvcu import_share, sepby(dprovi)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(dprovi)

gen energy_share = energy_cost/rtlvcu

format energy_cost %20.0fc
format rtlvcu %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu energy_share, sepby(dprovi)

drop rtlvcu

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(dprovi)

gen labour_intensity = labour_cost/rtlvcu

format labour_cost %20.0fc
format rtlvcu %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu labour_intensity, sepby(dprovi)

drop rtlvcu

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/IBS_2019_sepby_dprovi.xlsx", ///
    firstrow(variables) replace
	
	
*=================================
* IBS 2020
*=================================

use "/Users/raisa/Documents/IBS_dta/si2020.dta", clear
renvars _all, lower

tempfile import energy labour


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(dprovi)

gen import_share = rimvcu/rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list dprovi rimvcu rtlvcu import_share, sepby(dprovi)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(dprovi)

gen energy_share = energy_cost/rtlvcu

format energy_cost %20.0fc
format rtlvcu %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu energy_share, sepby(dprovi)

drop rtlvcu

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(dprovi)

gen labour_intensity = labour_cost/rtlvcu

format labour_cost %20.0fc
format rtlvcu %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu labour_intensity, sepby(dprovi)

drop rtlvcu

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/IBS_2020_sepby_dprovi.xlsx", ///
    firstrow(variables) replace

	
*=================================
* IBS 2021
*=================================

use "/Users/raisa/Documents/IBS_dta/si2021.dta", clear
renvars _all, lower

tempfile import energy labour


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(dprovi)

gen import_share = rimvcu/rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list dprovi rimvcu rtlvcu import_share, sepby(dprovi)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(dprovi)

gen energy_share = energy_cost/rtlvcu

format energy_cost %20.0fc
format rtlvcu %20.0fc
format energy_share %9.4f

list dprovi energy_cost rtlvcu energy_share, sepby(dprovi)

drop rtlvcu

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(dprovi)

gen labour_intensity = labour_cost/rtlvcu

format labour_cost %20.0fc
format rtlvcu %20.0fc
format labour_intensity %9.4f

list dprovi labour_cost rtlvcu labour_intensity, sepby(dprovi)

drop rtlvcu

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/IBS_2021_sepby_dprovi.xlsx", ///
    firstrow(variables) replace
