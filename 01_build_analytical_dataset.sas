/*******************************************************************************************************************************
*******************************************************************************************************************************
*** Project: Essential Caregiver Policies and Nursing Home Deaths
*** Description: Clean and compile 2020 and 2021 CMS nursing home COVID-19 data and merge with other data sources
*** Input data: CMS COVID-19 Nursing Home data (https://data.cms.gov/covid-19/covid-19-nursing-home-data)
				2019 LTCFocus data (https://ltcfocus.org/data), 
				2020 and 2021 monthly Nursing Home Compare data (https://data.cms.gov/provider-data/topics/nursing-homes), 
				NYTimes COVID-19 data (https://github.com/nytimes/covid-19-data), 
				American Community Survey 2018-2022 5-year Estimates data (https://www.socialexplorer.com/explore-tables)
*** Output data: NH_COVID_FAC_2020_2021_16  
*** Author: Mingyu Qi
*** Last updated: Jan 10, 2025
*******************************************************************************************************************************
*******************************************************************************************************************************/

/* Set up SAS library */
libname cms "Z:\Essential_caregiver\Data\CMS";
libname census "Z:\Essential_caregiver\Data\Census";
libname xwalk "Z:\Essential_caregiver\Data\Crosswalk";

/* Define SAS format */
proc format;
    value yesno
      1 = 'Yes'
      0 = 'No';
	value profit
	  1 = "For profit"
	  2 = "Government"
	  3 = "Non profit";
run;

/* Read Nursing Home Covid-19 data into SAS */
%macro import(year = );
	proc import datafile = "Z:\Essential_caregiver\Data\CMS\faclevel_&year..csv"
				dbms = csv replace 
				out = nh_covid_fac_&year._0;
	run;
%mend;

%import(year = 2020);
%import(year = 2021);

/* Combine 2020 and 2021 Nursing Home Covid-19 data and keep only records that past the quality assurance check */
data nh_covid_fac_2020_2021_0;
	set nh_covid_fac_2020_0(keep = 
		week_ending Federal_Provider_Number provider_name provider_city provider_state provider_zip_code county
		Residents_Weekly_Admissions_COV Residents_Total_Admissions_COVI Residents_Weekly_Confirmed_COVI Residents_Total_Confirmed_COVID
		Residents_Total_Suspected_COVID Residents_Weekly_All_Deaths Residents_Total_All_Deaths 
		Residents_Weekly_COVID_19_Death Residents_Total_COVID_19_Deaths number_of_all_beds total_number_of_occupied_beds total_: 
		Shortage_of_Nursing_Staff Shortage_of_Clinical_Staff Shortage_of_Aides Shortage_of_Other_Staff 
		Any_Current_Supply_of_N95_Masks One_Week_Supply_of_N95_Masks Any_Current_Supply_of_Surgical One_Week_Supply_of_Surgical_Mas
		Any_Current_Supply_of_Eye_Prote One_Week_Supply_of_Eye_Protecti Any_Current_Supply_of_Gowns One_Week_Supply_of_Gowns
		Any_Current_Supply_of_Gloves One_Week_Supply_of_Gloves Any_Current_Supply_of_Hand_Sani One_Week_Supply_of_Hand_Sanitiz
		Resident_Access_to_Testing_in_F Able_to_Test_or_Obtain_Resource VAR42
		Submitted_Data passed_quality_assurance_check Weekly_Resident_Confirmed_COVID Weekly_Resident_COVID_19_Deaths Total_Resident_Confirmed_COVID_
		Total_Resident_COVID_19_Deaths Total_Residents_COVID_19_Deaths)

		nh_covid_fac_2021_0(keep = 
		week_ending Federal_Provider_Number provider_name provider_city provider_state provider_zip_code county
		Residents_Weekly_Admissions_COV Residents_Total_Admissions_COVI Residents_Weekly_Confirmed_COVI Residents_Total_Confirmed_COVID
		Residents_Total_Suspected_COVID Residents_Weekly_All_Deaths Residents_Total_All_Deaths 
		Residents_Weekly_COVID_19_Death Residents_Total_COVID_19_Deaths number_of_all_beds total_number_of_occupied_beds total_:
		Shortage_of_Nursing_Staff Shortage_of_Clinical_Staff Shortage_of_Aides Shortage_of_Other_Staff 
		Any_Current_Supply_of_N95_Masks One_Week_Supply_of_N95_Masks Any_Current_Supply_of_Surgical One_Week_Supply_of_Surgical_Mas
		Any_Current_Supply_of_Eye_Prote One_Week_Supply_of_Eye_Protecti Any_Current_Supply_of_Gowns One_Week_Supply_of_Gowns
		Any_Current_Supply_of_Gloves One_Week_Supply_of_Gloves Any_Current_Supply_of_Hand_Sani One_Week_Supply_of_Hand_Sanitiz
		Resident_Access_to_Testing_in_F Able_to_Test_or_Obtain_Resource VAR42
		Submitted_Data passed_quality_assurance_check Weekly_Resident_Confirmed_COVID Weekly_Resident_COVID_19_Deaths Total_Resident_Confirmed_COVID_
		Total_Resident_COVID_19_Deaths Total_Residents_COVID_19_Deaths);

	* Create week ending day, month and year variable;
	week_ending_year = "20"||substr(week_ending, 7, 2);
	week_ending_month = substr(week_ending, 1, 2);
	week_ending_day = substr(week_ending, 4, 2);
	week_ending_date = mdy(week_ending_month, week_ending_day, week_ending_year);
	week_starting_date = week_ending_date - 7;
	format week_ending_date week_starting_date date9.;
	
	rename Any_Current_Supply_of_Surgical = Any_Current_Supply_of_Sur_Masks 
		   One_Week_Supply_of_Surgical_Mas = One_Week_Supply_of_Sur_Masks
		   Any_Current_Supply_of_Eye_Prote = Any_Current_Supply_of_Eye_Prot
	       One_Week_Supply_of_Eye_Protecti = One_Week_Supply_of_Eye_Prot
		   Any_Current_Supply_of_Hand_Sani = Any_Current_Supply_of_Sanitizer
           One_Week_Supply_of_Hand_Sanitiz = One_Week_Supply_of_Sanitizer
		   Able_to_Test_or_Obtain_Resource = Able_to_Test_Residents_7_Days
		   VAR42 = Able_to_Test_Staffs_7_Days
		   Weekly_Resident_Confirmed_COVID = Weekly_Covid_Case_per_1000
		   Weekly_Resident_COVID_19_Deaths = Weekly_Covid_Death_per_1000
           Total_Resident_Confirmed_COVID_ = Total_Covid_Case_per_1000
	       Total_Resident_COVID_19_Deaths = Total_Covid_Death_per_1000
           Total_Residents_COVID_19_Deaths = Total_Covid_Death_Pct;
	where Submitted_Data =: "Y" and passed_quality_assurance_check =: "Y";
