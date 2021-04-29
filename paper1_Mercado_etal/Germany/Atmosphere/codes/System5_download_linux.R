
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
dir.data <- '/home/shikhani/Documents/System_5/' 
dir.Rdata <- '/home/shikhani/Documents/System_5/'

# Define the geographical domain to be loaded
lonLim <- c(6, 8) 
latLim <- c(50, 52)
# Alternatively...
# Define the geographical location, a single point, in this case the interpolation using interpGrid function is not required (but will work even if applying interpGrid)
# e.g. Black sea:
# lonLim <- 32.625
# latLim <- 43.177

##Define the coordinates and name of the lake
lake <- list(x =7.3011, y = 51.1983)
lakename <- "Wuppertalsperre"


# Define the dataset
dataset <- "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_forecast_Seasonal_51Members_SFC.ncml"

#from sixto 

# 
# cdsNcML <- "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_Seasonal_25Members_SFC.ncml" ## TDS5 NcML
#forecast
# fctNcML <- "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_forecast_Seasonal_51Members_SFC.ncml" ## TDS5 NcML


loginUDG("WATExR", "1234567890")

# Check available variables in the dataset (System45) 
di <- dataInventory( "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_forecast_Seasonal_51Members_SFC.ncml") 
names(di)
dictionary <- "/home/shikhani/Documents/System_5/SYSTEM5_ecmwf_Seasonal_25Members_SFC.dic"

# Path to the observational data
dir.Rdata.obs <- "/home/shikhani/Documents/ERA5_requests/rdata_files/ERA5_daily_Interpolated_March2020.RData"
obs.data <- get(load(dir.Rdata.obs))
#obs.data$mx2t <- NULL
#obs.data$mer <- NULL
#obs.data$mn2t <- NULL
obs.data$sp <- NULL
names(obs.data)
#names(obs.data)<- c("uas", "vas", "tdps", "tas","petH","slp","cc",  "tp", "rsds", "rlds")
# Define the variables to be loaded (the same as in the observational data,
sapply(obs.data, function(x) getVarNames(x)) # to check the variables in the observational data.
#variables <- c("uas", "vas", "slp", "tas",  "tp", "rsds", "rlds",  "tdps")
variables <-c("uas", "vas", "tdps", "tas","tp", "rsds", "rlds")
# Define daily aggregation function for each variable selected
aggr.fun <- c("mean", "mean", "mean", "mean", "sum","mean", "mean")



# Define the members
mem <- 1:51# mem <- 1:51 #for forecast
# Define the lead month
lead.month <- 0
# Define period and season
years <- 2017:2019
#fct.years <- c(2017:2019) #for forecast
season <- c(5,6,7,8) # Winter

########## DATA LOADING AND TRANSFORMATION ----------------------------------------------------------

# Load seasonal forecast data (System5) with function loadSeasonalForecast
# Data is loaded in a loop (funci?n lapply) to load all variables in a single code line.
# A list of grids is obtained, each slot in the list corresponds to a variable
data.prelim <- lapply(1:length(variables), function(x) loadSeasonalForecast(dataset, var = variables[x], years = years,dictionary = dictionary, members = mem, leadMonth = lead.month, lonLim = lonLim, latLim = latLim, season = season,time = "DD", aggr.d = aggr.fun[x]))
names(data.prelim) <- variables
names(data.prelim) <- c("uas", "vas", "tdps", "tas","tp", "rsds", "rlds")
# Bilinear interpolation of the data to the location of the lake
data.interp <- lapply(data.prelim, function(x) interpGrid(x, new.coordinates = lake,
                                                          method = "bilinear",
                                                          bilin.method = "akima"))

# Convert pressure units to millibars with function udConvertGrid from package convertR.
#attr(data.interp$slp$Variable, "units")<- "Pa"
#data.interp$slp<- udConvertGrid(data.interp$slp, new.units = "millibars")

# Compute cloud cover with function rad2cc
clt <- rad2cc(rsds = data.interp$rsds, rlds = data.interp$rlds)
clt$Variable$varName <- "cc"

# Put all variables together
data <- c(data.interp, "cc" = list(clt))

############################################################################################
############### RUN THE FOLLOWING CODE CHUNK IF YOU NEED POTENTIAL EVAPOTRANSPIRATION ######
# Load needed variables
tasmin <- loadSeasonalForecast(dataset, var = "tas", years = years,dictionary = dictionary,
                               members = mem, leadMonth = lead.month,
                               lonLim = lonLim, latLim = latLim, season = season,  time = "DD", aggr.d = "min")

