* Do File Mapping Data IBS
* Sectoral Analysis
* Raisa Idris

*=================================
* IBS 2022
*=================================

use "/Users/raisa/Documents/IBS_dta/si2022.dta", clear
renvars _all,lower

tempfile import energy labour

* BY KBLI *

tab disic2
tab disic2 if ekspor !=.

* Import Share

preserve
collapse (sum) rimvcu rtlvcu, by(disic2)
gen import_share = rimvcu/rtlvcu

format rimvcu %20.0fc
format rtlvcu %20.0fc

list disic2 rimvcu rtlvcu import_share, sepby(disic2)

save `import'

restore


* Energy Cost (Checker)

gen fuel_check = ///
epevcu + esovcu + esdvcu + edivcu + ///
eclvcu + eckvcu + ecbvcu + engvcu + ///
efovcu + elpvcu + ecavcu + encvcu + eluvcu

summ fuel_check efuvcu

gen diff = fuel_check - efuvcu
summ diff

* Energy Cost 

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu
collapse (sum) energy_cost rtlvcu, by(disic2)
gen energy_share = energy_cost / rtlvcu

format energy_cost rtlvcu %18.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu energy_share, sepby (disic2)

drop rtlvcu

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu
collapse (sum) labour_cost rtlvcu, by(disic2)
gen labour_intensity = labour_cost / rtlvcu

format labour_cost rtlvcu %18.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu labour_intensity, sepby(disic2)

drop rtlvcu

save `labour'

restore

* Merge All Results

use `import', clear

merge 1:1 dprovi using `energy', nogen
merge 1:1 dprovi using `labour', nogen

order dprovi rimvcu rtlvcu import_share energy_cost energy_share labour_cost labour_intensity

export excel using "/Users/raisa/Documents/IBS_2022_sepby_disic2.xlsx", ///
    firstrow(variables) replace


*=================================
* IBS 2015
*=================================

use "/Users/raisa/Documents/IBS_dta/si2015.dta", clear
renvars _all, lower

tempfile export import energy labour

* BY KBLI *

tostring disic515, replace

gen disic2 = substr(disic515,1,2)
destring disic2, replace

tempfile export import energy labour

* Export Share 

preserve

collapse (mean) prprex15, by(disic2)
format prprex15 %9.2f
list disic2 prprex15

save `export'

restore


* Import Share

preserve

collapse (sum) rimvcu15 rtlvcu15, by(disic2)
gen import_share = rimvcu15 / rtlvcu15

format rimvcu15 rtlvcu15 %20.0fc
format import_share %9.4f

list disic2 rimvcu15 rtlvcu15 import_share, sepby(disic2)

save `import'

restore


* Energy Cost 

preserve

gen energy_cost = efuvcu15 + eplvcu15 + enpvcu15
collapse (sum) energy_cost rtlvcu15, by(disic2)
gen energy_share = energy_cost / rtlvcu15

format energy_cost %18.0fc
format rtlvcu15 %18.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu15 energy_share, sepby(disic2)

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu15 + zndvcu15
collapse (sum) labour_cost rtlvcu15, by(disic2)
gen labour_intensity = labour_cost / rtlvcu15

format labour_cost %18.0fc
format rtlvcu15 %18.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu15 labour_intensity, sepby(disic2)

save `labour'

restore


* Merge All Results

use `export', clear

merge 1:1 disic2 using `import', nogen
merge 1:1 disic2 using `energy', nogen
merge 1:1 disic2 using `labour', nogen

order disic2 ///
      prprex15 ///
      rimvcu15 iinput15 import_share ///
      energy_cost rtlvcu15 energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/KBLI_Shares_2015.xlsx", ///
    firstrow(variables) replace

*=================================
* IBS 2017
*=================================

use "/Users/raisa/Downloads/si2017.dta"
rename Year year_survey
renvars _all,lower

tempfile import energy labour

* BY KBLI

tostring disic517, replace

gen disic2 = substr(disic517, 1, 2)
destring disic2, replace

tempfile import energy labour

* Import Share

preserve

collapse (sum) rimvcu17 rtlvcu17, by(disic2)
gen import_share = rimvcu17 / rtlvcu17

format rimvcu17 rtlvcu17 %20.0fc
format import_share %9.4f

list disic2 rimvcu17 rtlvcu17 import_share, sepby(disic2)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu17 + eplvcu17 + enpvcu17
collapse (sum) energy_cost rtlvcu17, by(disic2)
gen energy_share = energy_cost / rtlvcu17

format energy_cost rtlvcu17 %20.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu17 energy_share, sepby(disic2)

save `energy'

restore


* Labour Cost

preserve

gen labour_cost = zpdvcu17 + zndvcu17
collapse (sum) labour_cost rtlvcu17, by(disic2)
gen labour_intensity = labour_cost / rtlvcu17

format labour_cost rtlvcu17 %20.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu17 labour_intensity, sepby(disic2)
save `labour'
restore