run; * 1,260,340;

proc sort data = nh_covid_fac_2020_2021_0 nodupkey; by Federal_Provider_Number week_ending_date; run;

* Check % of observations with missing provider state and week ending date;
proc sql;
	create table check_missing as 
	select provider_state
	from nh_covid_fac_2020_2021_0
	where provider_state = "" | week_ending_date = . ;
quit; *0 missing;

* Check missing death outcomes;
proc means data = NH_COVID_FAC_2020_2021_0 n nmiss;
	var Residents_Weekly_All_Deaths Residents_Weekly_COVID_19_Death Residents_Total_All_Deaths Residents_Total_COVID_19_Deaths;
run; 

/* Create Essential Caregiver Policy (ECP) indicator at state level */
data nh_covid_fac_2020_2021_1;
	set nh_covid_fac_2020_2021_0;
	*AZ;
	if provider_state = "AZ" & week_ending_date - 7 >= input("23SEP2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*DE;
	else if provider_state = "DE" & week_ending_date - 7 >= input("07SEP2020", date9.) & week_ending_date <= input("26JAN2021", date9.)
		then do; ecp_dich= 1; ecp_cat = 1; end;
	else if provider_state = "DE" & week_ending_date > input("26JAN2021", date9.) /* Changed from with restriction to without restriction */
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*FL;
	*https://www.floridadisaster.org/globalassets/executive-orders/covid-19/dem-order-no.-20-011-in-re-covid-19-public-health-emergency-issued-october-22-2020.pdf;
	else if provider_state = "FL" & week_ending_date - 7 >= input("09SEP2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*IL;
	else if provider_state = "IL" & week_ending_date - 7 >= input("02DEC2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 1; end;
	*IN;
	*It seems that the ECP did not end in Nov 2020, according to https://www.in.gov/health/files/LTC-Newsletter-11.20.-2020.pdf;
	else if provider_state = "IN" & week_ending_date - 7 >= input("05JUN2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 1; end;
	*MI;
	else if provider_state = "MI" & week_ending_date - 7 >= input("01JUN2020", date9.) & week_ending_date <= input("02MAR2021", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	else if provider_state = "MI" & week_ending_date > input("02MAR2021", date9.) 
		then do; ecp_dich= 1; ecp_cat = 1; end;
	*MN;
	else if provider_state = "MN" & week_ending_date - 7 >= input("10JUL2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*MO;
	else if provider_state = "MO" & week_ending_date - 7 >= input("22SEP2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*NE;
	else if provider_state = "NE" & week_ending_date - 7 >= input("02DEC2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*NJ;
	else if provider_state = "NJ" & week_ending_date - 7 >= input("10AUG2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*OK;
	else if provider_state = "OK" & week_ending_date - 7 >= input("09SEP2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*OR;
	else if provider_state = "OR" & week_ending_date - 7 >= input("29JAN2021", date9.) 
		then do; ecp_dich= 1; ecp_cat = 1; end;
	*RI;
	else if provider_state = "RI" & week_ending_date - 7 >= input("14DEC2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*SD;
	else if provider_state = "SD" & week_ending_date - 7 >= input("26JUN2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 1; end;
	*TN;
	else if provider_state = "TN" & week_ending_date - 7 >= input("17SEP2020", date9.) & week_ending_date <= input("01OCT2020", date9.)
		then do; ecp_dich= 1; ecp_cat = 2; end;
	else if provider_state = "TN" & week_ending_date > input("01OCT2020", date9.) 
		then do; ecp_dich= 1; ecp_cat = 1; end;
	*TX;
	else if provider_state = "TX" & week_ending_date - 7 >= input("24SEP2020", date9.)
		then do; ecp_dich= 1; ecp_cat = 2; end;
	*WA;
	else if provider_state = "WA" & week_ending_date - 7 >= input("06AUG2020", date9.) & week_ending_date <= input("15NOV2020", date9.)
		then do; ecp_dich= 1; ecp_cat = 1; end;
	else if provider_state = "WA" & week_ending_date > input("15NOV2020", date9.)
		then do; ecp_dich= 1; ecp_cat = 2; end;

	else do; ecp_dich= 0; ecp_cat = 0; end;

	label ecp_dich= "Dichotomous ECP Indicator" ecp_cat = "Categorical ECP Indicator";

	* Create non-Covid-19 death variable; 
	Weekly_Non_Covid_19_Deaths = Residents_Weekly_All_Deaths - Residents_Weekly_COVID_19_Death;
	Total_Non_Covid_19_Deaths = Residents_Total_All_Deaths - Residents_Total_COVID_19_Deaths;

	* Limit records to those were reported after Jun 1st, 2020 for higher data quality;
	where week_ending_date - 7 >= input("01JUN2020", date9.);
run; *1,216,183;

* Check number of unique nursing homes in the data set;
proc sql;
	create table nh_unique as 
	select distinct Federal_Provider_Number
	from NH_COVID_FAC_2020_2021_1;
quit; *15,296;

* Check ECP variables;
proc freq data = NH_COVID_FAC_2020_2021_1;
	tables ecp_dich ecp_cat ;
run;

/* Exclude records of nursing homes that ever reported negative non-covid-19 deaths as there records might be associated with lower data quality */
proc sql; 
	create table NH_COVID_FAC_2020_2021_2 as 
	select * 
	from NH_COVID_FAC_2020_2021_1
	where Federal_Provider_Number not in (
		select Federal_Provider_Number from NH_COVID_FAC_2020_2021_1
		where (weekly_non_covid_19_deaths ^=. & weekly_non_covid_19_deaths < 0) | 
			   total_non_covid_19_deaths ^=. & total_non_covid_19_deaths < 0); 
quit; *1,193,633;

* Check number of unique nursing homes remained in the data set;
proc sql;
	create table nh_unique as 
	select distinct Federal_Provider_Number
	from NH_COVID_FAC_2020_2021_2;
quit; *15,013;

/* Exclude records of nursing homes that reported negative non-occupied beds as there records might be associated with lower data quality */
proc sql; 
	create table NH_COVID_FAC_2020_2021_3 as 
	select * 
	from NH_COVID_FAC_2020_2021_2
	where Federal_Provider_Number not in (
		select Federal_Provider_Number from NH_COVID_FAC_2020_2021_2
		where number_of_all_beds < total_number_of_occupied_beds & number_of_all_beds ^= .); 
quit; *1,156,055;

* Check number of unique nursing homes remained in the data set;
proc sql;
	create table nh_unique as 
	select distinct Federal_Provider_Number
	from NH_COVID_FAC_2020_2021_3;
quit; *14,542;

/* Exclude records of nursing homes that report number of weekly all deaths greater than number of occupied beds */
proc sql; 
	create table NH_COVID_FAC_2020_2021_4 as 
	select * 
	from NH_COVID_FAC_2020_2021_3
	where Federal_Provider_Number not in (
		select Federal_Provider_Number from NH_COVID_FAC_2020_2021_3
		where Residents_Weekly_All_Deaths > total_number_of_occupied_beds & total_number_of_occupied_beds ^= .); 
quit; *1,147,885;

* Check number of unique nursing homes remained in the data set;
proc sql;
	create table nh_unique as 
	select distinct Federal_Provider_Number
	from NH_COVID_FAC_2020_2021_4;
quit; *14,438;

/* Create an estimated number of residents served at weekly level following the method introduced in Miller et al. (2021) */
proc sort data = NH_COVID_FAC_2020_2021_4; by Federal_Provider_Number week_ending_date; run;

* Create estimated cumulative residents served variable using method developed by (Miller et al., 2016);
data NH_COVID_FAC_2020_2021_5;
	set NH_COVID_FAC_2020_2021_4;
	retain cumulative_residents_served;
	by Federal_Provider_Number week_ending_date;
	number_of_occupied_beds_lag = lag(total_number_of_occupied_beds);
	net_change = Residents_Weekly_Admissions_COV + (total_number_of_occupied_beds - number_of_occupied_beds_lag - Residents_Weekly_Admissions_COV - Residents_Weekly_All_Deaths);
	if net_change < 0 then net_change = 0;
	if first.Federal_Provider_Number then do;
		number_of_occupied_beds_lag = .;
		net_change = 0;
		cumulative_residents_served = total_number_of_occupied_beds;
	end;
	else do;
		cumulative_residents_served = cumulative_residents_served + net_change;
	end;
run;

proc means data = NH_COVID_FAC_2020_2021_5 nonobs n nmiss min median max mean std maxdec=2;
	var cumulative_residents_served;
run;

/* Exclude records of nursing homes that report number of weekly all deaths greater than number of estimated residents served */
proc sql; 
	create table NH_COVID_FAC_2020_2021_6 as 
	select * 
	from NH_COVID_FAC_2020_2021_5
	where Federal_Provider_Number not in (
		select Federal_Provider_Number from NH_COVID_FAC_2020_2021_5
		where Residents_Total_All_Deaths > cumulative_residents_served & cumulative_residents_served ^= .); 
quit; *1,136,082;

* Check number of unique nursing homes remained in the data set;
proc sql;
	create table nh_unique as 
	select distinct Federal_Provider_Number
	from NH_COVID_FAC_2020_2021_6;
quit; *14,288;

/* Create ECP ever variables and facility-level report count */
proc sql;
	create table NH_COVID_FAC_2020_2021_7_0 as 
	select *, max(ecp_dich) as Ecp_Ever label = "Ever ECP Indicator"
	from NH_COVID_FAC_2020_2021_6
	group by provider_state
	order by Federal_Provider_Number, week_ending_date;
quit; *1,136,082;

proc sql;
	create table NH_COVID_FAC_2020_2021_7 as 
	select *,  
		   81 - count(Federal_Provider_Number) as Missing_Report_Count
	from NH_COVID_FAC_2020_2021_7_0
	group by Federal_Provider_Number
	order by Federal_Provider_Number, week_ending_date;
quit;

* Check frequency and percentage of records by missing report count;
proc freq data = NH_COVID_FAC_2020_2021_7;
	table missing_report_count;
run;

proc sql;
	create table nh_unique as 
	select distinct Federal_Provider_Number, missing_report_count
	from NH_COVID_FAC_2020_2021_7;
quit;

proc freq data = nh_unique;
	table missing_report_count;
run;

/* Create total Covid death per 1000 and total non-Covid death per 1000 using the estimated cumulative residents served */
data NH_COVID_FAC_2020_2021_8;
	set NH_COVID_FAC_2020_2021_7;
	if cumulative_residents_served = 0 then do;
		Total_Covid_Death_per_1000_e = 0;
		Total_Non_Covid_Death_per_1000_e = 0;
		Week_Covid_Death_per_1000_e = 0; 
		Week_Non_Covid_Death_per_1000_e = 0;
	end;
	else do;
		Total_Covid_Death_per_1000_E = (Residents_Total_COVID_19_Deaths / cumulative_residents_served) * 1000;
		Total_Non_Covid_Death_per_1000_E = (Total_Non_Covid_19_Deaths / cumulative_residents_served) * 1000;
	end;

	if total_number_of_occupied_beds = 0 then Total_Non_Covid_Death_per_1000 = 0;
	else Total_Non_Covid_Death_per_1000 = (Total_Non_Covid_19_Deaths / total_number_of_occupied_beds) * 1000;

	if total_number_of_occupied_beds + net_change = 0 then do;
		Week_Covid_Death_per_1000_E = 0;
		Week_Non_Covid_Death_per_1000_E = 0;
	end;
	else do;
		Week_Covid_Death_per_1000_E = (Residents_Weekly_COVID_19_Death / total_number_of_occupied_beds) * 1000;
		Week_Non_Covid_Death_per_1000_E = (Weekly_Non_Covid_19_Deaths / total_number_of_occupied_beds) * 1000;
	end;
	format ecp_ever yesno.;
run;

proc means data = NH_COVID_FAC_2020_2021_8 nonobs n min median max mean std maxdec=2;
	var Residents_Total_COVID_19_Deaths total_non_covid_19_deaths
	Total_Covid_Death_per_1000_E Total_Covid_Death_per_1000 Total_Non_Covid_Death_per_1000_E Total_Non_Covid_Death_per_1000
	Week_COVID_Death_per_1000_E Week_Non_Covid_Death_per_1000_E;
run;

/* Summary of ECP binary, ever, and categorical variables */
proc freq data = NH_COVID_FAC_2020_2021_8;
	tables (ecp_dich ecp_cat ecp_ever);
run;

/* Merge in nursing home characteristics variables from 2019 LTCFocus data set */
proc import datafile="Z:\Essential_caregiver\Data\LTCFocus\facility_2019.xlsx"
			dbms = xlsx
			out = ltcfocus_2019 replace;
run;

* Check if there is any duplicate record;
proc sort data = ltcfocus_2019 nodupkey; by prov1680; run;

proc sql;
	create table NH_COVID_FAC_2020_2021_9 as 
	select a.*, b.totbeds as totbeds_ltcf, b.hospbase as hospbase_ltcf, b.paymcaid as paymcaid_ltcf, b.paymcare as paymcare_ltcf, 
				b.profit as profit_status_ltcf, b.acuindex2 as acuindex_ltcf, b.multifac as multifac_ltcf
	from NH_COVID_FAC_2020_2021_8 as a 
	left join ltcfocus_2019 as b
	on a.Federal_Provider_Number = prov1680;
quit; *1,136,082;

data NH_COVID_FAC_2020_2021_10(drop = totbeds_ltcf paymcaid_ltcf paymcare_ltcf acuindex_ltcf);
	set NH_COVID_FAC_2020_2021_9;
	total_beds_ltcf = input(totbeds_ltcf, best12.);
	acu_index_ltcf = input(acuindex_ltcf, best12.);
	pay_medicaid_ltcf = input(paymcaid_ltcf, best12.)/100;
	pay_medicare_ltcf = input(paymcare_ltcf, best12.)/100;
	format pay_medicaid_ltcf pay_medicare_ltcf percent7.2; 
run;

/* Merge in numersing home quality measures from Nursing Home Compare data sets */
%macro nhc;
%do i = 2020 %to 2021;
	%do j = 1 %to 12;
		%if &i = 2020 AND &j <=7 %then %do;
			proc import datafile = "Z:\Essential_caregiver\Data\Nursing Home Compare\NH_ProviderInfo_&i._&j..csv"
				 dbms = csv
				 out = temp replace;
			run;

			data nhc_&i._&j(rename=(Overall_Rating_2 = Overall_Rating Quality_Rating_2 = Quality_Rating Staffing_Rating_2 = Staffing_Rating
									ADJ_AIDE_2 = ADJ_AIDE ADJ_LPN_2 = ADJ_LPN ADJ_RN_2 = ADJ_RN	ADJ_TOTAL_2 = ADJ_TOTAL));
				set temp (keep = PROVNUM COUNTY_SSA OWNERSHIP BEDCERT INHOSP Overall_Rating Quality_Rating Staffing_Rating ADJ_AIDE	
								 ADJ_LPN ADJ_RN	ADJ_TOTAL);
				Overall_Rating_2 = input(Overall_Rating, best12.);
				Quality_Rating_2 = input(Quality_Rating, best12.); 
				Staffing_Rating_2 = input(Staffing_Rating, best12.); 
				ADJ_AIDE_2 = input(ADJ_AIDE, best12.);
				ADJ_LPN_2 = input(ADJ_LPN, best12.); 
				ADJ_RN_2 = input(ADJ_RN, best12.);	
				ADJ_TOTAL_2 = input(ADJ_TOTAL, best12.);
				year_num = &i;
				month_num = &j;
				drop Overall_Rating Quality_Rating Staffing_Rating ADJ_AIDE ADJ_LPN ADJ_RN	ADJ_TOTAL;
			run;
		%end;

		%else %do;
			proc import datafile = "Z:\Essential_caregiver\Data\Nursing Home Compare\NH_ProviderInfo_&i._&j..csv"
				 dbms = csv
				 out = temp replace;
			run;

			data nhc_&i._&j(rename=(Overall_Rating_2 = Overall_Rating Staffing_Rating_2 = Staffing_Rating));
				set temp (keep = Federal_Provider_Number Provider_SSA_County_Code Ownership_Type Number_of_Certified_Beds Provider_Resides_in_Hospital Overall_Rating QM_Rating Staffing_Rating Adjusted_Nurse_Aide_Staffing_Ho	
								 Adjusted_LPN_Staffing_Hours_per Adjusted_RN_Staffing_Hours_per	Adjusted_Total_Nurse_Staffing_H);
				Overall_Rating_2 = input(Overall_Rating, best12.);
				Quality_Rating = input(QM_Rating, best12.); 
				Staffing_Rating_2 = input(Staffing_Rating, best12.); 
				ADJ_AIDE = input(Adjusted_Nurse_Aide_Staffing_Ho, best12.);
				ADJ_LPN = input(Adjusted_LPN_Staffing_Hours_per, best12.); 
				ADJ_RN = input(Adjusted_RN_Staffing_Hours_per, best12.);	
				ADJ_TOTAL = input(Adjusted_Total_Nurse_Staffing_H, best12.);
				rename Federal_Provider_Number = PROVNUM   
					   Ownership_Type = OWNERSHIP 
					   Provider_SSA_County_Code = COUNTY_SSA  
					   Number_of_Certified_Beds = BEDCERT 
					   Provider_Resides_in_Hospital = INHOSP;
				year_num = &i;
				month_num = &j;
				drop Overall_Rating QM_Rating Staffing_Rating Adjusted_Nurse_Aide_Staffing_Ho Adjusted_LPN_Staffing_Hours_per Adjusted_RN_Staffing_Hours_per Adjusted_Total_Nurse_Staffing_H;
			run;
		%end;
	%end;
%end;
%mend;

%nhc;

data nhc_combined_2020_2021;
	set nhc_2:;
	if OWNERSHIP =: "G" then OWNERSHIP_Short = "Government";
	else if OWNERSHIP =: "F" then OWNERSHIP_Short = "For profit";
	else if OWNERSHIP =: "N" then OWNERSHIP_Short = "Non profit";
run;

proc sql;
	create table NH_COVID_FAC_2020_2021_11(drop = PROVNUM year_num month_num county_ssa) as 
	select a.*, b.*
	from NH_COVID_FAC_2020_2021_10 as a 
	left join nhc_combined_2020_2021 as b
	on a.Federal_Provider_Number = b.PROVNUM and input(a.week_ending_year, best12.) = b.year_num and input(a.week_ending_month, best12.) = b.month_num;
quit; *1,136,082;

proc sort data = nhc_combined_2020_2021 out = nhc_ssa nodupkey; by PROVNUM; run;

proc sql;
	create table NH_COVID_FAC_2020_2021_12 as 
	select a.*, b.county_ssa
	from NH_COVID_FAC_2020_2021_11 as a 
	left join nhc_ssa as b
	on a.Federal_Provider_Number = b.PROVNUM ;
quit; *1,136,082;

/* Merge in county-level COVID-19 cases from NYTimes data set */
* 2020;
proc import datafile = "Z:\Essential_caregiver\Data\NYTimes\us-counties-2020.csv"
	 dbms = csv
	 out = us_counties_2020 replace;
run;

* 2021;
proc import datafile = "Z:\Essential_caregiver\Data\NYTimes\us-counties-2021.csv"
	 dbms = csv
	 out = us_counties_2021 replace;
run;

data us_counties_2020_2021;
	set us_counties_2020 us_counties_2021;
	where fips ^= .;
run;

proc sort data = us_counties_2020_2021 nodupkey; by fips date; run; *0;

data Ssa_to_fips_xwalk2018;
	set xwalk.Ssa_to_fips_xwalk2018;
	where FIPS_County_Code ^= "";
run;

proc sort data = Ssa_to_fips_xwalk2018 nodupkey; by State ssacd; run; *0;

* Merge in fips code from ssa-fips crosswalk;
proc sql;
	create table NH_COVID_FAC_2020_2021_13 as 
	select a.*, b.FIPS_County_Code
	from NH_COVID_FAC_2020_2021_12 as a 
	left join Ssa_to_fips_xwalk2018 as b
	on a.Provider_State = b.State and a.COUNTY_SSA = substr(b.ssacd,3,3);
quit; *1,136,082;

proc sql;
	create table county_week_cases_deaths as 
	select distinct a.FIPS_County_Code, a.week_ending_date, b.cases as county_cases_cumulative, b.deaths as county_deaths_cumulative
	from NH_COVID_FAC_2020_2021_13 as a 
	left join us_counties_2020_2021 as b
	on input(a.FIPS_County_Code, best12.) = b.fips and a.week_ending_date = b.date
    where FIPS_County_Code^= ""
	order by FIPS_County_Code, week_ending_date;
quit;

data county_week_cases_deaths_1;
	set county_week_cases_deaths;
	by FIPS_County_Code week_ending_date;
	county_cases_cumulative_lag = lag(county_cases_cumulative);
	county_deaths_cumulative_lag = lag(county_deaths_cumulative);
	county_cases_new = county_cases_cumulative - county_cases_cumulative_lag;
	county_deaths_new = county_deaths_cumulative - county_deaths_cumulative_lag;
	if first.FIPS_County_Code then do;
		county_cases_new = county_cases_cumulative;
		county_deaths_new = county_deaths_cumulative;
	end;
	if county_cases_new <0 and county_cases_new ^= . then county_cases_new = 0;
	if county_deaths_new < 0 and county_deaths_new ^=. then county_deaths_new = 0;
run;

proc sql;
	create table NH_COVID_FAC_2020_2021_14 as 
	select a.*, b.county_cases_cumulative, b.county_deaths_cumulative, b.county_cases_new, b.county_deaths_new
	from NH_COVID_FAC_2020_2021_13 as a 
	left join county_week_cases_deaths_1 as b
	on a.FIPS_County_Code = b.FIPS_County_Code and a.week_ending_date = b.week_ending_date;
quit; *1,136,082;

proc means data = NH_COVID_FAC_2020_2021_14 nmiss mean min max;
	var county_cases_cumulative county_deaths_cumulative county_cases_new county_deaths_new;
run;

/* Merge in county-level characteristics from American Community Survey 2018-2022 5-year Estimates data */
proc sql;
	create table NH_COVID_FAC_2020_2021_15 as 
	select a.*, b.A00001_001 as total_population, b.A01001B_010 as population_65, b.A03001_003 as population_black, b.B04001_010 as populaton_hispanic,
				b.A14006_001 as median_household_inc, b.A17005_001 as population_labor_force, b.A17005_003 as population_unemployed
	from NH_COVID_FAC_2020_2021_14 as a 
	left join census.R13145749 as b
	on a.FIPS_County_Code = b.FIPS;
quit; *1,136,082;

/* Calculate county level new cases per 1000 population */
data NH_COVID_FAC_2020_2021_16;
	set NH_COVID_FAC_2020_2021_15;
	county_cases_new_2 = county_cases_new - Residents_Weekly_Confirmed_COVI;
	county_deaths_new_2 = county_deaths_new - Residents_Weekly_COVID_19_Death;
	if county_cases_new_2 < 0 then county_cases_new_2 = 0;
	if county_deaths_new_2 < 0 then county_deaths_new_2 = 0;
	county_cases_new_1000 = (county_cases_new_2 / total_population) * 1000;
	county_deaths_new_1000 = (county_deaths_new_2 / total_population) * 1000;
	population_65_pct = population_65 / total_population;
	population_black_pct = population_black / total_population;
	population_hispanic_pct = populaton_hispanic / total_population;
	format population_65_pct population_black_pct population_hispanic_pct  percent7.2 ;
	format county_cases_new_1000 county_deaths_new_1000 8.3;
run;

/* Convert all sas variable names to lowercases */
options mprint; 
%macro lowcase(dsn); 
     %let dsid=%sysfunc(open(&dsn)); 
     %let num=%sysfunc(attrn(&dsid,nvars)); 
     %put &num;
     data &dsn; 
           set &dsn(rename=( 
        %do i = 1 %to &num; 
        /*function of varname returns the name of a SAS data set variable*/
        %let var&i=%sysfunc(varname(&dsid,&i));
        &&var&i=%sysfunc(lowcase(&&var&i)) /*rename all variables*/ 
        %end;)); 
        %let close=%sysfunc(close(&dsid)); 
  run; 
%mend lowcase; 

%lowcase(NH_COVID_FAC_2020_2021_16);

/* Reocde all string values to numeric values */
data NH_COVID_FAC_2020_2021_17(rename=(shortage_of_nursing_staffn = shortage_of_nursing_staff shortage_of_clinical_staffn=shortage_of_clinical_staff
shortage_of_aidesn=shortage_of_aides ownership_shortn=ownership_short inhospn=inhosp multifac_ltcfn=multifac_ltcf));
	set NH_COVID_FAC_2020_2021_16;
	if shortage_of_nursing_staff = "Y" then shortage_of_nursing_staffn = 1; 
	else if shortage_of_nursing_staff = "N" then  shortage_of_nursing_staffn = 0;
	if shortage_of_clinical_staff = "Y" then shortage_of_clinical_staffn = 1;
	else if shortage_of_clinical_staff = "N" then shortage_of_clinical_staffn = 0;
	if shortage_of_aides = "Y" then shortage_of_aidesn = 1;
	else if shortage_of_aides = "N" then shortage_of_aidesn = 0;
	if ownership_short = "For profit" then ownership_shortn = 1;
	else if ownership_short = "Government" then ownership_shortn = 2;
	else if ownership_short = "Non profit" then ownership_shortn = 3;
	if inhosp = "Y" then inhospn = 1;
	else if inhosp = "N" then inhospn = 0;
	if multifac_ltcf = "Yes" then multifac_ltcfn = 1;
	else if multifac_ltcf = "No" then multifac_ltcfn = 0 ;
	format ownership_shortn profit.;
	drop shortage_of_nursing_staff shortage_of_clinical_staff shortage_of_aides ownership_short inhosp multifac_ltcf;
run;

proc freq data = NH_COVID_FAC_2020_2021_17;
	tables (shortage_of_nursing_staff shortage_of_clinical_staff shortage_of_aides ownership_short inhosp multifac_ltcf);
run;

/* Save the analytical data set as a permanant data set and export it to .dta file */
data cms.NH_COVID_FAC_2020_2021;
	set NH_COVID_FAC_2020_2021_17;
	label   bedcert="Number of certified beds"
		    overall_rating="Overall rating"
	        quality_rating="Quality rating"
			staffing_rating="Staffing rating"
			adj_aide="Adjusted nurse aide staffing hours per resident per day"
			adj_lpn="Adjusted LPN staffing hours per resident per day"
			adj_rn="Adjusted RN staffing hours per resident per day"
			adj_total="Adjusted total nurse staffing hours per resident per day"
			shortage_of_clinical_staff="Shortage of clinical staff"
			shortage_of_aides="Shortage of aides"
			ownership_short="Ownership"
			inhosp="Hospital-based"
			multifac_ltcf="Chain"
			acu_index_ltcf="Acuity index"
			pay_medicaid_ltcf="Proportion of facility residents whose primary support is Medicaid"
			pay_medicare_ltcf="Proportion of facility residents whose primary support is Medicare"
			population_65_pct="Proportion of county level population of age 65 and over"
			population_black_pct="Proportion of county level population of black"
			population_hispanic_pct="Proportion of county level population of Hispanic"
			median_household_inc="Median household income of county"
			county_cases_new_1000="County-level weekly new cases per 1000 people";
run;

proc export data = cms.NH_COVID_FAC_2020_2021
			outfile = "Z:\Essential_caregiver\Data\CMS\NH_COVID_FAC_2020_2021.dta"
			dbms = dta replace;
run;








