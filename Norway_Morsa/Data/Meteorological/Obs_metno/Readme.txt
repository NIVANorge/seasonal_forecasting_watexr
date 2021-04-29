
______________________________
Rainfall and temperature data:

From the met.no 1x1km gridded data.

v1: downloaded winter 2018. Used in original model calibrations. Has a mistake in the temperature data (unit conversion wrong). SHOULD NOT BE USED.

v2:

Interpolated from the nordic climatic gridded data set on 12/12/2019 (version 19_09: https://thredds.met.no/thredds/catalog/ngcd/version_19.09/TG/type2/catalog.html). Dataset was generated using Bayesian spatial interpolation methods and scale-separation concepts (Type_2 dataset).
The data was averaged over the Vansjø basin.

Data are averaged at 1800 so that means it might not be representative of the 24H day, especially if most of the rain falls after 1800.

Data downloadeed (a) for the whole catchment, and (b) just for grid squares associated with Storefjorden and Vanemfjorden. The lake is on average 0.8 degC warmer than the catchment.

NOTE: the temperature time series differs from the downloaded data used prior to Dec 2019, and used in the original SimplyQ, GOTM and BBN calibrations. The new data is on average about 1degC warmer. JLG thinks there was originally an error in his conversion from K to degC, so the new data should be taken as definitive. There are also very small differences in the rainfall data, but these are insignificant.
______________________________

Wind data:
Daily mean wind data from Rygge station (at the southern end of the catchment). Station code SN17150.
Variable: mean(wind_speed P1D)