capture log close 
clear all
set more off
log using "/PATH/Analysis_Balanced_Sample.log", replace 

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
 
*** Limiting the sample to observations of NHs with exact 21 records 
sort federal_provider_number week_number 
by federal_provider_number: egen week_number_count = count(week_number)
tab week_number_count

keep if week_number_count == 21 

*** Merge in ecp_start_week_number
merge m:1 provider_state using "/Users/mingyuqi/Desktop/Research/Essential Caregiver/Code/ecp_start_week.dta", keepusing(ecp_start_week_number)
drop if _merge == 2 
drop _merge 

* CSDID require never treated coded as 0
replace ecp_start_week_number = 0 if ecp_start_week_number == . 
tab ecp_start_week_number if cum_covid_case_per_1000_e_lag != . 

numlabel, add
tab ecp_ever if cum_covid_case_per_1000_e_lag != . 

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

*** Summarize treatment cohorts 
tab ecp_start_week_number if cum_covid_case_per_1000_e_lag != .

*** Summarize outcomes
sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d


/******************************
*** Appendix Table 1
******************************/

*** Static TWFE model 

* New non-Covid deaths
eststo: qui xtreg new_non_covid_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)  
estimates store new_non_death

* New Covid deaths 
eststo: qui xtreg new_covid_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num) 
estimates store new_cov_death 

* New total deaths 
eststo: qui xtreg new_total_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num) 
estimates store new_total_death

esttab  new_non_death new_cov_death new_total_death, keep(1.ecp_dich) title("TWFE (Full Sample)") se n star(* 0.10 ** 0.05 *** 0.01)

esttab using TWFE_Full.csv, se n star(* 0.10 ** 0.05 *** 0.01) replace 
eststo clear

restore 

*** Omit always treated, early treated (SD and MN) and NE
keep if ecp_ever == 0 | !inlist(provider_state, "MI", "IN", "SD", "MN", "NE")


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


*** TWFE model in the restricted sample 

* New non-Covid deaths
eststo: qui xtreg new_non_covid_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)
estimates store new_non_death

* New Covid deaths 
eststo: qui xtreg new_covid_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)
estimates store new_cov_death 

* New total deaths 
eststo: qui xtreg new_total_death_per_1000_ln i.ecp_dich i.week_number $covarn, i(federal_provider_number_num) fe vce(cluster provider_state_num)
estimates store new_total_death

esttab  new_non_death new_cov_death new_total_death, keep(1.ecp_dich) title("TWFE (Restricted Sample)") se n star(* 0.10 ** 0.05 *** 0.01)
eststo clear

*** Callaway method - use not yet treated as controls 
set scheme white_ptol

* Summarize outcomes in the estimation sample
preserve 

drop if ecp_start_week_number >= 15
drop if ecp_start_week_number == 14 & week_number >9

* Summarize outcomes
sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

restore 

* New non-Covid death
eststo: csdid new_non_covid_death_per_1000_ln $covarn,ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num)
estat simple
estat event

* New Covid death
eststo: csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num)
estat simple
estat event

* New total death
eststo: csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num)
estat simple
estat event 

*** Sun and Abraham method 

* Create never treated indicator
gen never_ecp = (ecp_start_week_number == 0)

* Code the relative time categorical variable
replace ecp_start_week_number = . if ecp_start_week_number == 0
gen relative_week = week_number - ecp_start_week_number

* Check if there is a sufficient number of treated units for each relative time
tab relative_week, m

* Generate relative time indicators
forvalues k = 17(-1)2 {
    gen lead_`k' = relative_week == -`k'
}

forvalues k = 0/15 {
        gen lag_`k' = relative_week == `k'
}

* New non-Covid death
eststo: eventstudyinteract new_non_covid_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster federal_provider_number_num)
matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom (lag_1 + lag_2 + lag_3 + lag_4 + lag_5 + lag_6 + lag_7 + lag_8 + lag_9 + lag_10 + lag_11 + lag_12 + lag_13 + lag_14 + lag_15)/15

* New Covid death
eststo: eventstudyinteract new_covid_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster federal_provider_number_num)
matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom (lag_1 + lag_2 + lag_3 + lag_4 + lag_5 + lag_6 + lag_7 + lag_8 + lag_9 + lag_10 + lag_11 + lag_12 + lag_13 + lag_14 + lag_15)/15

* New total death
eststo: eventstudyinteract new_total_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster federal_provider_number_num)
matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom (lag_1 + lag_2 + lag_3 + lag_4 + lag_5 + lag_6 + lag_7 + lag_8 + lag_9 + lag_10 + lag_11 + lag_12 + lag_13 + lag_14 + lag_15)/15

*esttab using Sun_Full.csv, se n star(* 0.10 ** 0.05 *** 0.01) replace
eststo clear


capture log close 

