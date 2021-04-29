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
# devtools::install_github(c("SantanderMetGroup/loadeR.java", "SantanderMetGroup/loadeR",
#                            "SantanderMetGroup/transformeR", "SantanderMetGroup/loadeR.ECOMS",  
#                            "SantanderMetGroup/visualizeR", "SantanderMetGroup/convertR",
#                            "SantanderMetGroup/drought4R@devel", "SantanderMetGroup/downscaleR@devel")) 

# Load packages.
options(java.parameters = "-Xmx8000m")
library(transformeR)
library(loadeR.ECOMS)
library(loadeR)
library(visualizeR)
library(convertR)
library(drought4R)
library(downscaleR)

####### GENERAL SETTINGS THAT NEED TO BE DEFINED: --------------------------------------------------

# Output path where the data will be saved (change to your local path)
dir.data <- 'C:\\Data\\Working\\WATExR\\ClimateData\\Morsa\\'
dir.Rdata <- 'C:\\Data\\Working\\WATExR\\ClimateData\\Morsa\\RData\\'

# Define the geographical domain to be loaded
latLim <- c(59.31, 59.90)
lonLim <- c(10.63, 11.25)
# Alternatively...
# Define the geographical location, a single point, in this case the interpolation using interpGrid function is not required (but will work even if applying interpGrid)
# e.g. Black sea:
# lonLim <- 32.625 
# latLim <- 43.177

# Define the coordinates and name of the lake
lake <- list(x = 10.895, y = 59.542) # roughly the middle of Morsa
lakename <- "Morsa"

# Define the dataset 
dataset <- "System4_seasonal_15" # "CFSv2_seasonal", "System4_seasonal_15", may also change to something System5-related

# Login in the TAP-UDG the climate4R libraries 
# More details about UDG in https://doi.org/10.1016/j.cliser.2017.07.001
loginUDG("WATExR", "1234567890")

# Check available variables in the dataset  
di <- dataInventory("http://www.meteo.unican.es/tds5/dodsC/system4/System4_Seasonal_15Members.ncml")
# di <- dataInventory("http://meteo.unican.es/tds5/dodsC/cfsrr/CFSv2_Seasonal.ncml")
names(di)

# Path to the observational data to use in bias correction (change to your local path)
dir.Rdata.obs <- "C:\\Data\\Working\\WATExR\\ClimateData\\Morsa\\RData\\PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_pr_tas_petH.rda"
obs.data <- get(load(dir.Rdata.obs))


# Define the variables to be loaded (the same as in the observational data, 
# except clould cover (cc) and evapotranspiration (petH))
sapply(obs.data, function(x) getVarNames(x)) # to check the variables in the observational data.

# N.B. you don't need to know the original name of the variable in the dataset as long as the dataset "label"
# is passed (e.g. "CFSv2_seasonal") to the dataset argument dataset in functionloadECOMS (or loadGridData). 
# The variable names are then given by the "Climate4R vocabulary". Print this with function C4R.vocabulary

variables <- c("pr", "tas")
# Or a larger string of variables: c("uas", "vas", "ps", "tas", "hurs", "pr", "rsds", "rlds")

# Define daily aggregation function for each variable
aggr.fun <- c("sum", "mean")

# Define the members (System4 has 15, CFSv2 has 24)
mem <- 1:15
# Define the lead month
lead.month <- 0
# Define period and season
years <- 1981:2010
season <- 6:8 # Month number (inclusive, I think? Check Mattermost for discussions on this)

########## DATA LOADING AND TRANSFORMATION ----------------------------------------------------------


# Load seasonal forecast data (System4 or CFS) with function loadECOMS
# Data is loaded in a loop (función lapply) to load all variables in a single code line.
# A list of grids is obtained, each slot in the list corresponds to a variable
data.prelim <- lapply(1:length(variables), function(x) loadECOMS(dataset, var = variables[x], years = years, 
                                                          members = mem, leadMonth = lead.month,
                                                          lonLim = lonLim, latLim = latLim, season = season, 
                                                          time = "DD", aggr.d = aggr.fun[x]))
names(data.prelim) <- variables

# Bilinear interpolation of the data to the location of the lake
data.interp <- lapply(data.prelim, function(x) interpGrid(x, new.coordinates = lake, 
                                                          method = "bilinear", 
                                                          bilin.method = "akima"))
#Convert pressure units to millibars and temperature units to celsius with function udConvertGrid from package convertR.
# data.interp$ps <- udConvertGrid(data.interp$ps, new.units = "millibars")
data.interp$tas <- udConvertGrid(data.interp$tas, new.units = "celsius")

# Collect some common metadata (e.g. from variable uas)
dates <- data.interp[[1]]$Dates
xycoords <- getCoordinates(data.interp[[1]])

