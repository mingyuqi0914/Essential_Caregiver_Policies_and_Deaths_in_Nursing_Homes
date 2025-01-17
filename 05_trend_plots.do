/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Figure 2
	- Appendix Figure 2
	- Appendix Figure 3
	- Appendix Figure 4

********************************************************************************************/

capture log close 
clear all
set more off
log using "/PATH/Trend_plots.log", replace 

*** Import the estimation sample 
use "/PATH/NH_COVID_FAC_2020_2021_E.dta", replace 

*** Create a numeric id variable for each state
egen provider_state_num = group(provider_state)

*** Create lagged weekly confirmed COVID-19 cases per 1,000 residents and cumulative COVID-19 cases per 1,000 residents
gen new_covid_case_per_1000_e = (residents_weekly_confirmed_covi / total_number_of_occupied_beds) * 1000
gen cum_covid_case_per_1000_e = (residents_total_confirmed_covid / cumulative_residents_served) * 1000

sort federal_provider_number week_number
by federal_provider_number: gen lag_1 = cum_covid_case_per_1000_e[_n-2]
by federal_provider_number: gen lag_2 = total_covid_death_per_1000_e[_n-2]
by federal_provider_number: gen lag_3 = total_non_covid_death_per_1000_e[_n-2]

*** Define covariates
global covarn bedcert overall_rating quality_rating staffing_rating adj_aide adj_lpn adj_rn adj_total i.shortage_of_nursing_staff i.shortage_of_clinical_staff i.shortage_of_aides i.ownership_short i.inhosp i.multifac_ltcf acu_index_ltcf pay_medicaid_ltcf pay_medicare_ltcf population_65_pct median_household_inc county_cases_new_1000 lag_1 lag_2 lag_3

*** Omit early treated (SD and MN) states and NE
keep if ecp_ever == 0 | !inlist(provider_state, "MI", "IN")

*** Log-transform the dependent variables
egen new_non_covid_death_per_1000_m = min(new_non_covid_death_per_1000_e) if new_non_covid_death_per_1000_e > 0
egen new_covid_death_per_1000_m = min(new_covid_death_per_1000_e) if new_covid_death_per_1000_e > 0
egen new_total_death_per_1000_m = min(new_total_death_per_1000_e) if new_total_death_per_1000_e > 0
egen new_covid_case_per_1000_m = min(new_covid_case_per_1000_e) if new_covid_case_per_1000_e > 0

gen new_non_covid_death_per_1000_n = new_non_covid_death_per_1000_e / new_non_covid_death_per_1000_m
gen new_covid_death_per_1000_n = new_covid_death_per_1000_e / new_covid_death_per_1000_m
gen new_total_death_per_1000_n = new_total_death_per_1000_e / new_total_death_per_1000_m
gen new_covid_case_per_1000_n = new_covid_case_per_1000_e / new_covid_case_per_1000_m

gen new_non_covid_death_per_1000_ln = ln(new_non_covid_death_per_1000_n)
gen new_covid_death_per_1000_ln = ln(new_covid_death_per_1000_n)
gen new_total_death_per_1000_ln = ln(new_total_death_per_1000_n)
gen new_covid_case_per_1000_ln = ln(new_covid_case_per_1000_n)

replace new_non_covid_death_per_1000_ln = 0 if new_non_covid_death_per_1000_ln == .
replace new_covid_death_per_1000_ln = 0 if new_covid_death_per_1000_ln == .
replace new_total_death_per_1000_ln = 0 if new_total_death_per_1000_ln == .
replace new_covid_case_per_1000_ln = 0 if new_covid_case_per_1000_ln == .

label drop wn
label define wn 1 "06/21/2020" 2 "07/05/2020" 3 "07/19/2020" 4 "08/02/2020" 5 "08/16/2020" 6 "08/30/2020" 7 "09/13/2020" ///
8 "09/27/2020" 9 "10/11/2020" 10 "10/25/2020" 11 "11/08/2020" 12 "11/22/2020" 13 "12/06/2020" 14 "12/20/2020" ///
15 "01/03/2021" 16 "01/17/2021" 17 "01/31/2021" 18 "02/14/2021" 19 "02/28/2021" 20 "03/14/2021" 21 "03/28/2021" 
label values week_number wn

