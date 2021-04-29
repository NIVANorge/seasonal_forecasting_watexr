setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GOTM")

library(gotmtools)
library(airGR)
library(lubridate)
library(transformeR)
library(visualizeR)
source('../R_scripts/modelling/functions/create_level.R')
source('../R_scripts/modelling/functions/match_hyps.R')
source('../R_scripts/modelling/functions/init_prof.R') #beta version - will be updated into gotmtools soon
source('../R_scripts/modelling/functions/run_gr4j.R')
source('../R_scripts/modelling/functions/streams_switch.R')


## Prepare output file
hind_m <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/System4_seasonal_15_2_3_4_5_uas_vas_ps_tas_pr_rsds_rlds_hurs_cc_petH_wss_BC.rda"))

dir.Rdata <- 'C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata\\'

## Metadata
model = c('GR4J', 'GOTM')
season <- getSeason(hind_m$uas)
dataset <- "System4"
site = c('echunga', 'onka', 'mtbold')

## File names
out = 'output.nc'
yaml = 'gotm.yaml'
ech_outfile = 'ech_inflow.dat'
onk_outfile = 'onk_inflow.dat'
met_outfile <- 'meteo_tmp.dat'

## Catchment model data
# Echunga
ech_catch = 31.9
ech_param = as.vector(unlist(read.csv('../GR4J/Echunga/calib_param.csv')))

# Onkaparinga
onk_catch = 324.87
onk_param = as.vector(unlist(read.csv('../GR4J/Onkaparinga/onka_gr4j_calib_param.csv')))

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


#####
# Prepare lists for hindcast output
hind <- list("ech_q" = hind_m$uas, "onk_q" = hind_m$uas, "surftemp" = hind_m$uas, "bottemp" = hind_m$uas) #, "watertemp" = hind_m$uas)

attr(hind$ech_q$Variable, "longname") <- paste("Discharge")
attr(hind$ech_q$Variable, "description") <- paste("Discharge for Echunga Creek")
hind$ech_q$Variable$varName <- "ech_q"
attr(hind$ech_q$Variable, "units") <- "m3.s-1"

attr(hind$onk_q$Variable, "longname") <- paste("Discharge")
attr(hind$onk_q$Variable, "description") <- paste("Discharge for the Onkaparinga river")
hind$onk_q$Variable$varName <- "onk_q"
attr(hind$onk_q$Variable, "units") <- "m3.s-1"

attr(hind$surftemp$Variable, "longname") <- paste("Surface temperature")
attr(hind$surftemp$Variable, "description") <- paste("Surface temperature")
hind$surftemp$Variable$varName <- "surftemp"
attr(hind$surftemp$Variable, "units") <- "degC"

attr(hind$bottemp$Variable, "longname") <- paste("Bottom temperature")
attr(hind$bottemp$Variable, "description") <- paste("Bottom temperature")
hind$bottemp$Variable$varName <- "bottemp"
attr(hind$bottemp$Variable, "units") <- "degC"

# attr(hind$watertemp$Variable, "longname") <- paste("Full profile")
# attr(hind$watertemp$Variable, "description") <- paste("Full profile")
# hind$watertemp$Variable$varName <- "watertemp"
# attr(hind$watertemp$Variable, "units") <- "degC"

########

dir <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data\\output/"

#Select obs and mod files required for running the model
obs.files <- list.files(dir)[grep('PIK_Obs',list.files(dir))]
fc.files <- list.files(dir)[grep('System4',list.files(dir))]


## Time vector for subsetting outputs
fc_time <- format(as.POSIXct(hind$ech_q$Dates$start), format =  '%Y-%m-%d %H:%M:%S')

#Create matrices for output
mat_ech <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_onk <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_surftemp <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_bottemp <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))

file.copy('output_temp.yaml', 'output.yaml', overwrite = T)
season <- getSeason(hind$ech_q)

fc.dates <- as.POSIXct(hind$ech_q$Dates$start, tz = 'UTC')

