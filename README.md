# Effects of essential caregiver policies on COVID-19 and non-COVID-19 deaths in nursing homes

The SAS and Stata codes in this repository reproduce the analytic data set and exhibits for the following paper:

Qi, M., Ghazali, N., & Konetzka, R. T. (2024). Effects of essential caregiver policies on COVID‐19 and non‐COVID‐19 deaths in nursing homes. Health Economics, 33(10), 2321-2341.

 [Link to the article](https://onlinelibrary.wiley.com/doi/full/10.1002/hec.4873)

## Input data 

* [CMS COVID-19 Nursing Home data](https://data.cms.gov/covid-19/covid-19-nursing-home-data)

* [LTCFocus 2019 data set](https://ltcfocus.org/data)

* [Nursing Home Compare 2019 and 2020 monthly data sets](https://data.cms.gov/provider-data/topics/nursing-homes)

* [NYTimes COVID-19 data](https://github.com/nytimes/covid-19-data)

* [American Community Survey 2018-2022 5-year Estimates data](https://www.socialexplorer.com/explore-tables)
  
## Steps for recreating the analytic data set

1. Download all the data sets listed in the **Input data** section.

2. Run SAS code `01_build_analytical_dataset.sas` to create an analytical data set.
   
3. Run Stata code `02_create_estimation_sample.do` to generate the estimation sample for running analyses. 

## Steps for replicating the exhibits

* Figure 1: `03_main_analyses.do`

* Figure 2: `05_trend_plots.do`

* Figure 3: `04_bacondecomp.do`

* Figure 4: `03_main_analyses.do`
  
* Table 1: `03_main_analyses.do`

* Table 2: `03_main_analyses.do`

* Table 3: `03_main_analyses.do`

* Table 4: `06_heterogeneity.do`
