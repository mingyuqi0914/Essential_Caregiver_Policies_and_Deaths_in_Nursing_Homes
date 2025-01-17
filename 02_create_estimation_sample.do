/********************************************************************************************

	This program generates the estimation sample in which the analyses were done. 

********************************************************************************************/

capture log close 
clear all
set more off
log using "/PATH/Create_Estimation_Sample.log", replace 

*** Define covariates
global covar bedcert overall_rating quality_rating staffing_rating adj_aide adj_lpn adj_rn adj_total shortage_of_nursing_staff shortage_of_clinical_staff shortage_of_aides ownership_short inhosp multifac_ltcf acu_index_ltcf pay_medicaid_ltcf pay_medicare_ltcf population_65_pct population_black_pct population_hispanic_pct median_household_inc county_cases_new_1000

*** Import analytical data set
use "/Users/mingyuqi/Desktop/Research/Essential Caregiver/Data/NH_COVID_FAC_2020_2021.dta", replace 

*** Drop observations with missing values, and limit study sample to 06/2020 - 03/2021
foreach var of global covar {
    drop if missing(`var')
}
drop if missing(total_non_covid_death_per_1000_e) | missing(total_covid_death_per_1000_e) |  missing(week_non_covid_death_per_1000_e) | missing(week_covid_death_per_1000_e) | total_number_of_occupied_beds == 0

* Keep only records before March 2021
keep if week_ending_year == "2020" | (week_ending_year == "2021" & inlist(week_ending_month, "01","02","03") )

*** Create a numeric two-week period indicator 
preserve 
	keep week_ending_date 
	duplicates drop 
	sort week_ending_date 
	gen week_number = _n
	replace week_number = week_number[_n-1] if mod(week_number, 2) == 0
	replace week_number = (week_number + 1)/2 if week_number != 1
	label define wn 1 "08Jun2020 - 21Jun2020" 2 "22Jun2020 - 05Jul2020" 3 "06Jul2020 - 19Jul2020" 4 "20Jul2020 - 02Aug2020" 5 "03Aug2020 - 16Aug2020" 6 "17Aug2020 - 30Aug2020" 7 "31Aug2020 - 13Sep2020" 8 "14Sep2020 - 27Sep2020" 9 "28Sep2020 - 11Oct2020" 10 "12Oct2020 - 25Oct2020" 11 "26Oct2020 - 08Nov2020" 12 "09Nov2020 - 22Nov2020" 13 "23Nov2020 - 06Dec2020" 14 "07Dec2020 - 20Dec2020" 15 "21Dec2020 - 03Jan2021" 16 "04Jan2021 - 17Jan2021" 17 "18Jan2021 - 31Jan2021" 18 "01Feb2021 - 14Feb2021" 19 "15Feb2021 - 28Feb2021" 20 "01Mar2021 - 14Mar2021" 21 "15Mar2021 - 28Mar2021" 
	label values week_number wn
	save week_number.dta, replace 
restore 

merge m:1 week_ending_date using week_number.dta, keepusing(week_number)
drop _merge 


***Create two-week period level ECP indicator

preserve 
	collapse (min) ecp_dich_new = ecp_dich (min) ecp_ever_new = ecp_ever, by (provider_state week_number)  
	save ecp_week_number.dta, replace 
restore

merge m:1 provider_state week_number using ecp_week_number.dta, keepusing(ecp_dich_new ecp_ever_new)
drop _merge 


*** Collapse data set to biweekly level 
sort federal_provider_number week_number week_ending_date

collapse (first) provider_state (first) ecp_ever = ecp_ever_new (first) ecp_dich = ecp_dich_new (mean) bedcert (mean) overall_rating (mean) quality_rating (mean) staffing_rating (mean) adj_aide (mean) adj_lpn (mean) adj_rn (mean) adj_total  (first) shortage_of_nursing_staff (first) shortage_of_clinical_staff (first) shortage_of_aides (first) ownership_short (first) inhosp (first) multifac_ltcf (first) acu_index_ltcf (first) pay_medicaid_ltcf (first) pay_medicare_ltcf (first) population_65_pct (first) population_black_pct (first) population_hispanic_pct (first) median_household_inc (sum) county_cases_new_1000 (last) total_non_covid_death_per_1000_e (last) total_covid_death_per_1000_e (sum) weekly_non_covid_19_deaths (sum) residents_weekly_covid_19_death (sum) residents_weekly_confirmed_covi (last) residents_total_confirmed_covid (sum) total_number_of_occupied_beds (sum) net_change (last) cumulative_residents_served (last) residents_total_covid_19_deaths (last) total_non_covid_19_deaths, by (federal_provider_number week_number)

gen new_non_covid_death_per_1000_e = (weekly_non_covid_19_deaths / total_number_of_occupied_beds) * 1000
gen new_covid_death_per_1000_e = (residents_weekly_covid_19_death / total_number_of_occupied_beds) * 1000
egen new_total_death = rowtotal(weekly_non_covid_19_deaths residents_weekly_covid_19_death)
gen new_total_death_per_1000_e = (new_total_death / total_number_of_occupied_beds) * 1000

**Create numeric id variable for SNF provider number
egen federal_provider_number_num = group(federal_provider_number)

**Save estimation sample 
save "/Users/mingyuqi/Desktop/Research/Essential Caregiver/Data/NH_COVID_FAC_2020_2021_E.dta", replace 

capture log close 
