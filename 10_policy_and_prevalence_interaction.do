/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Appendix Table 10

********************************************************************************************/

capture log close 
clear all
set more off
log using "/PATH/ECP_and_Community_Prevalence_Interaction.log", replace 

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

preserve 

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

*** Summarize outcomes
sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

*** Summarize county COVID-19 prevalence 
sum county_cases_new_1000 if cum_covid_case_per_1000_e_lag != .,d


/***********************
*** Appendix Table 10
***********************/

*** TWFE model with ECP and community COVID-19 prevalence interaction 

*New non-Covid death 
xtreg new_non_covid_death_per_1000_ln c.county_cases_new_1000##i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)  
estimates store new_non_death

*New Covid death 
xtreg new_covid_death_per_1000_ln c.county_cases_new_1000##i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)  
estimates store new_cov_death 

*New total death 
xtreg new_total_death_per_1000_ln c.county_cases_new_1000##i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)  
estimates store new_tot_death
eststo clear

restore 


capture log close 