*** Predict covariates adjusted outcomes 

* New non-Covid deaths
eststo: qui xtreg new_non_covid_death_per_1000_e i.week_number $covarn, i(federal_provider_number_num) fe cluster(provider_state_num)
predict new_non_death

* New Covid deaths 
eststo: qui xtreg new_covid_death_per_1000_e i.week_number $covarn, i(federal_provider_number_num) fe cluster(provider_state_num)
predict new_cov_death 

* New total deaths 
eststo: qui xtreg new_total_death_per_1000_e i.week_number $covarn, i(federal_provider_number_num) fe cluster(provider_state_num)
predict new_tot_death 


*** Predict covariates adjusted transformed outcomes 

* New non-Covid deaths
eststo: qui xtreg new_non_covid_death_per_1000_ln i.week_number $covarn, i(federal_provider_number_num) fe cluster(provider_state_num)
predict new_non_death_ln

* New Covid deaths 
eststo: qui xtreg new_covid_death_per_1000_ln i.week_number $covarn, i(federal_provider_number_num) fe cluster(provider_state_num)
predict new_cov_death_ln

* New total deaths 
eststo: qui xtreg new_total_death_per_1000_ln i.week_number $covarn, i(federal_provider_number_num) fe cluster(provider_state_num)
predict new_tot_death_ln 

*** Collapse data set to state-level for treated states and to a single observation for untreated states 

preserve 

collapse (mean) new_non_covid_death_per_1000_e (mean) new_covid_death_per_1000_e (mean) new_total_death_per_1000_e (mean) new_non_death (mean) new_cov_death (mean) new_tot_death (mean) new_non_covid_death_per_1000_ln (mean) new_covid_death_per_1000_ln (mean) new_total_death_per_1000_ln (mean) new_non_death_ln (mean) new_cov_death_ln (mean) new_tot_death_ln, by(ecp_ever week_number)
elabel variable (*) ("")
save "Outcomes_by_ECP_Ever_Log.dta", replace 

restore 

keep if ecp_ever == 1 
collapse (mean) new_non_covid_death_per_1000_e (mean) new_covid_death_per_1000_e (mean) new_total_death_per_1000_e (mean) new_non_death (mean) new_cov_death (mean) new_tot_death (mean) new_non_covid_death_per_1000_ln (mean) new_covid_death_per_1000_ln (mean) new_total_death_per_1000_ln (mean) new_non_death_ln (mean) new_cov_death_ln (mean) new_tot_death_ln, by(provider_state week_number)
elabel variable (*) ("")
append using "Outcomes_by_ECP_Ever_Log.dta"

set scheme white_ptol


/******************************
*** Figure 2
******************************/

* New non-COVID-19 death - ECP versus No ECP
tw (line new_non_covid_death_per_1000_e week_number if ecp_ever == 1,lwidth(medthick) lcolor(orange)) ///
(line new_non_covid_death_per_1000_e week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)8, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("", size(small))  /// 
legend(label(1 "With Essential Caregiver Policy") label(2 "Without Essential Caregiver Policy") cols(2) pos(6)) xline(1 3 4 6 8 9 14 15 18) ///
title("{bf:New Non-COVID-19 Deaths}", size(small) position(12) ring(7)) saving(new_non_covid, replace) 
graph export "New_Non_Covid_Death_ECP_vs_NoECP.png", replace 

* New COVID-19 death - ECP versus No ECP
tw (line new_covid_death_per_1000_e week_number if ecp_ever == 1,lwidth(medthick) lcolor(orange)) ///
(line new_covid_death_per_1000_e week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)8, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("", size(small))  /// 
legend(label(1 "With Essential Caregiver Policy") label(2 "Without Essential Caregiver Policy") cols(2) pos(6)) xline(1 3 4 6 8 9 14 15 18) ///
title("{bf:New COVID-19 Deaths}", size(small) position(12) ring(7)) saving(new_covid, replace)
graph export "New_Covid_Death_ECP_vs_NoECP.png", replace 

