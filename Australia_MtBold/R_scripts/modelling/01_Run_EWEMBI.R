setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GOTM")

library(gotmtools)
library(airGR)
library(lubridate)
source('../R_scripts/modelling/functions/create_level.R')
source('../R_scripts/modelling/functions/match_hyps.R')
source('../R_scripts/modelling/functions/init_prof.R') #beta version - will be updated into gotmtools soon
source('../R_scripts/modelling/functions/run_gr4j.R')
source('../R_scripts/modelling/functions/streams_switch.R')

## Prepare output file
obs_m <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_tasmax_tasmin_pr_rsds_rlds_hurs_cc_petH.rda"))

## Rdata folder
dir.Rdata <- 'C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata\\'

## Metadata
model = c('GR4J', 'GOTM')
season <- getSeason(obs_m$uas)
dataset <- "EWEMBI"
site = c('echunga', 'onka', 'mtbold')

## File names
out = 'output.nc'
yaml = 'gotm.yaml'
ech_outfile = 'ech_inflow.dat'
onk_outfile = 'onk_inflow.dat'
met_outfile <- 'meteo_tmp.dat'

## Create list for outputs and input new attributes
#####
# Observed
obs <- list("ech_q" = obs_m$uas, "onk_q" = obs_m$uas, "surftemp" = obs_m$uas, "bottemp" = obs_m$uas) #, "watertemp" = obs_m$uas)

attr(obs$ech_q$Variable, "longname") <- paste("Discharge")
attr(obs$ech_q$Variable, "description") <- paste("Discharge for Echunga Creek")
obs$ech_q$Variable$varName <- "ech_q"
attr(obs$ech_q$Variable, "units") <- "m3.s-1"

attr(obs$onk_q$Variable, "longname") <- paste("Discharge")
attr(obs$onk_q$Variable, "description") <- paste("Discharge for the Onkaparinga river")
obs$onk_q$Variable$varName <- "onk_q"
attr(obs$onk_q$Variable, "units") <- "m3.s-1"

attr(obs$surftemp$Variable, "longname") <- paste("Surface temperature")
attr(obs$surftemp$Variable, "description") <- paste("Surface temperature")
obs$surftemp$Variable$varName <- "surftemp"
attr(obs$surftemp$Variable, "units") <- "degC"

attr(obs$bottemp$Variable, "longname") <- paste("Bottom temperature")
attr(obs$bottemp$Variable, "description") <- paste("Bottom temperature")
obs$bottemp$Variable$varName <- "bottemp"
attr(obs$bottemp$Variable, "units") <- "degC"

# attr(obs$watertemp$Variable, "longname") <- paste("Full profile")
# attr(obs$watertemp$Variable, "description") <- paste("Full profile")
# obs$watertemp$Variable$varName <- "watertemp"
# attr(obs$watertemp$Variable, "units") <- "degC"

#####


## Load observed Met data
met_inp <- '../data/output/PIK_Obs-EWEMBI_all_meteo_file_19790101-20101231_member01.dat'
met <- read.delim(met_inp, header = T)

## Run catchment models and generate GOTM inputs
# from WateXr\MtBold_Data\Echunga Creek GR4J
#Echunga
ech_catch = 31.9
ech_param = as.vector(unlist(read.csv('../GR4J/Echunga/calib_param.csv')))
ech_q <- run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm.day.1, pre = met$pr_mm, warmup_ratio = NULL, param = ech_param, catch_size = ech_catch, out_file = ech_outfile, airt = met$tas_degC, calc_T = TRUE, vector = TRUE)

obs$ech_q$Data <- as.array(ech_q$Q_m.3.s.1)
attributes(obs$ech_q$Data) <- attributes(obs_m$uas$Data) 

#Onkaparinga
onk_catch = 324.87
onk_param = as.vector(unlist(read.csv('../GR4J/Onkaparinga/onka_gr4j_calib_param.csv')))
onk_q <- run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm.day.1, pre = met$pr_mm, warmup_ratio = NULL, param = onk_param, catch_size = onk_catch, out_file = onk_outfile, airt = met$tas_degC, calc_T = TRUE, vector = TRUE)
# plot_inp(onk_outfile, header = T)

obs$onk_q$Data <- as.array(onk_q$Q_m.3.s.1)
attributes(obs$onk_q$Data) <- attributes(obs_m$uas$Data) 

# Plots
temporalPlot(obs$ech_q, obs$onk_q)

### Preparing GOTM
## Set background config
#####
input_yaml(file = yaml, label = 'location', key = 'name', value = 'mt_bold')
input_yaml(file = yaml, label = 'location', key = 'latitude', value = -35.12)
input_yaml(file = yaml, label = 'location', key = 'longitude', value = 138.70)
input_yaml(file = yaml, label = 'time', key = 'dt', value = 3600)
#####

