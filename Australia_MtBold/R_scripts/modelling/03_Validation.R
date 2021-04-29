# Install required packages. RUN JUST THE FIRST TIME.
#install.packages("Cairo")
#devtools::install_github("SantanderMetGroup/transformeR")
#devtools::install_github("SantanderMetGroup/loadeR.ECOMS")
#devtools::install_github("SantanderMetGroup/visualizeR")

# Load packages. 
library(transformeR)
library(visualizeR)
library(Cairo)
library(abind)

####### GENERAL SETTINGS THAT NEED TO BE DEFINED IN EACH CASE STUDY ------------------


# Output path where the generated validation plots will be saved
dir.validation <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\val_plots\\model/"
# Path where the Rdata was saved. Change to your local path)
dir.Rdata <- 'C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata\\'

# Observational and seasonal forecasting datasets
obs.dataset <- "PIK_Obs-EWEMBI"
forecast.dataset <- "System4_seasonal_15"


###### LOAD R-DATA TO THE R ENVIRONMENT -----------------------------------------------
# Define the variables to be loaded
variables <- c("ech_q", "onk_q", "surftemp", "bottemp")
# Or a larger string of variables: c("uas", "vas", "ps", "tas", "hurs", "rsds", "rlds", "cc")  

# Find Rdara according to a name pattern and load with the appropriate path of those printed in the console
list.files(dir.Rdata, pattern = paste0(obs.dataset, "_.*", paste0(variables, collapse = "_")), full.names = TRUE)
obs.data <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata\\EWEMBI_GR4J_GOTM_1_2_3_4_5_6_7_8_9_10_11_12_ech_q_onk_q_surftemp_bottemp.rda"))

# Example
exa <- obs.data$ech_q
meta <- list('station_id' = 'Ech', 'name' = 'Ech', 'altitude' = 240, 'source' = 'UDG')
exa = c(exa, list('Metadata' = meta))


loadeR.2nc::stations2nc(exa, NetCDFOutFile = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data/output/obs.nc4", )

grid2nc_tm(obs.data, NetCDFOutFile = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data/output/obs_grid.nc4")
grid2nc_tm(obs.data$ech_q, NetCDFOutFile = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data/output/obs_ech.nc4")


# Repeat the operation for forecast data
list.files(dir.Rdata, pattern = paste0(forecast.dataset, "_.*", paste0(variables, collapse = "_")), full.names = TRUE)
forecast.data <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata\\System4_GR4J_GOTM_2_3_4_5_ech_q_onk_q_surftemp_bottemp.rda")) 
forecast.data <- lapply(forecast.data, function(x) subsetGrid(x, season = getSeason(x)[-1]))

grid2nc_tm(forecast.data, NetCDFOutFile = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data/output/fcast.nc4")
fc <- loadGridData("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data/output/fcast.nc4", var = 'surftemp')

###### TRANSFORMATION -----------------------------------------------------------------------
# Select variables for validation
# e.g.
val.variables <- c("ech_q", "onk_q", "surftemp", "bottemp")
# Retain required variables
ind <- abind(lapply(val.variables, function(x) which(names(obs.data) == x)))
obs <- obs.data[ind]
ind <- abind(lapply(val.variables, function(x) which(names(forecast.data) == x)))
hind <- forecast.data[ind]

if (!identical(names(obs), names(hind))) stop("there is one or more variables missing in the observations and/or forecast data.")

# Subset season in obs # works for spirng-summer-autumn
season <- getSeason(hind[[1]])
obs.sub <- lapply(1:length(obs), function(x) {intersectGrid(obs[[x]], hind[[x]], type = "temporal", which.return = 1)})
hind <- lapply(1:length(obs), function(x) {intersectGrid(obs[[x]], hind[[x]], type = "temporal", which.return = 2)})

names(obs.sub) <- sapply(obs.sub, function(x) getVarNames(x))
names(hind) <- sapply(hind, function(x) getVarNames(x))

temporalPlot(obs.sub$ech_q, hind$ech_q)


 
########## VALIDATION ------------------------------------------------------------------------------------

# Define metadata to generate the file name
institution <- "DkIT"
lake_id <- "MtBold"
ClimateModelName <- forecast.dataset
ExperimentName <- "GR4J_GOTM_seasonal"
freq <- "day"
startTime <- format(as.POSIXlt(hind[[1]]$Dates$start[1]), format = "%Y%m%d")
endTime <- format(as.POSIXlt(hind[[1]]$Dates$end[length(hind[[1]]$Dates$end)]), format = "%Y%m%d")

# Create and save tercile plots
filename <- paste0(dir.validation, '/', lake_id, "_", institution, "_", ClimateModelName, "_", ExperimentName, "_", paste0(season, collapse = "_"), "_", freq,"_", startTime, "-", endTime, "_", paste(val.variables, collapse = "_"),"_", ".pdf")
CairoPDF(file = filename, width = 10)
for (i in 1:length(val.variables)) {
  
  tercilePlot(obs = redim(obs.sub[[i]]), hindcast = redim(hind[[i]]))
}
dev.off()