tasmax <- loadSeasonalForecast(dataset, var = "tas", years = years,dictionary = dictionary,
                               members = mem, leadMonth = lead.month,
                               lonLim = lonLim, latLim = latLim, season = season,  time = "DD", aggr.d = "max")


# Compute potential evapotranspiration with function petGrid from package drought4R
# For daily data the implemented method is hargreaves-samani (See ?petGrid for details):
petH <- petGrid(tasmin = tasmin,
                tasmax = tasmax,
                method = "hargreaves-samani")

# bilinear interpolation
petH.interp <- interpGrid(petH, new.coordinates = lake, method = "bilinear", bilin.method = "akima")
petH.interp$Variable$varName <- "petH"

# Put all variables together
data <- c(data.interp, "cc" = list(clt), "petH" = list(petH.interp))
#data <- c(data.interp$uas,data.interp$vas,data.interp$tdps,data.interp$tas , "petH" = list(petH.interp), data.interp$rlds,data.interp$rsds,data.interp$slp , "cc" = list(clt), data.interp$tp)
#data <- c("uas"=list(data.interp$uas), "cc" = list(clt), "petH" = list(petH.interp))

#data$tp$Variable$varName <- "pr"
##data <- c(data.interp, "cc" = list(clt))
#names(data)[5] <- "pr"
###################### END OF THE CHUNK ####################################################
############################################################################################

##### BIAS CORRECTION -----------------------------------------------------------------------
# Subset all datasets to the same Dates as the hindcast precipitation. Note that we compute daily accumulated
# precipitation, for this reason this variable has no value for the first day of every season. 
if (sum(names(data)=="tp")>0){
  data <- lapply(1:length(data), function(x)  {intersectGrid(data[[x]], data[[which(names(data)=="tp")]], type = "temporal", which.return = 1)})
  names(data) <- sapply(data, function(x) getVarNames(x))
  obs.data <- lapply(1:length(obs.data), function(x)  {intersectGrid(obs.data[[x]], data[[x]], type = "temporal", which.return = 1)})
  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x))
} else{
  obs.data <- lapply(1:length(obs.data), function(x)  {intersectGrid(obs.data[[x]], data[[x]], type = "temporal", which.return = 1)})
  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x)) 
}

# Check variable consistency
if (!identical(names(obs.data), names(data))) stop("variables in obs.data and data (seasonal forecast) do not match.")
###
#use the following lines in case you face an error
#namestob <- names(data)
#names(obs.data) <- c(namestob[1:4], "hurs", "tp", "rsds", "rlds", "cc", "petH")
names(obs.data) 
names(data)
#names(obs.data)  <- names(data)
names(obs.data) <- c("uas", "vas", "tdps", "tas", "cc","tp","rsds", "rlds", "petH")
data <- data[match(names(obs.data), names(data))]
varnames <- names(data)
if (!identical(names(obs.data), names(data))) stop("variables in obs.data and data (seasonal forecast) do not match.")

# Bias correction with leave-one-year-out ("loo") cross-validation
# type ?biasCorrection in R for more info about the parameter settings for bias correction.
data.bc.cross <- lapply(1:length(data), function(x)  {
  precip <- FALSE
  if (names(data)[x] == "tp") precip <- TRUE
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
  if (names(data)[v] == "tp") pre <- TRUE
  biasCorrection(y = obs.data[[v]], x = data[[v]],
                 method = "eqm",
                 precipitation = pre,
                 wet.threshold = 1,
                 join.members = TRUE)
})
names(data.bc) <- names(data) 

# save Rdata (*.rda file)
dataset <- "System5_seasonal_51" 

save(data, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_raw.rda"))
save(data.bc.cross, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BCcross.rda"))
save(data.bc, file = paste0(dir.Rdata, dataset, "_", paste0(season, collapse = "_"), "_", paste0(names(data), collapse = "_"), "_BC_.rda"))

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

# Define metadata to generate the file name
institution <- "UFZ"
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
  # single.member["rsds"] <- NULL
  # single.member["rlds"] <- NULL
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
  write.table(df, paste0(dirName, "meteo_file.dat", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = T, quote = FALSE)
}


