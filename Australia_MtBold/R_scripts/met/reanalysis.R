#
# Case Study:
# caseStudy={'Lake Arreskov','Denmark',55.16,10.31,'sub-daily','both';...
#   'Wupper Reservoir','Germany',51.1983,7.3011,'hourly or daily','both';...
#   'Burrishoole Catchment','Ireland',[53.8833 54.05],[-9.6833 -9.4833],'Daily','both';...
#   'Vansjo Catchment','Norway',[59.31 59.90],[10.63 11.25],'Daily','both';...
#   'Sau Reservoir','Spain',41.9702,2.3994,'Daily or sub-daily','both';...
#   'Mt. Bold Reservoir','Australia',[-35.15 -35.0167],[138.6667 138.8167],'6-hourly','both'};
####################################################################################################
## Example of Data Reference Sintax: How to build the directory structure and file naming         ##
## considering observations, reanalysis, seasonal forecast or climate change projections          ##
## SEE the proposal for the WATExR Archive Design in:                                             ## 
## https://docs.google.com/document/d/1yzNtw9W_z_ziPQ6GrnSgD9ov5O1swnohndDTAWOgpwc/edit           ##
####################################################################################################
#   Lake (lake_id): Is an identifier for the lake/case study.
#   institution (institute_id): Is an identifier for the institution that is responsible for the scientific aspects of the simulation.
#   LakeModelName (driving_lake_model_id): is an identifier of the driving lake model.
#     The name consists of an institute identifier and a lake model identifier. 
#     The two parts of the name are separated by a '-' (dash). Note that dashes in either of the two parts are allowed. 
#   ClimateModelName (driving_climate_model_id) is an identifier of the driving climate model.
#     The name consists of an institute identifier and a climate model identifier. 
#     The two parts of the name are separated by a '-' (dash). Note that dashes in either of the two parts are allowed.
#     For observations or reanalysis indicate the name of the data set as model identifier. 
#   ExperimentName (driving_experiment_name) is:
# Climate change projection: either "evaluation" or the value of the CMIP5 experiment_id of the data used ("historical", "rcp4.5", "rcp8.5", etc)
# Seasonal Forecasts: "seasonal"
# Observed data: "observations"
# Reanalysis: "reanalysis"
#   EnsembleMember (driving_model_ensemble_member) identifies the ensemble member of the global climate model, seasonal or climate change, experiment that produced the forcing data.
# Climate change: the format should be the same used in the CMIP5 (e.g. r1i1p1)
# Seasonal Forecasts: this element is defined by the member (e.g. member01 for the first member).
# Reanalysis: Set this element as member01 for reanalysis data.
#   Frequency (frequency) is the output frequency indicator: 6hr=6 hourly, day=daily, etc.
#   StartTime and EndTime indicate the time span of the file content. The format is YYYY[MM[DD[HH[MM]]]], i.e. the year is represented by 4 digits, 
# while the month, day, hour, and minutes are represented by exactly 2 digits, if they are present at all. In accordance with CMIP5, only those 
# digits have to be included that are necessary to indicate the file content. The two dates are separated by a dash. All time stamps refer to UTC.2.2 
##################################################################################################################################################################

# Install required packages. RUN JUST THE FIRST TIME.
# devtools::install_github(c("SantanderMetGroup/loadeR.java", "SantanderMetGroup/loadeR@devel",
#                            "SantanderMetGroup/transformeR", "SantanderMetGroup/loadeR.ECOMS",  
#                            "SantanderMetGroup/visualizeR", "SantanderMetGroup/convertR",
#                            "SantanderMetGroup/drought4R@devel", "SantanderMetGroup/downscaleR@devel")) 

# Load packages. 
library(loadeR)
library(transformeR)
library(loadeR.ECOMS)
library(visualizeR)
library(convertR)
library(drought4R)#
library(downscaleR)

####### GENERAL SETTINGS THAT NEED TO BE DEFINED IN EACH CASE STUDY ---------------------------------

# Output path where the data will be saved (change to your local path).
dir.data <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data\\"
dir.Rdata <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/"

# Define the geographical domain to be loaded
lonLim <- c(137.5, 139.25) 
latLim <- c(-35.5, -34.25)
# Alternatively...
# Define the geographical location, a single point, in this case the interpolation using interpGrid function is not required (but will work even if applying interpGrid)
# e.g. Black sea:
# lonLim <- 32.625 
# latLim <- 43.177

