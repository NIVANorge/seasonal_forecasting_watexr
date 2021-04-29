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
# library(loadeR.ECOMS)
# library(visualizeR)
library(convertR)
library(drought4R)

####### GENERAL SETTINGS THAT NEED TO BE DEFINED IN EACH CASE STUDY ---------------------------------

# Output path where the data will be saved (change to your local path).
dir.data <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data\\"
dir.Rdata <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/"
  
# Define the geographical domain to be loaded
#   'Mt. Bold Reservoir','Australia',[-35.15 -35.0167],[138.6667 138.8167],'6-hourly','both'};
lonLim <- c(137.5, 139.25) 
latLim <- c(-35.5, -34.25)
# Alternatively...
# Define the geographical location, a single point, in this case the interpolation using interpGrid function is not required (but will work even if applying interpGrid)
# e.g. Black sea:
# lonLim <- 32.625 
# latLim <- 43.177

# Define the period and the season
years <- 1979:2010
season <- 1:12 #Full year

# Define the coordinates and name of the lake
lake <- list(x = 138.702, y = -35.119) # black sea
lakename <- "MtBold"

# Define the dataset 
dataset <- "PIK_Obs-EWEMBI"

# Login in the TAP-UDG the climate4R libraries 
# More details about UDG in https://doi.org/10.1016/j.cliser.2017.07.001
loginUDG(username = "WATExR",password =  "1234567890")

# Check available variables in the dataset (EWEMBI)  
di <- dataInventory(dataset)
names(di)

# Define the variables to be loaded. Remove those not needed. 
variables <- c("uas", "vas", "ps", "tas", "tasmax", "tasmin", "pr", "rsds", "rlds", "hurs")

########## DATA LOADING AND TRANSFORMATION -------------------------------------------------------

# Load observations (EWEMBI) with function loadGridData from package loadeR.
# Data is loaded in a loop (function lapply) to load all variables in a single code line.
# A list of grids is obtained, each slot in the list corresponds to a variable
data.prelim <- lapply(variables, function(x) loadGridData(dataset, var = x, years = years, 
                                                   lonLim = lonLim, latLim = latLim, 
                                                   season = season))
names(data.prelim) <- variables

# Bilinear interpolation of the data to the location of the lake. See ?interpGrid for other methods.
data.interp <- lapply(data.prelim, function(x) interpGrid(x, new.coordinates = lake, 
                                                   method = "bilinear", 
                                                   bilin.method = "akima"))

#Convert pressure units to millibars with function udConvertGrid from package convertR.
# data.interp$ps <- udConvertGrid(data.interp$ps, new.units = "millibars")

# Collect some common metadata (e.g. from variable uas)
dates <- data.interp[[1]]$Dates
xycoords <- getCoordinates(data.interp[[1]])

# Compute cloud cover with function rad2cc from package convertR
clt <- rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds)
clt$Variable$varName <- "cc"
attr(clt$Variable, 'units') <- 'frac'

# Put all variables together
data <- c(data.interp, "cc" = list(clt))


############################################################################################
############### RUN THE FOLLOWING CODE CHUNK IF YOU NEED POTENTIAL EVAPOTRANSPIRATION ######
# Load needed variables 
tasmin <- loadGridData(dataset, var = "tasmin", years = years, 
                       lonLim = lonLim, latLim = latLim, 
                       season = season,  time = "DD", aggr.d = "min")
tasmax <- loadGridData(dataset, var = "tasmax", years = years, 
                       lonLim = lonLim, latLim = latLim, 
                       season = season,  time = "DD", aggr.d = "max")

# Compute potential evapotranspiration with function petGrid from package drought4R
# For daily data the implemented method is hargreaves-samani (See ?petGrid for details):
petH <- petGrid(tasmin = data.prelim$tasmin, 
                tasmax = data.prelim$tasmax,
                method = "hargreaves-samani")

# bilinear interpolation 
petH.interp <- interpGrid(petH, new.coordinates = lake, method = "bilinear", bilin.method = "akima")
petH.interp$Variable$varName <- "petH"

# Put all variables together
data <- c(data.interp, "cc" = list(clt), "petH" = list(petH.interp))
###################### END OF THE CHUNK ####################################################
############################################################################################

# save Rdata for posterior bias correction of seasonal forecasts
save(data, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), ".rda"))

########## BUILD FINAL DATA --------------------------------------------------------------

# extract the data arrays of all variables from the list
data_sub <- lapply(data, function(x) x[["Data"]])
units <- lapply(data, function(x) attributes(x$Variable)$units)
cnams <- paste0(names(data),'_', units)
# Remove unwanted variables from output
# data["rsds"] <- NULL 
# data["rlds"] <- NULL
# Build data frame
yymmdd <- as.Date(dates$start)
hhmmss <- format(as.POSIXlt(dates$start), format = "%H:%M:%S")
datetime = paste(yymmdd, hhmmss)
df <- data.frame(c(list("DateTime" = datetime)), data_sub)
colnames(df) <- c("DateTime", cnams)


########### EXPORT DATA ACCORDING TO THE WATExR ARCHIVE DESIGN -----------------------------
## SEE the proposal for the WATExR Archive Design in:                                            
## https://docs.google.com/document/d/1yzNtw9W_z_ziPQ6GrnSgD9ov5O1swnohndDTAWOgpwc/edit

# Define metadata to generate the file name
institution <- "DkIT"
lake_id <- lakename
ClimateModelName <- "EWEMBI"
ExperimentName <- "observations"
member <- "member01"
freq <- "day"

# Create directory and save file
startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
dirName <- paste0(dir.data, lake_id, "/CLIMATE/", lake_id, "_", institution, "_", ClimateModelName, "_", ExperimentName, "_", member, "_", freq, "_", startTime, "-", endTime, "/", sep = "", collapse = NULL)
dir.create(dirName, showWarnings = TRUE, recursive = TRUE, mode = "0777")
write.table(df, paste0(dirName,"meteo_file.dat", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)




