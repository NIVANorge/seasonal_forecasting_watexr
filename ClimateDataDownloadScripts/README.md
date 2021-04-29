# R scripts

## Climate scripts


  - **observations.R**: to load observational gridded data (e.g. EWEMBI dataset) for the entire period and to export the data  in the appropriate format (for catchment and lake  models)
  - **reanalysis.R**: to load reanalysis gridded data (e.g. ERA-Interim) for the warm up period, to bias correct the data and to export the data  in the appropriate format (for catchment and lake  models)
  - **seasonalForecast.R**: to load seasonal forecast gridded data (e.g. CFS, S4) for different seasons, to bias correct the data and to export the data  in the appropriate format (for catchment and lake  models)
  - **validation.R**: to produce tercile plots.
  - **post-process.R**: to bind the reanalysis time series to the 4 months of the seasonal forecast (this binding is performed for each year in the seasonal forecast).
  
These scripts are tailored to follow the workflow shown in the figure below:

<img src="/figs/fig_hindcast_workflow_UNICAN.jpg" />