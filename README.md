# Introduction

As part of the WATExR project, we have developed tools for seasonal forecasting of river discharge, lake water temperature, ecology and fish phenology. The aim is for stakeholders to have access to probabilistic aquatic forecasts driven by state-of-the-art seasonal climate projections. Forecasts provide an indication of the expected average environmental conditions during the coming 1 to 9 months.

Forecasting tools were developed for five pilot case sites, one in Australia and four in Europe.

<p align="center">
  <img src="Images/LocationMap.jpg" width="400" />
</p>

# Forecasting methods

At most sites, forecasts were produced by driving freshwater models using downscaled seasonal climate model forecasts.

<p align="center">
  <img src="Images/steps.jpg" width="600" />
</p>

## Accessing seasonal climate data

We used [ECMWF's SEAS5](https://www.ecmwf.int/en/newsletter/154/meteorology/ecmwfs-new-long-range-forecasting-system-seas5) seasonal climate model forecasts. These can be accessed directly through the [Copernicus Climate Data Store](https://cds.climate.copernicus.eu/#!/home), and you will find an example script for downloading data directly from Copernicus [here](https://nbviewer.jupyter.org/github/NIVANorge/seasonal_forecasting_watexr/blob/master/Norway_Morsa/MetData_Processing/notebooks/05_download_era5.ipynb)). However, in WATExR seasonal climate data was primarily directly downloaded from the University of Cantabria server, using the R scripts in the [ClimateDataDownload](https://github.com/NIVANorge/seasonal_forecasting_watexr/tree/main/ClimateDataDownloadScripts) folder. These scripts make use of the Climate4R package. This data is only historic and was used for the development and evaluation of the forecasting tools, and therefore cannot be used for operational forecasting. A username and password are required from UniCan. Many of the functions in the scripts in this folder can however be reused for operational forecasting.

## Impact modelling

Statistical and process-based models were used to produce seasonal forecasts for variables that were relevant in the various case study sites. These included, for example, catchment hydrology, lake temperature, lake ice cover, lake water quality and ecological status, and the timing of seaware fish migration. More details are given in the papers.

# Case study sites

## Mount Bold reservoir, Southern Autralia
**The challenge**: Improve management of the largest reservoir in South Australia to reduce pumping costs and improve water quality.

**Developer and co-developer**: [Dundalk Institute of Technology](https://www.dkit.ie/), [SA Water](https://www.sawater.com.au/) and [University of Adelaide](https://www.adelaide.edu.au/)

## Burrishoole catchment, Ireland
**The challenge**: Better understanding and management of diadromous fish stocks, in particular the timing of fish migration.

**Developer and co-developer**: [Marine Institute](https://www.marine.ie/Home/home)

## Sau reservoir, Spain
**The challenge**: Improved reservoir management to reduce flooding and improve water quality for drinking water and to meet ecological targets.

**Developer and co-developer**: ICRA, [Catalan Water Agency](http://aca.gencat.cat/ca/inici)

## Lake Vansjø, Norway
**The challenge**: Manage lake water levels and farming practices in the catchment to improve water quality and achieve water quality and ecology targets, including prevention of toxic cyanobacterial blooms.

**Developer and co-developer**: Norwegian Institute for Water Research (NIVA), [Morsa](http://morsa.org/)

## Wupper reservoir, Germany
**The challenge**: Improved reservoir operations to meet requirements for flood protection, recreation and improved water quality both in the reservoir and downstream.

**Developer and co-developer**: UFZ, [WUPPERVERBAND](https://www.wupperverband.de/internet/web.nsf/id/pa_startseite.html)

# Papers
Three papers are currently published/submitted/in preparation:

* Mercado et al. (in review): Workflow description
* Clayer et al. (in prep): Exploration of the sources of skill in seasonal forecasts
* Jackson-Blake et al. (in prep): Assessment of how useful forecasts are for decision making

# Acknowledgements
This is a contribution of the WATExR project (watexr.eu/), which is part of ERA4CS, an ERA-NET initiated by JPI Climate, and funded by MINECO-AEI (ES), FORMAS (SE), BMBF (DE), EPA (IE), RCN (NO), and IFD (DK), with co-funding by the European Union (Grant 690462). MINECO-AEI funded this research through projects PCIN-2017-062 and PCIN-2017-092.