for(i in fc.files){
  met <- read.delim(file.path(dir,i), header = T, stringsAsFactors = F)
  
  met$pr_m.s.1 <- 1.157e-8*met$pr_mm
  met$ps_Pa <- met$ps_millibars *100 #Convert from mbar to Pa
  colnames(met)[1] <- '!DateTime'
  met[,-1] <- signif(met[,-1], digits = 5)
  write.table(met, met_outfile, col.names = T, row.names = F, quote = F, sep = '\t')
  
  if(i == fc.files[1]){
    ## Set gotm.yaml met config
    ######
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
  }

  
  # Extract year and member
  met$year <- year(as.POSIXct(met[,1]))
  txt1 <- strsplit(i,'_')[[1]][4]
  txt2 <- strsplit(txt1, '-')[[1]][2]
  yr = year(as.POSIXct(txt2, format = '%Y%m%d'))
  mem = as.numeric(gsub("member", "", strsplit(i,'_')[[1]][5])) #as.numeric(strsplit(i,'_')[[1]][5])
  
  # Run Echunga
  ech_q <- run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm.day.1, pre = met$pr_mm, warmup_ratio = NULL, param = ech_param, catch_size = ech_catch, out_file = ech_outfile, airt = met$tas_degC, calc_T = TRUE, vector = TRUE)
  ech_q$month <- month(ech_q[,1])
  ech_q$year <- year(ech_q[,1])
  
  # Run Onka
  onk_q <- run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm.day.1, pre = met$pr_mm, warmup_ratio = NULL, param = onk_param, catch_size = onk_catch, out_file = onk_outfile, airt = met$tas_degC, calc_T = TRUE, vector = TRUE)
  onk_q$month <- month(onk_q[,1])
  onk_q$year <- year(onk_q[,1])
  
  # Extract index for data to extract and member
  ech_q <- ech_q[(ech_q$year == yr),]
  ind_ext1 <- which(ech_q[,1] %in% fc.dates)
  ind_inp1 <- which(fc.dates %in% ech_q[,1])
  ind_row <- which(is.na(mat_ech[mem,]))[1]
  
  ## Set start stop time for GOTM
  start = met$`!DateTime`[1]
  stop = met$`!DateTime`[nrow(met)]
  input_yaml(file = yaml, label = 'time', key = 'start', value = start)
  input_yaml(file = yaml, label = 'time', key = 'stop', value = stop)
  
  # Run GOTM
  run_gotm()
  
  #Extract water temp
  wtemp <- get_vari(out, 'temp')
  wtemp$year <- year(wtemp[,1])
  wtemp <- wtemp[(wtemp$year == yr),]
  wtemp$year <- NULL
  
  ind_ext2 <- which(wtemp[,1] %in% fc.dates)
  ind_inp2 <- which(fc.dates %in% wtemp[,1])
  
  surftemp <- wtemp[ind_ext2,2]
  bottemp <- wtemp[ind_ext2,ncol(wtemp)]
  
    
  #Input data in matrix
  mat_ech[mem, ind_inp1] <- ech_q[ind_ext1,2]
  mat_onk[mem, ind_inp1] <- onk_q[ind_ext1,2]
  
  mat_surftemp[mem, ind_inp2] <- surftemp
  mat_bottemp[mem, ind_inp2] <- bottemp
  
}

## Insert matrix into list w/ attributes
# Echunga
hind$ech_q$Data <- as.array(mat_ech)
attributes(hind$ech_q$Data) <- attributes(hind_m$uas$Data) 
#Onka
hind$onk_q$Data <- as.array(mat_onk)
attributes(hind$onk_q$Data) <- attributes(hind_m$uas$Data) 
#Surface temperature
hind$surftemp$Data <- as.array(mat_surftemp)
attributes(hind$surftemp$Data) <- attributes(hind_m$uas$Data) 
#Bottom temperature
hind$bottemp$Data <- as.array(mat_bottemp)
attributes(hind$bottemp$Data) <- attributes(hind_m$uas$Data) 

temporalPlot(hind$ech_q$Data)
temporalPlot(hind$surftemp, hind$bottemp)

# save Rdata for posterior bias correction of seasonal forecasts
dataset <- strsplit(fc.files[1], '_')[[1]][1]
save(hind, file = paste0(dir.Rdata, paste(dataset, collapse = '_'), '_', paste0(model, collapse = '_'), "_", paste0(season, collapse = "_"), "_", paste0(names(hind), collapse = "_"), ".rda"))