# Define the period and the season. If required for the warm up of the lake model, data from 1979 can be loaded. 
years <- 1979:2016
season <- 1:12 #Full year

# Define the coordinates and name of the lake
lake <- list(x = 138.702, y = -35.119) # black sea
lakename <- "MtBold"

# Define the dataset 
## dataset <- "ECMWF_ERA-Interim-ESD"
dataset <- "http://meteo.unican.es/tds5/dodsC/interim/interim075_WATExR.ncml"
# dataset <- "http://meteo.unican.es/tds7/ncss/interim/interim075.ncml"

# Login in the TAP-UDG the climate4R libraries 
# More details about UDG in https://doi.org/10.1016/j.cliser.2017.07.001
loginUDG(username = "WATExR",password =  "1234567890")

# Check available variables in the dataset (EWEMBI)  
di <- dataInventory(dataset)
names(di)

# Path to the observational data (change to your local path).
dir.Rdata.obs <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/"

obs.data <- get(load(dir.Rdata.obs))


# Define the variables to be loaded (the same as in the observational data, 
# except clould cover (cc) and evapotranspiration (petH))
varnames.obs <- sapply(obs.data, function(x) getVarNames(x)) # to check the variables in the observational data.
varnames.obs

# Define the variables to be loaded. Remove those not needed.
variables <- c("uas", "vas", "ps", "tas", "pr", "rsds", "rlds")
# variables <- c("uas", "vas", "ps", "tas", "tasmax", "tasmin", "pr", "rsds", "rlds", "hurs")
# Define daily aggregation function for each variable selected. 
aggr.fun <- c("mean", "mean", "mean", "mean", "sum", "mean", "mean")

########## DATA LOADING AND TRANSFORMATION ----------------------------------------------------------
# Load reanalysis (ERA-Interim) with function loadGridData from package loadeR.
# Data is loaded in a loop (function lapply) to load all variables in a single code line.
# A list of grids is obtained, each slot in the list corresponds to a variable
data.prelim <- lapply(1:length(variables), function(x) loadGridData(dataset, var = variables[x], years = years, 
                                                                    lonLim = lonLim, latLim = latLim, season = season, 
                                                                    time = "DD", aggr.d = aggr.fun[x]))

# Deal with the special case of accumulated variables (get temporal intersection)
data.prelim <- intersectGrid(data.prelim, type = "temporal", which.return = 1:length(variables))
names(data.prelim) <- c("uas", "vas", "ps", "tas", "pr", "rsds", "rlds")

# Compute relative humidity from the mean temperature and the dew point with function tdps2hurs from package convertR
tdps <- loadGridData(dataset, var = "tdps", years = years, 
                     lonLim = lonLim, latLim = latLim, 
                     season = season,  time = "DD", aggr.d = "mean")
tdps <- intersectGrid(tdps, data.prelim$tas, which.return = 1)
tasmax <- loadGridData(dataset, var = "tas", years = years, 
                     lonLim = lonLim, latLim = latLim, 
                     season = season,  time = "DD", aggr.d = "max")
tasmax <- intersectGrid(tdps, data.prelim$tas, which.return = 1)
tasmin <- loadGridData(dataset, var = "tas", years = years, 
                       lonLim = lonLim, latLim = latLim, 
                       season = season,  time = "DD", aggr.d = "min")
tasmin <- intersectGrid(tdps, data.prelim$tas, which.return = 1)

hurs <- data.prelim$tas # Predefine the object
hurs$Data <- tdps2hurs(data.prelim$tas$Data, tdps$Data) # Assign the data matrix
# Define correctly the metadata of the object:
hurs$Variable$varName <- "hurs"
attr(hurs$Variable,"units") <- "%"
attr(hurs$Variable,"description") <- "2 metre relative humidity"
attr(hurs$Variable,"longname") <- "hurs"
# Include variables in data.prelim
data.prelim <- c(data.prelim, "hurs" = list(hurs))

