# Load packages. 
library(loadeR)
library(transformeR)
library(loadeR.ECOMS)
library(visualizeR)
library(convertR)
library(drought4R)
library(downscaleR)

# Parse user input
args <- commandArgs(trailingOnly=TRUE)
vargs <- strsplit(args, ",")
year <- strtoi(vargs[[1]])
years <- year:year
season <- c(vargs[[2]])
season <- as.integer(season)

# Output path where the data will be saved
dir.data <- './data_cache/s4_seasonal/' 
  
# Define the geographical domain for the Morsa catchment
latLim <- c(59.31, 59.90) 
lonLim <- c(10.63, 11.25) 

# Define the coordinates and name of the lake
lake <- list(x = 10.895, y = 59.542) # Roughly the middle of Morsa catchment
lakename <- "Morsa"

# Login in the TAP-UDG the climate4R libraries 
# More details about UDG in https://doi.org/10.1016/j.cliser.2017.07.001
loginUDG("WATExR", "1234567890")

# Define metadata to generate the file name
institution <- "NIVA"
lake_id <- lakename

options(java.parameters = "-Xmx8000m")

# Define the members
mem <- 1:15
# Define the lead month
lead.month <- 0

# Define the dataset 
dataset <- "System4_seasonal_15" # or "CFSv2_seasonal"

# Check available variables in the dataset (System4)  
di <- dataInventory("http://www.meteo.unican.es/tds5/dodsC/system4/System4_Seasonal_15Members.ncml") # or "http://meteo.unican.es/tds5/dodsC/cfsrr/CFSv2_Seasonal.ncml"
names(di)

# Path to the observational data (change to your local path).
dir.Rdata.obs <- "./data_cache/ewembi_obs/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_pr_rsds_rlds_hurs_petH.rda"
obs.data <- get(load(dir.Rdata.obs))

# Define the variables to be loaded (the same as in the observational data, 
# except clould cover (cc) and evapotranspiration (petH))
sapply(obs.data, function(x) getVarNames(x)) # to check the variables in the observational data.
variables <- c("uas", "vas", "ps", "tas", "pr", "rsds", "rlds", "hurs")

# Define daily aggregation function for each variable selected
aggr.fun <- c("mean", "mean", "mean", "mean", "sum", "mean", "mean", "mean")

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

# Convert pressure units to millibars with function udConvertGrid from package convertR.
data.interp$ps <- udConvertGrid(data.interp$ps, new.units = "millibars")

## Compute cloud cover with function rad2cc
#clt <- rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds)
#clt$Variable$varName <- "cc"
#
## Put all variables together
#data <- c(data.interp, "cc" = list(clt))
data <- data.interp

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
petH.interp$Variable$varName <- "petH"

# Put all variables together
data <- c(data, "petH" = list(petH.interp))
###################### END OF THE CHUNK ####################################################
############################################################################################
                      
# Subset all datasets to the same Dates as the hindcast precipitation. Note that we compute daily accumulated 
# precipitation, for this reason this variable has no value for the first day of every season.  
if (sum(names(data)=="pr")>0){
  data <- lapply(1:length(data), function(x)  {intersectGrid(data[[x]], data[[which(names(data)=="pr")]], type = "temporal", which.return = 1)}) 
  names(data) <- sapply(data, function(x) getVarNames(x))
  obs.data <- lapply(1:length(obs.data), function(x)  {intersectGrid(obs.data[[x]], data[[x]], type = "temporal", which.return = 1)}) 
  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x))
} else{
  obs.data <- lapply(1:length(obs.data), function(x)  {intersectGrid(obs.data[[x]], data[[x]], type = "temporal", which.return = 1)}) 
  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x))  
}

# Check variable consistency
if (!identical(names(obs.data), names(data))) stop("variables in obs.data and data (seasonal forecast) do not match.")

## Bias correction with leave-one-year-out ("loo") cross-validation
## type ?biasCorrection in R for more info about the parameter settings for bias correction.
#data.bc.cross <- lapply(1:length(data), function(x)  {
#    precip <- FALSE
#    if (names(data)[x] == "pr") precip <- TRUE
#    biasCorrection(y = obs.data[[x]], x = data[[x]], 
#                method = "eqm", cross.val = "loo",
#                precipitation = precip,
#                wet.threshold = 1,
#                join.members = TRUE)
#  }) 
#names(data.bc.cross) <- names(data)
                            
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
                            
# Select the object to export (can be 'data.bc', 'data.bc.cross' or 'data')
datatoexport <- data.bc

# Collect some common metadata (e.g. from variable uas)
dates <- datatoexport[[1]]$Dates
xycoords <- getCoordinates(datatoexport[[1]])

# Give format to dates
yymmdd <- as.Date(dates$start)
hhmmss <- format(as.POSIXlt(dates$start), format = "%H:%M:%S") 

# Define metadata to generate the file name
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