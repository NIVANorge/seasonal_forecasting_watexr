# Processing meteorological data for the Morsa catchment case study (Norway)

## Original workflow (deprecated)

 * **Notebooks 01 to 03** process old datasets (EWEMBI, ERA-Interim and System 4), which are no longer used
 
 * **[Notebook 04](https://nbviewer.jupyter.org/github/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/04_make_climate_forecast.ipynb)** is a prototype for the Morsa forecast app, which is now implemented [here](https://github.com/icra/WATExR/tree/master/Norway_Morsa/morsa_voila_app)
 
## Current workflow

### Code

These notebooks implement steps in the "common paper" protocol described [here](https://docs.google.com/document/d/17vP2NkuBOcP4I4mCHZvce92IkDJdszJDfLtEN-g9MaE/edit#) (only accessible to project members).

 * **[Notebook 05](https://nbviewer.jupyter.org/github/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/05_download_era5.ipynb)** downloads and restructures ERA5 data from the [Climate Data Service](https://cds.climate.copernicus.eu/cdsapp#!/search?type=dataset) (protocol step 1)
 
 * **[Notebook 06](https://nbviewer.jupyter.org/github/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/06_explore_era5.ipynb)** compares the ERA5 temperature and precipitation records to more detailed observational data provided by [met.no](https://www.met.no/) (protocol step 2)
 
 * **[Notebook 07](https://nbviewer.jupyter.org/github/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/07_download_s5.ipynb)** downloads and processes System 5 data from [Unican](https://web.unican.es/). This notebook calls the following R scripts:
 
   * **[07_s5_download.R](https://github.com/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/07_s5_download.R)** downloads System 5 hindcast and forecast data for use with both the GOTM and Bayesian network models (protocol step 5)
   
   * **[07_merge_hindcast_forecast.R](https://github.com/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/07_merge_hindcast_forecast.R)** combines the hindcast and forecast components into single data series (protocol step 5)
   
   * **[07_process_era5.R](https://github.com/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/07_process_era5.R)** prepares the ERA5 data for use with Climate4R and System 5 (protocol step 6)
   
   * **[07_bias_correct_s5.R](https://github.com/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/07_bias_correct_s5.R)** bias-corrects the System 5 data based on ERA5 using "leave-one-out" cross validation (protocol step 6)
 
 * **[Notebook 08](https://nbviewer.jupyter.org/github/icra/WATExR/blob/master/Norway_Morsa/MetData_Processing/notebooks/08_compare_era5_s5_bias_cor.ipynb)** performs basic checking and visualisation e.g. comparing ERA5 with "raw" and bias-corrected System 5 time series 
 
### Outputs

Time series for Lake Morsa in CSV format can be found [here](https://github.com/icra/WATExR/tree/master/Norway_Morsa/Data/Meteorological/06_era5) for ERA5 and [here](https://github.com/icra/WATExR/tree/master/Norway_Morsa/Data/Meteorological/07_s5_seasonal) for System 5.

Outputs in `.rda` format can be found [here](https://github.com/icra/WATExR/tree/master/Norway_Morsa/Data/Meteorological/RData). 

The following abbreviations are used for variable names in the output files:

    psl     Surface pressure (Pa)
    tcc     Total cloud cover (fraction between 0 and 1; dimensionless)
    uas     10 metre U wind component (m.s-1)
    vas     10 metre V wind component (m.s-1)
    tas     2 metre temperature (C)
    tdps    2 metre dewpoint temperature (C)
    rsds    Surface solar radiation downwards (W.m-2)
    rlds    Surface thermal radiation downwards (W.m-2)
    tp      Total precipitation (mm)