# Compute wss
wss <- data.prelim$uas
wss$Data <- data.prelim$uas$Data^2 + data.prelim$vas$Data^2
# Define correctly the metadata of the object:
wss$Variable$varName <- "wss"
attr(wss$Variable,"units") <- "m s**-1"
attr(wss$Variable,"description") <- "Near-Surface Wind Speed"
attr(wss$Variable,"longname") <- "wss"
# Include variables in data.prelim
data.prelim <- c(data.prelim, "wss" = list(wss))
data.prelim <- c(data.prelim, "tasmax" = list(tasmax), "tasmin" = list(tasmin))

# Bilinear interpolation of the data to the location of the lake. See ?interpGrid for other methods.
data.interp <- lapply(data.prelim, function(x) interpGrid(x, new.coordinates = lake, 
                                                          method = "bilinear", 
                                                          bilin.method = "akima"))

# Convert pressure and temperature units to millibars and celsius with function udConvertGrid from package convertR.
data.interp$ps <- udConvertGrid(data.interp$ps, new.units = "millibars") #No need SWAT
data.interp$tas <- udConvertGrid(data.interp$tas, new.units = "celsius")
data.interp$tasmax <- udConvertGrid(data.interp$tasmax, new.units = "celsius")
data.interp$tasmin <- udConvertGrid(data.interp$tasmin, new.units = "celsius")

# Convert radiation units from J/m2/12hours to W/m2
data.interp$rsds$Data <- data.interp$rsds$Data/43200 
attr(data.interp$rsds$Variable,"units") <- "W.m-2"
data.interp$rlds$Data <- data.interp$rlds$Data/43200 
attr(data.interp$rlds$Variable,"units") <- "W.m-2"

#Convert relative humidity units to fractions with function udConvertGrid from package convertR.
data.interp$hurs <- udConvertGrid(data.interp$hurs, new.units = "")

#Convert shortwave radiation units to MJ/(m2*day) with function udConvertGrid from package convertR.
data.interp$rsds <- udConvertGrid(data.interp$rsds, new.units = "MJ m-2 day-1")
data.interp$rlds <- udConvertGrid(data.interp$rlds, new.units = "MJ m-2 day-1")

# Compute cloud cover with function rad2cc
clt <- redim(rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds), drop = TRUE)
clt$Variable$varName <- "cc"

# Put all variables together
data <- c(data.interp, "cc" = list(clt))

############################################################################################
############### RUN THE FOLLOWING CODE CHUNK IF YOU NEED POTENTIAL EVAPOTRANSPIRATION ######
# Load needed variables 
# tasmin <- loadGridData(dataset, var = "tas", years = years, 
#                        lonLim = lonLim, latLim = latLim, 
#                        season = season,  time = "DD", aggr.d = "min")
# tasmax <- loadGridData(dataset, var = "tas", years = years, 
#                        lonLim = lonLim, latLim = latLim, 
#                        season = season,  time = "DD", aggr.d = "max")
# Compute potential evapotranspiration with function petGrid from package drought4R
# For daily data the implemented method is hargreaves-samani (See ?petGrid for details)
# petGrid function requires temperature in celsius. Convert temperature units to celsius.
data.prelim$tasmax <- udConvertGrid(data.prelim$tasmax, new.units = "celsius")
data.prelim$tasmin <- udConvertGrid(data.prelim$tasmin, new.units = "celsius")
petH <- petGrid(tasmin = data.prelim$tasmin, 
                tasmax = data.prelim$tasmax,
                method = "hargreaves-samani")

# bilinear interpolation 
petH.interp <- interpGrid(petH, new.coordinates = lake, method = "bilinear", bilin.method = "akima")
petH.interp$Variable$varName <- "petH"

# Put all variables together
data <- c(data.interp, "cc" = list(clt))#, "petH" = list(petH.interp))
###################### END OF THE CHUNK ####################################################
############################################################################################


# Check variable consistency
if (!all(names(obs.data) %in% names(data))) stop("variables in obs.data and data (seasonal forecast) do not match.")

#order variables
obs.data[['petH']] <- NULL
data <- data[match(names(obs.data), names(data))]
varnames <- names(data)

#Create wind speed
# Compute wss
wss <- obs.data$uas
wss$Data <- sqrt(obs.data$uas$Data^2 + obs.data$vas$Data^2)
# Define correctly the metadata of the object:
wss$Variable$varName <- "wss"
attr(wss$Variable,"units") <- "m s**-1"
attr(wss$Variable,"description") <- "Near-Surface Wind Speed"
attr(wss$Variable,"longname") <- "wss"
# Include variables in data.prelim
obs.data <- c(obs.data, "wss" = list(wss))

