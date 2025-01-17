/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Table 4
	- Appendix Table 5
	- Appendix Table 6
	- Appendix Table 7
	- Appendix Table 8
	- Appendix Table 9

********************************************************************************************/

capture log close 
clear all
set more off
log using "Heterogeneity.log", replace 

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

*** Omit always treated and early treated (SD and MN) states and NE
keep if ecp_ever == 0 | !inlist(provider_state, "MI", "IN", "SD", "MN", "NE")

*** Merge in ecp_start_week_number
merge m:1 provider_state using "/Users/mingyuqi/Desktop/Research/Essential Caregiver/Code/ecp_start_week.dta", keepusing(ecp_start_week_number)
drop if _merge == 2 
drop _merge 

* Code ecp_start_week_number as 0 for never treated observations for running CSDID
replace ecp_start_week_number = 0 if ecp_start_week_number == . 
tab ecp_start_week_number if cum_covid_case_per_1000_e_lag != .

* Drop treatment cohort with small sample size
drop if ecp_start_week_number == 15

* Create never treated indicator
gen never_ecp = (ecp_start_week_number == .)


/********************************************************
*** Table 4, Appendix Tables 5, 6, 7, 8, 9 
********************************************************/

set scheme white_ptol

merge m:1 federal_provider_number using base_covid_non_covid_death.dta, keepusing(base_covid_death_per_1000_e base_non_covid_death_per_1000_e)
drop _merge 

*** High overall rating in the baseline period 

* Create a binary indicator for high overall rating in baseline period
preserve 

keep if week_number == 1

sum overall_rating , d
keep if overall_rating > 3 

gen high_baseline_rating = 1 

keep federal_provider_number high_baseline_rating
duplicates drop

save high_baseline_rating_nh.dta, replace 

restore 

* Limit the sample to nursing homes with high overall rating in the baseline period 
preserve 

merge m:1 federal_provider_number using high_baseline_rating_nh.dta, keepusing(high_baseline_rating)
drop _merge

keep if high_baseline_rating == 1
sum overall_rating, d

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** Low overall rating 

* Limit the sample to nursing homes with low overall rating in the baseline period 
preserve 

merge m:1 federal_provider_number using high_baseline_rating_nh.dta, keepusing(high_baseline_rating)
drop _merge 

keep if high_baseline_rating == .
sum overall_rating, d

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** High staffing level 

* Create a binary indicator for high staffing level in the baseline period
preserve 

keep if week_number == 1 
sum adj_total, d
xtile  quintile_adj_total = adj_total, nq(10)
table quintile_adj_total, stat(max adj_total)

* This needs to be changed if the sample is different;
keep if quintile_adj_total > 5
gen high_baseline_staffing_level = 1

keep federal_provider_number high_baseline_staffing_level
duplicates drop

save high_baseline_staffing_level_nh.dta, replace 

restore 

preserve 

merge m:1 federal_provider_number using high_baseline_staffing_level_nh.dta, keepusing(high_baseline_staffing_level)
drop _merge 

* Limit to NHs with high staffing level at baseline
keep if high_baseline_staffing_level == 1
sum adj_total, d

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

*** Log-transforma the dependent variables
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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** Low staffing level 
preserve 

merge m:1 federal_provider_number using high_baseline_staffing_level_nh.dta, keepusing(high_baseline_staffing_level)
drop _merge 

* Limit to NHs with low staffing level at baseline
keep if high_baseline_staffing_level == .
sum adj_total, d

tab week_number  ecp_start_week_number
 
* Drop treatment cohort with small sample size
drop if ecp_start_week_number == 18

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** Not for-profit
preserve 

keep if ownership_short == 3

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** For-profit
preserve 

keep if ownership_short == 1

tab week_number  ecp_start_week_number

* Drop treatment cohort with small sample size
drop if ecp_start_week_number == 18

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore  


*** Without restriction 
preserve 

drop if inlist(provider_state, "DE", "IL", "IN", "MI", "OR", "SD", "TN", "WA")

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** With restriction 
preserve 

keep if inlist(provider_state, "DE", "IL", "IN", "MI", "OR", "SD", "TN", "WA") | ecp_ever == 0

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** Mandatory
preserve 

keep if ecp_ever == 0 | inlist(provider_state, "DE", "FL", "SD", "TX")

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


*** Non-mandatory
preserve 

keep if ecp_ever == 0 | !inlist(provider_state, "DE", "FL", "SD", "TX")

tab week_number  ecp_start_week_number

sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d

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

* New non-Covid death
qui csdid new_non_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New Covid death
qui csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

* New total death
qui csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet wboot cluster(provider_state_num)
estat simple
estat event

restore 


capture log close 

