# R scripts to download seasonal climate data using the Climate4R package

These scripts download hindcast seasonal climate data from the University of Cantabria User Data Gateway. A username and password is required. However, scripts can be modified relatively easily to instead download from e.g. Copernicus, for operational seasonal forecasting.

## Climate scripts in R

  - **observations.R**: to load observational gridded data (e.g. EWEMBI dataset) for the entire period and to export the data in the appropriate format (for catchment and lake models)
  - **reanalysis.R**: to load reanalysis gridded data (e.g. ERA-Interim) for the warm up period, to bias correct the data and to export the data in the appropriate format (for catchment and lake models)
  - **seasonalForecast.R**: to load seasonal forecast gridded data (e.g. CFS, S4, SEAS5) for different seasons, to bias correct the data and to export the data in the appropriate format (for catchment and lake models)
  - **validation.R**: to produce tercile plots and goodness-of-fit statistics (ROCSS), with significance testing
  - **post-process.R**: to bind the reanalysis time series to the 4 months of the seasonal forecast (this binding is performed for each year in the seasonal forecast). The product is a single time series covering both historic and future periods, which can then be used to drive catchment and lake models for warm-up, initialisation and the target season in a single run.


## Alternative scripts (R wrapped in Python)

For those more comfortable working with Python, see the scripts described [here](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/Norway_Morsa/MetData_Processing/notebooks#processing-meteorological-data-for-the-morsa-catchment-case-study-norway) for inspiration. The workflow is the same, but the Climate4R functionality is wrapped within Python code within Jupyter notebooks.