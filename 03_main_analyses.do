/********************************************************************************************

	This program can be used to replicate the following tables and figures:
 
	- Table 1
	- Table 2
	- Table 3
	- Figure 1
	- Figure 4

********************************************************************************************/

capture log close 
clear all
set more off
log using "/PATH/Analysis.log", replace 

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

*** Create a variable indicating the first time an observation was treated (ecp_start_week_number)

preserve 
keep if ecp_dich == 1
keep provider_state week_number ecp_dich

sort provider_state week_number
by provider_state: keep if _n == 1
gen ecp_start_week_number = week_number
label values ecp_start_week_number wn
save ecp_start_week.dta, replace 
restore 

*** Merge in ecp_start_week_number
merge m:1 provider_state using "/Users/mingyuqi/Desktop/Research/Essential Caregiver/Code/ecp_start_week.dta", keepusing(ecp_start_week_number)
drop if _merge == 2 
drop _merge 

* Code ecp_start_week_number as 0 for never treated observations for running CSDID
replace ecp_start_week_number = 0 if ecp_start_week_number == . 
tab ecp_start_week_number if cum_covid_case_per_1000_e_lag != . 

numlabel, add
tab ecp_ever if cum_covid_case_per_1000_e_lag != . 

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


/******************************
*** Figure 1
******************************/

preserve 

*** Collapse the data set to state-period level
collapse (mean) ecp_dich = ecp_dich, by(provider_state week_number)

*** Create a heat plot of treatment timing across treatment timing cohorts
set scheme white_tableau

heatplot ecp_dich provider_state week_number, discrete(1) ysize(3.6) xsize(2.7) xlabel(1 "06/21/2020" 2 "07/05/2020" 3 "07/19/2020" 4 "08/02/2020" 5 "08/16/2020" 6 "08/30/2020" 7 "09/13/2020" 8 "09/27/2020" 9 "10/11/2020" 10 "10/25/2020" 11 "11/08/2020" 12 "11/22/2020" 13 "12/06/2020" 14 "12/20/2020" 15 "01/03/2021" 16 "01/17/2021" 17 "01/31/2021" 18 "02/14/2021" 19 "02/28/2021" 20 "03/14/2021" 21 "03/28/2021", labs(vsmall) angle(45) nogrid) xtitle(" ") ylabel(, labsize(vsmall) nogrid) ytitle(" ") colors("217 217 217" "164 52 58", n(2)) legend(subtitle("") col(2) pos(6) bmargin(zero)) p(lcolor(black) lwidth(vvthin)) xsc(outergap(-4)) keylabels(none, off) text(7 8 "{bf:M}", color("234 170 0") size(vsmall)) text(7 8.5 "{it:R}", color("62 177 200") size(vsmall)) text(8 8 "{bf:M}", color("234 170 0") size(vsmall)) text(40 3 "{bf:M}", color("234 170 0") size(vsmall)) text(40 3.5 "{it:R}", color("62 177 200") size(vsmall)) text(42 9 "{bf:M}", color("234 170 0") size(vsmall)) text(13 14 "{it:R}", color("62 177 200") size(vsmall)) text(14 1 "{it:R}", color("62 177 200") size(vsmall)) text(21 1 "{it:R}", color("62 177 200") size(vsmall)) text(36 18 "{it:R}", color("62 177 200") size(vsmall)) text(41 9 "{it:R}", color("62 177 200") size(vsmall)) text(46 6 "{it:R}", color("62 177 200") size(vsmall)) 

graph export "Figure 1.png", replace 

restore 


/******************************
*** Table 1
******************************/

tab ecp_start_week_number if cum_covid_case_per_1000_e_lag != .

*** Summarize outcomes
sum new_non_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_covid_death_per_1000_e if cum_covid_case_per_1000_e_lag != .,d
sum new_total_death_per_1000_e if cum_covid_case_per_1000_e_lag != ., d


/******************************
*** Table 2
******************************/

preserve 

*** Limit observations to those in the baseline period
keep if week_number == 1

table1_mc, by(ecp_ever) ///
vars( ///
bedcert contn %5.2f \ ///
overall_rating contn %5.2f \ ///
quality_rating contn %5.2f \ ///
staffing_rating contn %5.2f \ ///
adj_aide contn %5.2f \ ///
adj_lpn contn %5.2f \ ///
adj_rn contn %5.2f \ ///
adj_total contn %5.2f \ ///
shortage_of_nursing_staff bin %5.2f \ ///
shortage_of_clinical_staff bin %5.2f \ ///
shortage_of_aides bin %5.2f \ ///
ownership_short cat %5.2f \ ///
inhosp bin %5.2f \ ///
multifac_ltcf bin %5.2f \ ///
acu_index_ltcf contn %5.2f \ ///
pay_medicaid_ltcf contn %5.2f \ ///
pay_medicare_ltcf contn %5.2f \ ///
population_65_pct contn %5.2f \ ///
population_black_pct contn %5.2f \ ///
population_hispanic_pct contn %5.2f \ ///
median_household_inc contn %4.0f \ ///
county_cases_new_1000 contn %5.2f \ ///
cum_covid_case_per_1000_e contn %5.2f \ ///
total_covid_death_per_1000_e contn %5.2f \ ///
total_non_covid_death_per_1000_e contn %5.2f \ ///
) ///
nospace onecol missing total(before) ///
saving("Table 2.xlsx", replace)

restore 


/*******************************************************
*** Table 3, Appendix Tables 4, 5, 6, 13 and Figure 4
*******************************************************/

*** Table 3 column 1: static TWFE model 

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

*** Appendix Table 13
esttab using TWFE_Full.csv, se n star(* 0.10 ** 0.05 *** 0.01) replace 
eststo clear