# Compute cloud cover with function rad2cc from package convertR and combine variables
# clt <- rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds)
# data <- c(data.interp, "cc" = list(clt))

# Or just reassign data for use below
data = data.interp

############################################################################################
############### RUN THE FOLLOWING CODE CHUNK IF YOU NEED POTENTIAL EVAPOTRANSPIRATION ######
# Load needed variables 
tasmin <- loadECOMS(dataset, var = "tasmin", years = years, 
                    lonLim = lonLim, latLim = latLim, 
                    leadMonth = lead.month, members = mem,
                    season = season, time = "DD", aggr.d = "min")
tasmax <- loadECOMS(dataset, var = "tasmax", years = years, 
                    lonLim = lonLim, latLim = latLim, 
                    leadMonth = lead.month, members = mem,
                    season = season, time = "DD", aggr.d = "max")

# Compute potential evapotranspiration with function petGrid from package drought4R
# For daily data the implemented method is hargreaves-samani (See ?petGrid for details):
petH <- petGrid(tasmin = tasmin, 
                tasmax = tasmax,
                method = "hargreaves-samani")

# bilinear interpolation 
petH.interp <- interpGrid(petH, new.coordinates = lake, method = "bilinear", bilin.method = "akima")

# Put all variables together
data <- c(data, "petH" = list(petH.interp))
###################### END OF THE CHUNK ####################################################
############################################################################################



##### BIAS CORRECTION -----------------------------------------------------------------------
# Subset observational data to the same season as forecast data
obs.data <- lapply(obs.data, function(x) subsetGrid(x, season = season))
# Check variable consistency
if (!identical(names(obs.data), names(data))) stop("variables in obs.data and data (seasonal forecast) do not match.")

# Bias correction with leave-one-year-out ("loo") cross-validation
# type ?biasCorrection in R for more info about the parameter settings for bias correction.
data.bc.cross <- lapply(1:length(data), function(x)  {
    precip <- FALSE
    if (names(data)[x] == "pr") precip <- TRUE
    biasCorrection(y = obs.data[[x]], x = data[[x]], 
                method = "eqm", cross.val = "loo",
                precipitation = precip,
                wet.threshold = 1,
                join.members = TRUE)
  }) 
names(data.bc.cross) <- names(data)
# Bias correction without cross-validation
data.bc <- lapply(1:length(data), function(v)  {
    pre <- FALSE
    if (names(data)[v] == "pr") pre <- TRUE
    biasCorrection(y = obs.data[[v]], x = data[[v]], 
                 method = "eqm",
                 precipitation = pre,
                 wet.threshold = 1,
                 join.members = TRUE)
}) 
names(data.bc) <- names(data)  


# save Rdata (*.rda file)
save(data, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_raw.rda"))
save(data.bc.cross, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BCcross.rda"))
save(data.bc, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BC.rda"))



########## BUILD FINAL DATA AND EXPORT ACCORDING TO THE WATExR ARCHIVE DESIGN -----------------------
## SEE the proposal for the WATExR Archive Design in:                                            
## https://docs.google.com/document/d/1yzNtw9W_z_ziPQ6GrnSgD9ov5O1swnohndDTAWOgpwc/edit

# Select the object to export (can be 'data.bc', 'data.bc.cross' or 'data')
datatoexport <- data.bc

# Give format to dates
yymmdd <- as.Date(dates$start)
hhmmss <- format(as.POSIXlt(dates$start), format = "%H:%M:%S") 

# Define metadata to generate the file name
institution <- "UC"
lake_id <- lakename
ClimateModelName <- dataset
ExperimentName <- "seasonal"
freq <- "day"

# Save a single file for each member
for (i in mem) {
  # Build data.frame for a single member
  single.member <- lapply(datatoexport, function(x) subsetGrid(x, members = i))
  single.member <- lapply(single.member, function(x) x$Data)
  # Remove unwanted variables
  single.member["rsds"] <- NULL
  single.member["rlds"] <- NULL
  # data.frame creation
  df <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss)), single.member)
  if (i < 10) {
    member <- paste0("member0", i, sep = "", collapse = NULL)
  } else {
    member <- paste0("member", i, sep = "", collapse = NULL)
  }    
  startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
  endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
  dirName <- paste0(dir.data, lake_id, "/CLIMATE/", lake_id, "_", institution, "_", ClimateModelName, "_", ExperimentName, "_", member, "_", freq,"_", startTime, "-", endTime, "/", sep = "", collapse = NULL)
  dir.create(dirName, showWarnings = TRUE, recursive = TRUE, mode = "0777")
  write.table(df, paste0(dirName, "meteo_file.dat", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
}