* Merge All Results

use `import', clear

merge 1:1 disic2 using `energy', nogen
merge 1:1 disic2 using `labour', nogen

order disic2 ///
      rimvcu17 rtlvcu17 import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/KBLI_Shares_2017.xlsx", ///
    firstrow(variables) replace
	
	
*=================================
* IBS 2018
*=================================

use "/Users/raisa/Downloads/si2018.dta", clear
renvars _all, lower

tempfile import energy labour

* BY KBLI

tostring disic5, replace

gen disic2 = substr(disic5, 1, 2)
destring disic2, replace


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(disic2)

gen import_share = rimvcu / rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list disic2 rimvcu rtlvcu import_share, sepby(disic2)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(disic2)

gen energy_share = energy_cost / rtlvcu

format energy_cost rtlvcu %20.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu energy_share, sepby(disic2)

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(disic2)

gen labour_intensity = labour_cost / rtlvcu

format labour_cost rtlvcu %20.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu labour_intensity, sepby(disic2)

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 disic2 using `energy', nogen
merge 1:1 disic2 using `labour', nogen

order disic2 ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/KBLI_Shares_2018.xlsx", ///
    firstrow(variables) replace


*=================================
* IBS 2019
*=================================

use "/Users/raisa/Downloads/si2019.dta", clear
renvars _all, lower

* BY KBLI

tostring disic5, replace

gen disic2 = substr(disic5, 1, 2)
destring disic2, replace

tempfile import energy labour


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(disic2)

gen import_share = rimvcu / rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list disic2 rimvcu rtlvcu import_share, sepby(disic2)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(disic2)

gen energy_share = energy_cost / rtlvcu

format energy_cost rtlvcu %20.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu energy_share, sepby(disic2)

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(disic2)

gen labour_intensity = labour_cost / rtlvcu

format labour_cost rtlvcu %20.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu labour_intensity, sepby(disic2)

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 disic2 using `energy', nogen
merge 1:1 disic2 using `labour', nogen

order disic2 ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/KBLI_Shares_2019.xlsx", ///
    firstrow(variables) replace
	
*=================================
* IBS 2020
*=================================

use "/Users/raisa/Downloads/si2020.dta", clear
renvars _all, lower

* BY KBLI

tostring disic5, replace

gen disic2 = substr(disic5, 1, 2)
destring disic2, replace

tempfile import energy labour


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(disic2)

gen import_share = rimvcu / rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list disic2 rimvcu rtlvcu import_share, sepby(disic2)

save `import'

restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(disic2)

gen energy_share = energy_cost / rtlvcu

format energy_cost rtlvcu %20.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu energy_share, sepby(disic2)

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(disic2)

gen labour_intensity = labour_cost / rtlvcu

format labour_cost rtlvcu %20.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu labour_intensity, sepby(disic2)

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 disic2 using `energy', nogen
merge 1:1 disic2 using `labour', nogen

order disic2 ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/KBLI_Shares_2020.xlsx", ///
    firstrow(variables) replace
	

*=================================
* IBS 2021
*=================================

use "/Users/raisa/Downloads/si2021.dta", clear
renvars _all, lower

* BY KBLI

tostring disic5, replace

gen disic2 = substr(disic5, 1, 2)
destring disic2, replace

tempfile import energy labour


* Import Share

preserve

collapse (sum) rimvcu rtlvcu, by(disic2)

gen import_share = rimvcu / rtlvcu

format rimvcu rtlvcu %20.0fc
format import_share %9.4f

list disic2 rimvcu rtlvcu import_share, sepby(disic2)
save `import'
restore


* Energy Cost

preserve

gen energy_cost = efuvcu + eplvcu + enpvcu

collapse (sum) energy_cost rtlvcu, by(disic2)

gen energy_share = energy_cost / rtlvcu

format energy_cost rtlvcu %20.0fc
format energy_share %9.4f

list disic2 energy_cost rtlvcu energy_share, sepby(disic2)

save `energy'

restore

* Labour Cost

preserve

gen labour_cost = zpdvcu + zndvcu

collapse (sum) labour_cost rtlvcu, by(disic2)

gen labour_intensity = labour_cost / rtlvcu

format labour_cost rtlvcu %20.0fc
format labour_intensity %9.4f

list disic2 labour_cost rtlvcu labour_intensity, sepby(disic2)

save `labour'

restore


* Merge All Results

use `import', clear

merge 1:1 disic2 using `energy', nogen
merge 1:1 disic2 using `labour', nogen

order disic2 ///
      rimvcu rtlvcu import_share ///
      energy_cost energy_share ///
      labour_cost labour_intensity

list

export excel using "/Users/raisa/Documents/KBLI_Shares_2021.xlsx", ///
    firstrow(variables) replace