## Create water level
wlevel_median_file = 'median_height.dat'
wlevel_out = 'wlevel.dat'
init_dep = create_level(from = as.POSIXct('1979-01-01'), to = as.POSIXct('2010-12-31'), in_file = wlevel_median_file, out_file = wlevel_out)
input_yaml(file = yaml, label = 'zeta', key = 'method', value = 2)
input_yaml(file = yaml, label = 'zeta', key = 'file', value = wlevel_out)
input_yaml(file = yaml, label = 'zeta', key = 'offset', value = -init_dep)
input_yaml(file = yaml, label = 'location', key = 'depth', value = init_dep)

## Normlize hypsograph to new depth
match_hyps(in_file = 'hypsograph.dat', out_file = 'temp_hypsograph.dat', lake_level = init_dep)
input_yaml(file = yaml, label = 'location', key = 'hypsograph', value = 'temp_hypsograph.dat')
# plot_hypso('temp_hypsograph.dat')

## Create initial temperature profile
obs_file = 'temp_02-18.obs'
init_prof(obs_file = obs_file, date = '1979-01-01 00:00:00', tprof_file = 'init_tprof.dat', month = 1, ndeps = 2, btm_depth = -init_dep, print = T)
input_yaml(file = yaml, label = 'temperature', key = 'method', value = 2)
input_yaml(file = yaml, label = 'temperature', key = 'file', value = 'init_tprof.dat')

met$pr_m.s.1 <- 1.157e-8*met$pr_mm
# met$ps_Pa <- met$ps_millibars *100 #Convert from mbar to Pa
colnames(met)[1] <- '!DateTime'
met[,-1] <- signif(met[,-1], digits = 5)
write.table(met, met_outfile, col.names = T, row.names = F, quote = F, sep = '\t')

## Set gotm.yaml met config
######
# Setup gotm.yaml file
yaml = 'gotm.yaml'
#u10
input_yaml(file = yaml, label = 'u10', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'u10', key = 'column', value = (which(colnames(met) == "uas_m.s.1")-1))
input_yaml(file = yaml, label = 'u10', key = 'scale_factor', value = 1)
#v10
input_yaml(file = yaml, label = 'v10', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'v10', key = 'column', value = (which(colnames(met) == "vas_m.s.1")-1))
input_yaml(file = yaml, label = 'v10', key = 'scale_factor', value = 1)
#airp
input_yaml(file = yaml, label = 'airp', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'airp', key = 'column', value = (which(colnames(met) == "ps_Pa")-1))
input_yaml(file = yaml, label = 'airp', key = 'scale_factor', value = 1)
#airt
input_yaml(file = yaml, label = 'airt', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'airt', key = 'column', value = (which(colnames(met) == "tas_degC")-1))
input_yaml(file = yaml, label = 'airt', key = 'scale_factor', value = 1)
#hum
input_yaml(file = yaml, label = 'hum', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'hum', key = 'column', value = (which(colnames(met) == "hurs_.")-1))
input_yaml(file = yaml, label = 'hum', key = 'type', value = 1) #1=relative humidity (%), 2=wet-bulb temperature, 3=dew point temperature, 4=specific humidity (kg/kg)
input_yaml(file = yaml, label = 'hum', key = 'scale_factor', value = 1)
#cloud
input_yaml(file = yaml, label = 'cloud', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'cloud', key = 'column', value = (which(colnames(met) == "cc_frac")-1))
input_yaml(file = yaml, label = 'cloud', key = 'scale_factor', value = 1)
#swr
input_yaml(file = yaml, label = 'swr', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'swr', key = 'column', value = (which(colnames(met) == "rsds_W.m.2")-1))
input_yaml(file = yaml, label = 'swr', key = 'scale_factor', value = 1)
#precip
input_yaml(file = yaml, label = 'precip', key = 'file', value = met_outfile)
input_yaml(file = yaml, label = 'precip', key = 'column', value = (which(colnames(met) == "pr_m.s.1")-1))
input_yaml(file = yaml, label = 'precip', key = 'scale_factor', value = 1)
#back_radiation
input_yaml(file = yaml, label = 'back_radiation', key = 'method', value = 1)

#####

## Set start stop time
start = met$`!DateTime`[1]
stop = met$`!DateTime`[nrow(met)]
input_yaml(file = yaml, label = 'time', key = 'start', value = start)
input_yaml(file = yaml, label = 'time', key = 'stop', value = stop)

## Switch streams on/off
# streams_switch(yaml, method = 'on')

run_gotm()

# Extract water temp
wtemp <- get_vari(out, 'temp')
surftemp <- wtemp[,2]
bottemp <- wtemp[,ncol(wtemp)]

# Input into list
obs$surftemp$Data <- as.array(surftemp)
attributes(obs$surftemp$Data) <- attributes(obs_m$uas$Data) 

obs$bottemp$Data <- as.array(bottemp)
attributes(obs$bottemp$Data) <- attributes(obs_m$uas$Data) 

# Plots
temporalPlot(obs$surftemp, obs$bottemp)

# obs$watertemp <- NULL

## Save as .rda object
save(obs, file = paste0(dir.Rdata, paste(dataset, collapse = '_'), '_', paste(model, collapse = '_'), "_", paste0(season, collapse = "_"), "_", paste0(names(obs), collapse = "_"), ".rda"))

