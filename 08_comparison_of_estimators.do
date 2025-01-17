/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Appendix Figure 5

********************************************************************************************/

capture log close 
clear all
set more off
log using "/PATH/Estimators_Comparison.log", replace 

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

*** Merge in ecp_start_week_number
merge m:1 provider_state using "/Users/mingyuqi/Desktop/Research/Essential Caregiver/Code/ecp_start_week.dta", keepusing(ecp_start_week_number)
drop if _merge == 2 
drop _merge 

* Code ecp_start_week_number as 0 for never treated observations for running CSDID
replace ecp_start_week_number = 0 if ecp_start_week_number == . 
tab ecp_start_week_number if cum_covid_case_per_1000_e_lag != . 

numlabel, add
tab ecp_ever if cum_covid_case_per_1000_e_lag != . 

*** Create a never treated indicator
gen never_ecp = (ecp_start_week_number == .)

set scheme white_ptol

*** Callaway and Sant'Anna (2020)

* CSDID require never treated coded as 0
replace ecp_start_week_number = 0 if ecp_start_week_number == . 
tab ecp_start_week_number if new_non_covid_death_per_1000_e != .
tab week_number ecp_start_week_number

* New non-COVID-19 deaths
eststo: csdid new_non_covid_death_per_1000_ln $covarn,ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num) rseed(08012022) notyet
estat event, estore(cs_non)
estat group 

* New COVID-19 deaths
eststo: csdid new_covid_death_per_1000_ln $covarn,ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num) rseed(08012022) notyet
estat event, estore(cs_cov)

* New total deaths
eststo: csdid new_total_death_per_1000_ln $covarn,ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num) rseed(08012022) notyet
estat event, estore(cs_tot)


*** Sun and Abraham (2020)

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

* New non-COVID-19 deaths
eststo: eventstudyinteract new_non_covid_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster provider_state_num)
matrix sa_b_non = e(b_iw)
matrix sa_V_non = e(V_iw)

* New COVID-19 deaths
eststo: eventstudyinteract new_covid_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster provider_state_num)
matrix sa_b_cov = e(b_iw)
matrix sa_V_cov = e(V_iw)

* New total deaths
eststo: eventstudyinteract new_total_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster provider_state_num)
matrix sa_b_tot = e(b_iw)
matrix sa_V_tot = e(V_iw)


*** TWFE OLS

* New non-COVID-19 deaths
reghdfe new_non_covid_death_per_1000_ln lead_* lag_* i, a(i.federal_provider_number_num i.week_number) cluster(i.provider_state_num)
estimates store ols_non

* New non-COVID-19 deaths
reghdfe new_covid_death_per_1000_ln lead_* lag_* i, a(i.federal_provider_number_num i.week_number) cluster(i.provider_state_num)
estimates store ols_cov

* New non-COVID-19 deaths
reghdfe new_total_death_per_1000_ln lead_* lag_* i, a(i.federal_provider_number_num i.week_number) cluster(i.provider_state_num)
estimates store ols_tot

*** Combine all plots using the stored estimates

* New non-COVID-19 deaths
event_plot cs_non sa_b_non#sa_V_non ols_non, ///
	stub_lag(Tp# lag_# lag_#) stub_lead(Tm# lead_# lead_#) plottype(scatter) ciplottype(rcap) ///
	together perturb(-0.4(0.1)0.4) trimlead(6) trimlag(15) noautolegend ///
	graph_opt(saving("Est_Combine_Non_COV_Log.gph", replace) title("{bf:New Non-COVID-19 Deaths}", size(medsmall)) xtitle("Periods from Implementation of ECP") ytitle("Average Effect") ///
	xlabel(-6(1)15) ylabel(-0.4(0.1)0.4) graphregion(color(white)) bgcolor(white) ///
	legend(pos(6) col(3) order(1 "Callaway-Sant'Anna" 3 "Sun-Abraham" 5 "OLS") region(lcolor(black))) ///
	/// the following lines replace default_look with something more elaborate
	xline(-0.5, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(,angle(horizontal)) ///
	) ///
	lag_opt1(msymbol(Sh) color(cranberry)) lag_ci_opt1(color(cranberry)) ///
	lag_opt2(msymbol(Th) color(forest_green)) lag_ci_opt2(color(forest_green)) ///
	lag_opt3(msymbol(Dh) color(purple)) lag_ci_opt3(color(purple)) 

* New COVID-19 deaths
event_plot cs_cov sa_b_cov#sa_V_cov ols_cov, ///
	stub_lag(Tp# lag_# lag_#) stub_lead(Tm# lead_# lead_#) plottype(scatter) ciplottype(rcap) ///
	together perturb(-0.4(0.1)0.4) trimlead(6) trimlag(15) noautolegend ///
	graph_opt(saving("Est_Combine_COV_Log.gph", replace) title("{bf:New COVID-19 Deaths}", size(medsmall)) xtitle("Periods from Implementation of ECP") ytitle("Average Effect") ///
	xlabel(-6(1)15) ylabel(-0.4(0.1)0.4) graphregion(color(white)) bgcolor(white) ///
	legend(pos(6) col(3) order(1 "Callaway-Sant'Anna" 3 "Sun-Abraham" 5 "OLS") region(lcolor(black))) ///
	/// the following lines replace default_look with something more elaborate
	xline(-0.5, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(,angle(horizontal)) ///
	) ///
	lag_opt1(msymbol(Sh) color(cranberry)) lag_ci_opt1(color(cranberry)) ///
	lag_opt2(msymbol(Th) color(forest_green)) lag_ci_opt2(color(forest_green)) ///
	lag_opt3(msymbol(Dh) color(purple)) lag_ci_opt3(color(purple)) 
	
* New non-COVID-19 deaths
event_plot cs_tot sa_b_tot#sa_V_tot ols_tot, ///
	stub_lag(Tp# lag_# lag_#) stub_lead(Tm# lead_# lead_#) plottype(scatter) ciplottype(rcap) ///
	together perturb(-0.4(0.1)0.4) trimlead(6) trimlag(15) noautolegend ///
	graph_opt(saving("Est_Combine_Tot_Log.gph", replace) title("{bf:New Total Deaths}", size(medsmall)) xtitle("Periods from Implementation of ECP") ytitle("Average Effect") ///
	xlabel(-6(1)15) ylabel(-0.4(0.1)0.4) graphregion(color(white)) bgcolor(white) ///
	legend(pos(6) col(3) order(1 "Callaway-Sant'Anna" 3 "Sun-Abraham" 5 "OLS") region(lcolor(black))) ///
	/// the following lines replace default_look with something more elaborate
	xline(-0.5, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(,angle(horizontal)) ///
	) ///
	lag_opt1(msymbol(Sh) color(cranberry)) lag_ci_opt1(color(cranberry)) ///
	lag_opt2(msymbol(Th) color(forest_green)) lag_ci_opt2(color(forest_green)) ///
	lag_opt3(msymbol(Dh) color(purple)) lag_ci_opt3(color(purple)) 

	
/******************************
*** Appendix Figure 5
******************************/
*Combine graphs
grc1leg2 Est_Combine_Non_COV_Log.gph Est_Combine_COV_Log.gph Est_Combine_Tot_Log.gph, row(3) imargin(1 1 1 1) lc(3) legs(2.2) xsize(3.5) ysize(5) iscale(0.62) 
graph export "Appendix Figure 5.png", replace 


capture log close 
	
	