##### BIAS CORRECTION -----------------------------------------------------------------------
# Subset observational data to the same dates as forecast data
obs.data <- lapply(1:length(obs.data), function(x)  {intersectGrid(obs.data[[x]], data[[x]], type = "temporal", which.return = 1)})
data <- lapply(1:length(obs.data), function(x)  {intersectGrid(obs.data[[x]], data[[x]], type = "temporal", which.return = 2)})
names(obs.data) <- varnames
names(data) <- varnames

# Collect some common metadata (e.g. from variable uas)
dates <- data[[1]]$Dates
xycoords <- getCoordinates(data[[1]])

# Bias correction with leave-one-year-out ("loo") cross-validation
# type ?biasCorrection in R for more info about the parameter settings for bias correction.
data.bc.cross <- lapply(1:length(data), function(x)  {
  precip <- FALSE
  if (names(data)[x] == "pr") precip <- TRUE
  biasCorrection(y = obs.data[[x]], x = data[[x]], 
                 method = "eqm", cross.val = "loo",
                 precipitation = precip,
                 wet.threshold = 1,
                 window = c(90, 31),
                 join.members = TRUE)
}) 
names(data.bc.cross) <- varnames
# Bias correction without cross-validation
data.bc <- lapply(1:length(data), function(v)  {
  pre <- FALSE
  print(names(data)[v])
  if (names(data)[v] == "pr") pre <- TRUE
  biasCorrection(y = obs.data[[v]], x = data[[v]], 
                 method = "eqm",
                 precipitation = pre,
                 wet.threshold = 1,
                 window = c(90, 31),
                 join.members = TRUE)
}) 
names(data.bc) <- varnames


# save Rdata (*.rda file)
save(data, file = paste0(dir.Rdata, "interim075_WATExR_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_raw.rda"))
save(data.bc.cross, file = paste0(dir.Rdata, "interim075_WATExR_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BCcross.rda"))
save(data.bc, file = paste0(dir.Rdata, "interim075_WATExR_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BC.rda"))






########## BUILD FINAL DATA --------------------------------------------------------------

datatoexport <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/interim075_WATExR_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_tasmax_tasmin_pr_rsds_rlds_hurs_cc_wss_BC.rda"))

# extract the data arrays of all variables from the list
data_sub <- lapply(datatoexport, function(x) x[["Data"]])
units <- lapply(datatoexport, function(x) attributes(x$Variable)$units)
units$cc <- 'frac'
cnams <- paste0(names(datatoexport),'_', units)
dates <- datatoexport[[1]]$Dates

# Remove unwanted variables from output
# data["rsds"] <- NULL 
# data["rlds"] <- NULL
# Build data frame
yymmdd <- as.Date(dates$start)
hhmmss <- format(as.POSIXlt(dates$start), format = "%H:%M:%S")
datetime = paste(yymmdd, hhmmss)
df <- data.frame(c(list("DateTime" = datetime)), data_sub)
colnames(df) <- c("DateTime", cnams)
df$ps_Pa <- df$ps_millibars*100


########### EXPORT DATA ACCORDING TO THE WATExR ARCHIVE DESIGN -----------------------------
## SEE the proposal for the WATExR Archive Design in:                                            
## https://docs.google.com/document/d/1yzNtw9W_z_ziPQ6GrnSgD9ov5O1swnohndDTAWOgpwc/edit

# Define metadata to generate the file name
institution <- "DkIT"
lake_id <- lakename
ClimateModelName <- "ERA-Interim"
ExperimentName <- "reanalysis"
member <- "member01"
freq <- "day"

# Create directory and save file
startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
dirName <- paste0(dir.data, lake_id, "/CLIMATE/", lake_id, "_", institution, "_", ClimateModelName, "_", ExperimentName, "_", member, "_", freq, "_", startTime, "-", endTime, "/", sep = "", collapse = NULL)
dir.create(dirName, showWarnings = TRUE, recursive = TRUE, mode = "0777")
write.table(df, paste0(dirName,"meteo_file.dat", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
write.table(df, 'mt_bold_ewembi.dat', row.names = F, quote = F, sep = '\t')