* New total death - ECP versus No ECP
tw (line new_total_death_per_1000_e week_number if ecp_ever == 1,lwidth(medthick) lcolor(orange)) ///
(line new_total_death_per_1000_e week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)13, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("", size(small))  /// 
legend(label(1 "With Essential Caregiver Policy") label(2 "Without Essential Caregiver Policy") cols(2) pos(6)) xline(1 3 4 6 8 9 14 15 18) ///
title("{bf:New Total Deaths}", size(small) position(12) ring(7)) saving(new_total_covid, replace) 
graph export "New_Total_Death_ECP_vs_NoECP.png", replace 

grc1leg2 new_non_covid.gph new_covid.gph new_total_covid.gph, col(2) row(2) imargin(0 0 0 0) legs(2.5) xsize(7) ysize(4.5)
graph export "Figure 2.png", replace 


/******************************
*** Appendix Figure 2
******************************/

* New non-COVID-19 death - SD
tw (line new_non_death week_number if provider_state == "SD",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(3) ///
title("South Dakota", size(med) position(12) ring(7)) saving(adj_new_non_covid_SD, replace)

* New non-COVID-19 death - MN
tw (line new_non_death week_number if provider_state == "MN",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(4) ///
title("Minnesota", size(med) position(12) ring(7)) saving(adj_new_non_covid_MN, replace)

* New non-COVID-19 death - WA
tw (line new_non_death week_number if provider_state == "WA",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(6) ///
title("Washington", size(med) position(12) ring(7)) saving(adj_new_non_covid_WA, replace)

* New non-COVID-19 death - NJ
tw (line new_non_death week_number if provider_state == "NJ",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(6) ///
title("New Jersey", size(med) position(12) ring(7)) saving(adj_new_non_covid_NJ, replace)

* New non-COVID-19 death - OK
tw (line new_non_death week_number if provider_state == "OK",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Oklahoma", size(med) position(12) ring(7)) saving(adj_new_non_covid_OK, replace)

* New non-COVID-19 death - FL
tw (line new_non_death week_number if provider_state == "FL",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Florida", size(med) position(12) ring(7)) saving(adj_new_non_covid_FL, replace)

* New non-COVID-19 death - DE
tw (line new_non_death week_number if provider_state == "DE",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Delaware", size(med) position(12) ring(7)) saving(adj_new_non_covid_DE, replace)

* New non-COVID-19 death - TX
tw (line new_non_death week_number if provider_state == "TX",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Texas", size(med) position(12) ring(7)) saving(adj_new_non_covid_TX, replace)

* New non-COVID-19 death - TN
tw (line new_non_death week_number if provider_state == "TN",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Tennessee", size(med) position(12) ring(7)) saving(adj_new_non_covid_TN, replace)

* New non-COVID-19 death - MO
tw (line new_non_death week_number if provider_state == "MO",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Missouri", size(med) position(12) ring(7)) saving(adj_new_non_covid_MO, replace)

* New non-COVID-19 death - AZ
tw (line new_non_death week_number if provider_state == "AZ",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Arizona", size(med) position(12) ring(7)) saving(adj_new_non_covid_AZ, replace) 

* New non-COVID-19 death - NE
tw (line new_non_death week_number if provider_state == "NE",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(14) ///
title("Nebraska", size(med) position(12) ring(7)) saving(adj_new_non_covid_NE, replace) 

* New non-COVID-19 death - IL
tw (line new_non_death week_number if provider_state == "IL",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(14) ///
title("Illinois", size(med) position(12) ring(7)) saving(adj_new_non_covid_IL, replace) 

* New non-COVID-19 death - RI
tw (line new_non_death week_number if provider_state == "RI",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(15) ///
title("Rhode Island", size(med) position(12) ring(7)) saving(adj_new_non_covid_RI, replace) 

* New non-COVID-19 death - OR
tw (line new_non_death week_number if provider_state == "OR",lwidth(medthick) lcolor(orange)) ///
(line new_non_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(18) ///
title("Oregon", size(med) position(12) ring(7)) saving(adj_new_non_covid_OR, replace) 

* Combine all graphs together
grc1leg2 adj_new_non_covid_SD.gph adj_new_non_covid_MN.gph adj_new_non_covid_WA.gph adj_new_non_covid_NJ.gph ///
         adj_new_non_covid_OK.gph adj_new_non_covid_FL.gph adj_new_non_covid_DE.gph adj_new_non_covid_TX.gph ///
		 adj_new_non_covid_TN.gph adj_new_non_covid_MO.gph adj_new_non_covid_AZ.gph adj_new_non_covid_NE.gph ///
		 adj_new_non_covid_IL.gph adj_new_non_covid_RI.gph adj_new_non_covid_OR.gph, ///
		 col(5) imargin(0 0 0 0) title("{bf:Adjusted Trends in New Non-COVID-19 Deaths by State}", size(vsmall) ///
		 box bexpand margin(1 1 1 1) ) legs(2.3) xsize(12) ysize(6) 
graph export "Appendix Figure 2.png", replace


/******************************
*** Appendix Figure 3
******************************/

* New COVID-19 death - SD
tw (line new_cov_death week_number if provider_state == "SD",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(3) ///
title("South Dakota", size(med) position(12) ring(7)) saving(new_covid_SD, replace)  

* New COVID-19 death - MN
tw (line new_cov_death week_number if provider_state == "MN",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(4) ///
title("Minnesota", size(med) position(12) ring(7)) saving(new_covid_MN, replace)

* New COVID-19 death - WA
tw (line new_cov_death week_number if provider_state == "WA",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(6) ///
title("Washington", size(med) position(12) ring(7)) saving(new_covid_WA, replace)

* New COVID-19 death - NJ
tw (line new_cov_death week_number if provider_state == "NJ",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(6) ///
title("New Jersey", size(med) position(12) ring(7)) saving(new_covid_NJ, replace)

* New COVID-19 death - OK
tw (line new_cov_death week_number if provider_state == "OK",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Oklahoma", size(med) position(12) ring(7)) saving(new_covid_OK, replace)

* New COVID-19 death - FL
tw (line new_cov_death week_number if provider_state == "FL",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Florida", size(med) position(12) ring(7)) saving(new_covid_FL, replace)

* New COVID-19 death - DE
tw (line new_cov_death week_number if provider_state == "DE",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Delaware", size(med) position(12) ring(7)) saving(new_covid_DE, replace) 

* New COVID-19 death - TX
tw (line new_cov_death week_number if provider_state == "TX",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Texas", size(med) position(12) ring(7)) saving(new_covid_TX, replace)

* New COVID-19 death - TN
tw (line new_cov_death week_number if provider_state == "TN",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Tennessee", size(med) position(12) ring(7)) saving(new_covid_TN, replace)

* New COVID-19 death - MO
tw (line new_cov_death week_number if provider_state == "MO",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Missouri", size(med) position(12) ring(7)) saving(new_covid_MO, replace)

* New COVID-19 death - AZ
tw (line new_cov_death week_number if provider_state == "AZ",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Arizona", size(med) position(12) ring(7)) saving(new_covid_AZ, replace) 

* New COVID-19 death - NE
tw (line new_cov_death week_number if provider_state == "NE",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(14) ///
title("Nebraska", size(med) position(12) ring(7)) saving(new_covid_NE, replace) 

* New COVID-19 death - IL
tw (line new_cov_death week_number if provider_state == "IL",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(14) ///
title("Illinois", size(med) position(12) ring(7)) saving(new_covid_IL, replace)

* New COVID-19 death - RI
tw (line new_cov_death week_number if provider_state == "RI",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(15) ///
title("Rhode Island", size(med) position(12) ring(7)) saving(new_covid_RI, replace) 

* New COVID-19 death - OR
tw (line new_cov_death week_number if provider_state == "OR",lwidth(medthick) lcolor(orange)) ///
(line new_cov_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(1)10, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(18) ///
title("Oregon", size(med) position(12) ring(7)) saving(new_covid_OR, replace) 

* Combine all graphs together
grc1leg2 new_covid_SD.gph new_covid_MN.gph new_covid_WA.gph new_covid_NJ.gph new_covid_OK.gph ///
         new_covid_FL.gph new_covid_DE.gph new_covid_TX.gph new_covid_TN.gph new_covid_MO.gph ///
         new_covid_AZ.gph new_covid_NE.gph new_covid_IL.gph new_covid_RI.gph new_covid_OR.gph, ///
		 col(5) imargin(0 0 0 0) title("{bf:Adjusted Trends in New COVID-19 Deaths by State}", ///
		 size(vsmall) box bexpand margin(1 1 1 1) ) legs(2.3) xsize(12) ysize(6) 
graph export "Appendix Figure 3.png", replace


/******************************
*** Appendix Figure 4
******************************/

* New Total death - SD
tw (line new_tot_death week_number if provider_state == "SD",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(3) ///
title("South Dakota", size(med) position(12) ring(7)) saving(new_tot_SD, replace)  

* New Total death - MN
tw (line new_tot_death week_number if provider_state == "MN",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(4) ///
title("Minnesota", size(med) position(12) ring(7)) saving(new_tot_MN, replace)

* New Total death - WA
tw (line new_tot_death week_number if provider_state == "WA",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(6) ///
title("Washington", size(med) position(12) ring(7)) saving(new_tot_WA, replace)

* New Total death - NJ
tw (line new_tot_death week_number if provider_state == "NJ",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(6) ///
title("New Jersey", size(med) position(12) ring(7)) saving(new_tot_NJ, replace)

* New Total death - OK
tw (line new_tot_death week_number if provider_state == "OK",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Oklahoma", size(med) position(12) ring(7)) saving(new_tot_OK, replace)

* New Total death - FL
tw (line new_tot_death week_number if provider_state == "FL",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Florida", size(med) position(12) ring(7)) saving(new_tot_FL, replace)

* New Total death - DE
tw (line new_tot_death week_number if provider_state == "DE",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(8) ///
title("Delaware", size(med) position(12) ring(7)) saving(new_tot_DE, replace) 

* New Total death - TX
tw (line new_tot_death week_number if provider_state == "TX",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Texas", size(med) position(12) ring(7)) saving(new_tot_TX, replace)

* New Total death - TN
tw (line new_tot_death week_number if provider_state == "TN",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Tennessee", size(med) position(12) ring(7)) saving(new_tot_TN, replace)

* New Total death - MO
tw (line new_tot_death week_number if provider_state == "MO",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Missouri", size(med) position(12) ring(7)) saving(new_tot_MO, replace)

* New Total death - AZ
tw (line new_tot_death week_number if provider_state == "AZ",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(9) ///
title("Arizona", size(med) position(12) ring(7)) saving(new_tot_AZ, replace) 

* New Total death - NE
tw (line new_tot_death week_number if provider_state == "NE",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(14) ///
title("Nebraska", size(med) position(12) ring(7)) saving(new_tot_NE, replace) 

* New Total death - IL
tw (line new_tot_death week_number if provider_state == "IL",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(14) ///
title("Illinois", size(med) position(12) ring(7)) saving(new_tot_IL, replace)

* New Total death - RI
tw (line new_tot_death week_number if provider_state == "RI",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(15) ///
title("Rhode Island", size(med) position(12) ring(7)) saving(new_tot_RI, replace) 

* New Total death - OR
tw (line new_tot_death week_number if provider_state == "OR",lwidth(medthick) lcolor(orange)) ///
(line new_tot_death week_number if ecp_ever == 0,lwidth(medthick) lcolor(ebblue) lp(dash)), ///
ylabel(0(2)20, gmin angle(horizontal)) ytitle("Number of Deaths per 1,000 Residents", size(vsmall)) ///
xlabel(1(1)21, val labs(vsmall) angle(45)) xtitle("") /// 
legend(label(1 "With Essential Caregiver Program") label(2 "Without Essential Caregiver Program") cols(2) pos(6)) xline(18) ///
title("Oregon", size(med) position(12) ring(7)) saving(new_tot_OR, replace) 

* Combine all graphs together
grc1leg2 new_tot_SD.gph new_tot_MN.gph new_tot_WA.gph new_tot_NJ.gph new_tot_OK.gph ///
         new_tot_FL.gph new_tot_DE.gph new_tot_TX.gph new_tot_TN.gph new_tot_MO.gph ///
         new_tot_AZ.gph new_tot_NE.gph new_tot_IL.gph new_tot_RI.gph new_tot_OR.gph, ///
		 col(5) imargin(0 0 0 0) title("{bf:Adjusted Trends in New Total Deaths by State}", ///
		 size(vsmall) box bexpand margin(1 1 1 1) ) legs(2.3) xsize(12) ysize(6) 
graph export "Appendix Figure 4.png", replace


capture log close 