*** Omit always treated and early treated (SD and MN) states and NE
keep if ecp_ever == 0 | !inlist(provider_state, "MI", "IN", "SD", "MN", "NE")

*** Table 3 column 2: TWFE model in the restricted sample 

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

*** Table 3 column 3, Appendix Tables 4, 5, and 6
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

* New non-Covid deaths
eststo: csdid new_non_covid_death_per_1000_ln $covarn,ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num)
estat simple
estat event
*** Appendix Table 4
estat event, window(-10 15) estore(cs)
event_plot cs, plottype(connected) ciplottype(rarea) graph_opt(xtitle("Periods from Implementation of ECP") ytitle("Average Effect") title("{bf:New Non-COVID-19 Deaths}", size(medsmall)) xlabel(-10(1)15) xline(-0.5, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(-0.4(0.1)0.4, angle(horizontal)) legend(pos(6) col(2) region(lcolor(black))) saving("Callaway_new_non_covid_full_notyet.gph", replace)) stub_lag(Tp#) stub_lead(Tm#) lead_opt(color(midblue)) lead_ci_opt(color(midblue%10)) lag_opt(color(orange_red)) lag_ci_opt(color(orange_red%10))   
graph export "Callaway_New_Non_Covid_Deaths_Full_Notyet.png", replace 

* New Covid deaths
eststo: csdid new_covid_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num)
estat simple
estat event
*** Appendix Table 5
estat event, window(-10 15) estore(cs)
event_plot cs, plottype(connected) ciplottype(rarea) graph_opt(xtitle("Periods from Implementation of ECP") ytitle("Average Effect") title("{bf:New COVID-19 Deaths}", size(medsmall)) xlabel(-10(1)15) xline(-0.5, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(-0.4(0.1)0.4, angle(horizontal)) legend(pos(6) col(2) region(lcolor(black))) saving("Callaway_new_covid_full_notyet.gph", replace)) stub_lag(Tp#) stub_lead(Tm#) lead_opt(color(midblue)) lead_ci_opt(color(midblue%10)) lag_opt(color(orange_red)) lag_ci_opt(color(orange_red%10)) 
graph export "Callaway_New_Covid_Deaths_Full_Notyet.png", replace 

* New total deaths
eststo: csdid new_total_death_per_1000_ln $covarn, ivar(federal_provider_number_num) time(week_number) gvar(ecp_start_week_number) rseed(08012022) notyet cluster(provider_state_num)
estat simple
estat event
*** Appendix Table 6
estat event, window(-10 15) estore(cs)
event_plot cs, plottype(connected) ciplottype(rarea) graph_opt(xtitle("Periods from Implementation of ECP") ytitle("Average Effect") title("{bf:New Total Deaths}", size(medsmall)) xlabel(-10(1)15) xline(-0.5, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(-0.4(0.1)0.4, angle(horizontal)) legend(pos(6) col(2) region(lcolor(black))) saving("Callaway_new_total_full_notyet.gph", replace)) stub_lag(Tp#) stub_lead(Tm#) lead_opt(color(midblue)) lead_ci_opt(color(midblue%10)) lag_opt(color(orange_red)) lag_ci_opt(color(orange_red%10)) 
graph export "Callaway_New_Total_Deaths_Full_Notyet.png", replace 

*** Figure 3: Combine three graphs into one
grc1leg2 Callaway_new_non_covid_full_notyet.gph Callaway_new_covid_full_notyet.gph Callaway_new_total_full_notyet.gph, row(3) imargin(1 1 1 1) lc(2) legs(2.2) xsize(3.5) ysize(5) iscale(0.62)
graph export "Callaway_Full_Notyet_Combine_State_SE_LogTrans_Death_and_Case_History.png", replace 

*** Table 3 column 4: Sun and Abraham method 

* Create a never treated indicator
gen never_ecp = (ecp_start_week_number == 0)

* Code indicators for periods relative to treatment period
replace ecp_start_week_number = . if ecp_start_week_number == 0
gen relative_week = week_number - ecp_start_week_number

* Check if there is sufficient number of treated units for each relative period
tab relative_week, m

* Generate relative period indicators
forvalues k = 17(-1)2 {
    gen lead_`k' = relative_week == -`k'
}

forvalues k = 0/15 {
        gen lag_`k' = relative_week == `k'
}

* New non-Covid deaths
eststo: eventstudyinteract new_non_covid_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster provider_state_num)
matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom (lag_1 + lag_2 + lag_3 + lag_4 + lag_5 + lag_6 + lag_7 + lag_8 + lag_9 + lag_10 + lag_11 + lag_12 + lag_13 + lag_14 + lag_15)/15

* New Covid deaths
eststo: eventstudyinteract new_covid_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster provider_state_num)
matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom (lag_1 + lag_2 + lag_3 + lag_4 + lag_5 + lag_6 + lag_7 + lag_8 + lag_9 + lag_10 + lag_11 + lag_12 + lag_13 + lag_14 + lag_15)/15

* New total deaths
eststo: eventstudyinteract new_total_death_per_1000_ln lead_* lag_* i, cohort(ecp_start_week_number) control_cohort(never_ecp) covariates($covarn) absorb(i.federal_provider_number_num i.week_number) vce(cluster provider_state_num)
matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom (lag_1 + lag_2 + lag_3 + lag_4 + lag_5 + lag_6 + lag_7 + lag_8 + lag_9 + lag_10 + lag_11 + lag_12 + lag_13 + lag_14 + lag_15)/15

esttab using Sun_Full.csv, se n star(* 0.10 ** 0.05 *** 0.01) replace
eststo clear


capture log close 

