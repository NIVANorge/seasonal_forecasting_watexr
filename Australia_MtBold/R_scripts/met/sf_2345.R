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
dir.data <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data\\"
dir.Rdata <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/"

# Define the geographical domain to be loaded
lonLim <- c(137.5, 139.25) 
latLim <- c(-35.5, -34.25)

# Define the coordinates and name of the lake
lake <- list(x = 138.702, y = -35.119) # black sea
lakename <- "MtBold"

# Define the dataset 
dataset <- "System4_seasonal_15" # or "CFSv2_seasonal"

# Login in the TAP-UDG the climate4R libraries 
# More details about UDG in https://doi.org/10.1016/j.cliser.2017.07.001
loginUDG(username = "WATExR",password =  "1234567890")

# Check available variables in the dataset (System4)  
di <- dataInventory("http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_Seasonal_25Members_SFC.ncml") # or "http://meteo.unican.es/tds5/dodsC/cfsrr/CFSv2_Seasonal.ncml"
names(di)

# Path to the observational data (change to your local path).
dir.Rdata.obs <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_tasmax_tasmin_pr_rsds_rlds_hurs_cc_petH.rda"
obs.data <- get(load(dir.Rdata.obs))

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

# Define the variables to be loaded (the same as in the observational data, 
# except clould cover (cc) and evapotranspiration (petH))
sapply(obs.data, function(x) getVarNames(x)) # to check the variables in the observational data.
variables <- c("uas", "vas", "ps", "tas", "pr", "rsds", "rlds", "hurs")

# Define daily aggregation function for each variable selected
aggr.fun <- c("mean", "mean", "mean", "mean", "sum", "mean", "mean", "mean")

# Define the members
mem <- 1:15
# Define the lead month
lead.month <- 0
# Define period and season
years <- 1979:2016
season <- c(2:5) # Spring

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

# Convert pressure units to millibars with function udConvertGrid from package convertR.
data.interp$ps <- udConvertGrid(data.interp$ps, new.units = "millibars")

# Compute cloud cover with function rad2cc
clt <- rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds)
clt$Variable$varName <- "cc"

# Put all variables together
data <- c(data.interp, "cc" = list(clt))

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

#Create wind speed
# Compute wss
wss <- data.interp$uas
wss$Data <- sqrt(data.interp$uas$Data^2 + data.interp$vas$Data^2)
# Define correctly the metadata of the object:
wss$Variable$varName <- "wss"
attr(wss$Variable,"units") <- "m s**-1"
attr(wss$Variable,"description") <- "Near-Surface Wind Speed"
attr(wss$Variable,"longname") <- "wss"
# Include variables in data.prelim


# Put all variables together
data <- c(data.interp, "cc" = list(clt), "petH" = list(petH.interp), "wss" = list(wss), "tasmin" = list(tasmin), "tasmax" = list(tasmax))
# save Rdata (*.rda file)
save(data, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_raw.rda"))
###################### END OF THE CHUNK ####################################################
############################################################################################

##### BIAS CORRECTION -----------------------------------------------------------------------

# Check variable consistency
if (!all(names(obs.data) %in% names(data))){
  message("variables in obs.data and data (seasonal forecast) do not match.")
  print(names(obs.data)[which(!(names(obs.data) %in% names(data)))])
}
obs.data[['tasmin']] <- NULL
obs.data[['tasmax']] <- NULL
data <- data[match(names(obs.data), names(data))]
names(data)
names(obs.data)

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
# save(data, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_raw.rda"))
save(data.bc.cross, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BCcross.rda"))
save(data.bc, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BC.rda"))

########## BUILD FINAL DATA AND EXPORT ACCORDING TO THE WATExR ARCHIVE DESIGN -----------------------
## SEE the proposal for the WATExR Archive Design in:                                            
## https://docs.google.com/document/d/1yzNtw9W_z_ziPQ6GrnSgD9ov5O1swnohndDTAWOgpwc/edit

# Select the object to export (can be 'data.bc', 'data.bc.cross' or 'data')
datatoexport <- data.bc

# Collect some common metadata (e.g. from variable uas)
dates <- datatoexport[[1]]$Dates
xycoords <- getCoordinates(datatoexport[[1]])

# Give format to dates
yymmdd <- as.Date(dates$start)
hhmmss <- format(as.POSIXlt(dates$start), format = "%H:%M:%S") 
datetime = paste(yymmdd, hhmmss)
# Define metadata to generate the file name
institution <- "DkIT"
lake_id <- lakename
ClimateModelName <- dataset
ExperimentName <- "seasonal"
freq <- "day"

# Save a single file for each member
for (i in mem) {
  # Build data.frame for a single member
  single.member <- lapply(datatoexport, function(x) subsetGrid(x, members = i))
  units <- lapply(data, function(x) attributes(x$Variable)$units)
  units$cc <- 'frac'
  cnams <- paste0(names(data),'_', units)
  single.member <- lapply(single.member, function(x) x$Data)
  # data.frame creation
  # df <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss)), single.member)
  df <- data.frame(c(list("DateTime" = datetime)), single.member)
  colnames(df) <- c("DateTime",cnams)
  if (i < 10) {
    member <- paste0("member0", i, sep = "", collapse = NULL)
  } else {
    member <- paste0("member", i, sep = "", collapse = NULL)
  }    
  startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
  endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
  dirName <- paste0(dir.data, lake_id, "/CLIMATE/", lake_id, "_", institution, "_", ClimateModelName, "_", ExperimentName, "_", member, "_", freq,"_", startTime, "-", endTime, "/", sep = "", collapse = NULL)
  dir.create(dirName, showWarnings = TRUE, recursive = TRUE, mode = "0777")
  write.table(df, paste0(dirName, "meteo_file.dat", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = T, quote = FALSE)
}




