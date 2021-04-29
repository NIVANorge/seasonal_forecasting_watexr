library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal); library(RNetCDF); library(sp);library(convertR)
library(drought4R)#;library(loadeR.2nc)
#Ter_basin <- readOGR("/home/ry4902/Documents/Inputs_nhm-5.9/MorphologicalVar/DEM_Sources_Hydrosheds/Ter_basin_eu_bas_15s_beta.shp")
#spatialPlot(climatology(data.prelim$pr), sp.layout = list(list(Ter_basin, first = F, pch = 19, cex = 0.5)))

season_name <- "winter"
years <- c(1994:2016)
season <- c(11,12,1:2)
tercile_season <- c(12,1:2)

# Opening observation data
load("/home/ry4902/Documents/Workflow/Atmosphere/EWEMBI_Download/Interpolation/EWEMBI.RData")
EWEMBI.interp$tcc <- rad2cc(rsds = EWEMBI.interp$rsds, rlds = EWEMBI.interp$rlds)
#Magnus-Tetens formula for dew-point:Ts = (b * α(T,RH)) / (a - α(T,RH))
#a=17.62, b=243.12°C, α(T,RH) = ln(RH/100) +a*T/(b+T)
EWEMBI.interp$tdps <- EWEMBI.interp$hurs
EWEMBI.interp$tdps$Data <- (243.12 * (log(EWEMBI.interp$hurs$Data/100)+17.62*EWEMBI.interp$tas$Data/(243.12+EWEMBI.interp$tas$Data)) ) / (17.62 - (log(EWEMBI.interp$hurs$Data/100)+17.62*EWEMBI.interp$tas$Data/(243.12+EWEMBI.interp$tas$Data)))
EWEMBI.interp$hurs <- NULL
data_obs_sub <- lapply(1:length(EWEMBI.interp), function(x) subsetGrid(EWEMBI.interp[[x]], years = years, season=season))
names(data_obs_sub) <- names(EWEMBI.interp)
# Setting model data

load(paste("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/Interpolation/", season_name,".RData", sep=""))
data_model_sub <- list(uas=get(paste(season_name, ".interp", sep=""))$uas,
                       vas=get(paste(season_name, ".interp", sep=""))$vas,
                       ps=get(paste(season_name, ".interp", sep=""))$psl,
                       tas=get(paste(season_name, ".interp", sep=""))$tas,
                       pr=get(paste(season_name, ".interp", sep=""))$tp,
                       rsds=get(paste(season_name, ".interp", sep=""))$rsds,
                       rlds=get(paste(season_name, ".interp", sep=""))$rlds,
                       tasmin=get(paste(season_name, ".interp", sep=""))$tasmin,
                       tasmax=get(paste(season_name, ".interp", sep=""))$tasmax,
                       petH=get(paste(season_name, ".interp", sep=""))$petH,
                       tcc=get(paste(season_name, ".interp", sep=""))$tcc,
                       tdps=get(paste(season_name, ".interp", sep=""))$tdps)

data_model_sub <- lapply(1:length(EWEMBI.interp), function(x) subsetGrid(data_model_sub[[x]], years = years))
names(data_model_sub) <- names(EWEMBI.interp)

# Setting obs data
data_obs_ini <- lapply(1:length(EWEMBI.interp), function(x) subsetGrid(EWEMBI.interp[[x]], season = c(11,12), years = (years[1]-1)))
data_obs_mid <- lapply(1:length(EWEMBI.interp), function(x) subsetGrid(EWEMBI.interp[[x]], season = season, 
                                                                  years = c(years[1]:(years[length(years)]-1))))
data_obs_end <- lapply(1:length(EWEMBI.interp), function(x) subsetGrid(EWEMBI.interp[[x]], season = c(1,2),
                                                                  years = (years[length(years)])))
data_obs_sub <- lapply(1:length(EWEMBI.interp), function(x) bindGrid(data_obs_ini[[x]], 
                                                                data_obs_mid[[x]], 
                                                                data_obs_end[[x]], dimension = c("time")))

names(data_obs_sub) <- names(EWEMBI.interp)

# Check variable consistency
if (!identical(names(data_obs_sub), names(data_model_sub))) stop("variables in obs.data and data (seasonal forecast) do not match.")

data.bc.cross <- lapply(1:length(data_obs_sub), function(x)  {
  precip <- FALSE
  if (names(data_obs_sub)[x] == "pr") precip <- TRUE
  biasCorrection(y = data_obs_sub[[x]], x = data_model_sub[[x]], 
                 method = "eqm", cross.val = "loo",
                 precipitation = precip,
                 #window = c(30,7),
                 wet.threshold = 1,
                 join.members = TRUE)
}) 

names(data.bc.cross) <- c("pr","tas","pet")
save(data.bc.cross, file=paste("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BiasCorrectedWithEWEMBI_SAU-SQD/", season_name,"_BC.RData", sep=""))