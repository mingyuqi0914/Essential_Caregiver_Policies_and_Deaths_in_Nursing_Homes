/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Figure 3

********************************************************************************************/

capture log close 
clear all
set more off
log using "/PATH/Bacondecomp.log", replace 

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

*** Create a balanced panel to conduct Bacon Decomposition
sort federal_provider_number week_number 
by federal_provider_number: egen week_number_count = count(week_number)
tab week_number_count

keep if week_number_count == 21 

xtset federal_provider_number_num week_number  

* Convert categorical variable to dummy variables 
gen ownership_short_1 = 1 if ownership_short == 1
replace ownership_short_1 = 0 if ownership_short_1 == .

gen ownership_short_2 = 1 if ownership_short == 2
replace ownership_short_2 = 0 if ownership_short_2 == .

gen ownership_short_3 = 1 if ownership_short == 3
replace ownership_short_3 = 0 if ownership_short_3 == .


/******************************
*** Figure 3
******************************/

*** Two-way fixed effects model (SNF FEs) and Bacon decomposition

set scheme white_tableau

drop if lag_1 == .

* New non-Covid death 
sum new_non_covid_death_per_1000_ln,d

qui xtreg new_non_covid_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)
estimates store new_non
esttab  new_non, keep(1.ecp_dich) se 

bacondecomp new_non_covid_death_per_1000_ln ecp_dich bedcert overall_rating quality_rating staffing_rating adj_aide adj_lpn adj_rn shortage_of_nursing_staff shortage_of_clinical_staff shortage_of_aides ownership_short_1 ownership_short_2 ownership_short_3 inhosp multifac_ltcf acu_index_ltcf pay_medicaid_ltcf pay_medicare_ltcf population_65_pct median_household_inc county_cases_new_1000 lag_1 lag_2 lag_3, ddetail robust gropt(note("{bf:New Non-COVID-19 Deaths}", size(small)) saving(bacon_new_non_covid_noalways.gph, replace)) msymbols(circle_hollow triangle square) mcolors(midblue orange midgreen) ddline(lcolor(maroon))
graph export "Bacondecomp_New_Non_Covid_Deaths_Biweekly_NoAlways.png", replace 

* New Covid death 
sum new_covid_death_per_1000_ln,d

qui xtreg new_covid_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)
estimates store new_cov 
esttab  new_cov, keep(1.ecp_dich) se 

bacondecomp new_covid_death_per_1000_ln ecp_dich bedcert overall_rating quality_rating staffing_rating adj_aide adj_lpn adj_rn shortage_of_nursing_staff shortage_of_clinical_staff shortage_of_aides ownership_short_1 ownership_short_2 ownership_short_3 inhosp multifac_ltcf acu_index_ltcf pay_medicaid_ltcf pay_medicare_ltcf population_65_pct median_household_inc county_cases_new_1000 lag_1 lag_2 lag_3, ddetail robust gropt(note("{bf:New COVID-19 Deaths}", size(small)) saving(bacon_new_covid_noalways.gph, replace)) msymbols(circle_hollow triangle square) mcolors(midblue orange midgreen) ddline(lcolor(maroon))
graph export "Bacondecomp_New_Covid_Deaths_Biweekly_NoAlways.png", replace 

* New Total death 
sum new_total_death_per_1000_ln,d

qui xtreg new_total_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)
estimates store new_tot 
esttab  new_tot, keep(1.ecp_dich) se 

bacondecomp new_total_death_per_1000_ln ecp_dich bedcert overall_rating quality_rating staffing_rating adj_aide adj_lpn adj_rn shortage_of_nursing_staff shortage_of_clinical_staff shortage_of_aides ownership_short_1 ownership_short_2 ownership_short_3 inhosp multifac_ltcf acu_index_ltcf pay_medicaid_ltcf pay_medicare_ltcf population_65_pct median_household_inc county_cases_new_1000 lag_1 lag_2 lag_3, ddetail robust gropt(note("{bf:New Total Deaths}", size(small)) saving(bacon_new_total_noalways.gph, replace)) msymbols(circle_hollow triangle square) mcolors(midblue orange midgreen) ddline(lcolor(maroon))
graph export "Bacondecomp_New_Total_Deaths_Biweekly_NoAlways.png", replace 

* Combine all graphs
grc1leg2 bacon_new_non_covid_noalways.gph bacon_new_covid_noalways.gph bacon_new_total_noalways.gph, col(2) row(2) imargin(1 1 1 1) lc(3) legs(1.75) xsize(8) ysize(6) iscale(0.58)
graph export "Bacondecomp_New_Combine_Biweekly_LogTrans_NoAlways.png", replace 


capture log close 
