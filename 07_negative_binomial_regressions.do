/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Appendix Figure 1
	- Appendix Table 12

********************************************************************************************/

capture log close 
clear all
set more off
log using "Nrgative_Binomial_Model.log", replace 

*** Import the estimation sample 
use "/PATH/NH_COVID_FAC_2020_2021_E.dta", replace 

*** Create lagged weekly confirmed COVID-19 cases per 1,000 residents and cumulative COVID-19 cases per 1,000 residents
gen new_covid_case_per_1000_e = (residents_weekly_confirmed_covi / total_number_of_occupied_beds) * 1000
gen cum_covid_case_per_1000_e = (residents_total_confirmed_covid / cumulative_residents_served) * 1000

sort federal_provider_number week_number
by federal_provider_number: gen cum_covid_case_per_1000_e_lag = cum_covid_case_per_1000_e[_n-2]
by federal_provider_number: gen cum_covid_death_per_1000_e_lag = total_covid_death_per_1000_e[_n-2]
by federal_provider_number: gen cum_non_covid_death_per_1000_e_l = total_non_covid_death_per_1000_e[_n-2]

*** Create a numeric id variable for each state
egen provider_state_num = group(provider_state)

*** Define covariates
global covarn bedcert overall_rating quality_rating staffing_rating adj_aide adj_lpn adj_rn adj_total i.shortage_of_nursing_staff i.shortage_of_clinical_staff i.shortage_of_aides i.ownership_short i.inhosp i.multifac_ltcf acu_index_ltcf pay_medicaid_ltcf pay_medicare_ltcf population_65_pct median_household_inc county_cases_new_1000 cum_covid_case_per_1000_e_lag cum_non_covid_death_per_1000_e_l cum_covid_death_per_1000_e_lag


/******************************
*** Appendix Figure 1
******************************/

preserve 

keep if cum_covid_case_per_1000_e_lag != .

hist new_non_covid_death_per_1000_e, percent color(orange) xtitle("") title("New Non-COVID-19 Deaths per 1,000 Residents", size(small)) saving("hist_new_non_covid.gph", replace)

hist new_covid_death_per_1000_e, percent color(orange) xtitle("") title("New COVID-19 Deaths per 1,000 Residents", size(small)) saving("hist_new_covid.gph", replace)

hist new_total_death_per_1000_e, percent color(orange) xtitle("") title("New Total Deaths per 1,000 Residents", size(small)) saving("hist_new_total.gph", replace)

graph combine hist_new_non_covid.gph hist_new_covid.gph hist_new_total.gph, col(2) row(2) xsize(4.5) ysize(4)
graph export "Histogram.png", replace 

restore


/******************************
*** Appendix Table 12
******************************/

*** Set panel variable and time variable
xtset federal_provider_number_num week_number

*** Generate exposure time
gen evar = 1

sort federal_provider_number week_number
by federal_provider_number: gen evar_cum = _n 
tab evar_cum

*** Negative binomial regressions 

* New non-Covid death 
xtnbreg new_non_covid_death_per_1000_e i.ecp_dich i.week_number $covarn,fe exposure(evar) nolog irr  
margins, dydx(ecp_dich)

* New Covid death 
xtnbreg new_covid_death_per_1000_e i.ecp_dich i.week_number $covarn,fe exposure(evar) nolog irr 
margins, dydx(ecp_dich)

* New total death 
xtnbreg new_total_death_per_1000_e i.ecp_dich i.week_number $covarn,fe exposure(evar) nolog irr 
margins, dydx(ecp_dich)


*** Repeat the above regression without always treated and early treated (SD and MN) states and NE
keep if ecp_ever == 0 | !inlist(provider_state, "MI", "IN", "SD", "MN", "NE")

*** Negative binomial regressions 

* New non-Covid death 
xtnbreg new_non_covid_death_per_1000_e i.ecp_dich i.week_number $covarn,fe exposure(evar) nolog irr 
margins, dydx(ecp_dich)

* New Covid death 
xtnbreg new_covid_death_per_1000_e i.ecp_dich i.week_number $covarn,fe exposure(evar) nolog irr 
margins, dydx(ecp_dich)

* New total death 
xtnbreg new_total_death_per_1000_e i.ecp_dich i.week_number $covarn,fe exposure(evar) nolog irr 
margins, dydx(ecp_dich)

capture log close 

