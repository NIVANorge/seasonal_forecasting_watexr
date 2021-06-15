# Lake Vansjø, Norway

## Introduction to the study area

The Vansjø-Hobøl catchment lies in south-eastern Norway, in one of the most agricultural catchments in Norway. High phosphorus loading to the lake occurs because of agricultural activities and the naturally phosphorus-rich clay soils in the area. As a result, the lake has suffered from numerous toxic cyanobacteria blooms over the last two decades, leading to frequent summer bathing bans. 

## Seasonal water quality and ecology forecasts for lake Vansjø

### Operational forecasts

Seasonal water quality and ecology forecasts for Lake Vansjø are produced annually in April, and can be found [here](https://watexr.data.niva.no/).

A brief description of the underlying methods and models used to generate the forecasts is given in [this guidance document](https://github.com/NIVANorge/seasonal_forecasting_watexr/blob/main/Norway_Morsa/guidance_docs/GuidanceDoc_InterpretingLakeForecast.pdf).

### Workflow, and code and data to reproduce it
Seasonal water chemistry and ecology forecasts are generated using the following workflow:

1. **Gather historic data**: Gather spot sample observations from the lake for the target and explanatory variables. In Vansjø, this was total phosphorus concentration (TP), chlorophyll-a concentration (chl-a), lake colour and cyanobacterial biovolume. Observations are required for as long a historic period as possible; at least 20 years of data are recommended. For Lake Vansjø, data were available from 1980 for all variables apart from cyanobacteria, which was available from 1996.
2. **Make a training data set:** Resample the lake data to seasonal frequency, e.g. by calculating seasonal means or, for cyanobacteria, maxima. For Lake Vansjø, only one season was relevant to forecast per year, the summer growing season (May-Oct), as this is used in Water Framework Classification. However, other season splits could be used. For Vansjø, this processing is carried out in [this notebook](https://github.com/NIVANorge/seasonal_forecasting_watexr/blob/main/Norway_Morsa/BayesianNetwork/Notebooks/04_MakeHistoricTrainingData.ipynb). The output is a csv of training data, which should be updated every year as more data become available.
3. **Fit the statistical model**: A Bayesian Belief Network (BBN) is used to produce the seasonal forecasts, using the BNLearn R package. The BBN is fit to the training data in [this notebook](https://github.com/NIVANorge/seasonal_forecasting_watexr/blob/main/Norway_Morsa/BayesianNetwork/Notebooks/05_Fit_BN.ipynb). By re-fitting the model every year, new observed data is assimilated.
4. **Evaluate model performance over the historic period**: Assess model performance by producing forecasts for every season in the historic period using cross validation methods and summarise using appropriate goodness of fit statistics. For Lake Vansjø, that is done in Notebooks 07 to 08b in [this folder](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/Norway_Morsa/BayesianNetwork/Notebooks).
5. **Produce the forecast**: Produce a forecast for the target season, driven by observations for that season, and accompany the forecast with information on the historic performance of the forecasting system derived in step 4.


## Historic seasonal forecasts of river discharge and lake temperature

In addition to the statistical approach described above, seasonal forecasts of river discharge, lake water temperature and ice cover were produced for the period 1993-2016 by driving the SimplyQ hydrology model with the GOTM lake model, driven by SEAS5 seasonal climate data. Associated code and data are in [this folder](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/Norway_Morsa/ProcessBasedModelling), and the workflow is described in more detail in papers by [Mercado et al.](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/paper1_Mercado_etal) and [Clayer et al.](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/paper2_Clayer_etal).

All the code required to download ERA5 and SEAS5 meteorological data, to downscale and bias correct SEAS5 data using ERA5 data, and to visualise the performance of SEAS5 compared to ERA5 with tercile plots and stats, are [here](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/Norway_Morsa/MetData_Processing/notebooks). See the [readme](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/Norway_Morsa/MetData_Processing/notebooks#processing-meteorological-data-for-the-morsa-catchment-case-study-norway) for more information.
