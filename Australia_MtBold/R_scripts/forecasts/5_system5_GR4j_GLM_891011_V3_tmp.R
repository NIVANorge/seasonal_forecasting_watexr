
## Set working directory ----
setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM")

season <- c(8:11)
tg.years <- 1993:2016

library(GLM3r)
library(glmtools)
library(airGR)
library(lubridate)
library(transformeR)

source('../R_scripts/modelling/functions/run_gr4j.R')
source('functions/create_meanflow.R')

# Load observed data ----
obs <- readRDS('../Rdata/ERA5_GR4J_GLM_1_2_3_4_5_6_7_8_9_10_11_12_ech_q_onk_q_surftemp_bottemp_wlev_v2.rds')
wlev <- subsetGrid(obs$wlev, years = c(1993:2016), season = season)
summary(as.vector(wlev$Data))
median_wlev <- median(as.vector(wlev$Data))
min_wlev <- min(as.vector(wlev$Data))



## Prepare output file ----
hind_m <- readRDS(paste0("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/System5_seasonal_25_", paste(season, collapse = ''), "_uas_vas_psl_tas_tp_tdps_cc_wss_petH_rsds_rlds_BCcross.rds"))
# hind_m <- get(load("C:\\Users\\shikhani\\Documents\\LINUX/System_5/Data_final_2019/System5_final_5_6_7_8_uas_vas_tdps_tas_cc_tp_rsds_rlds_petH_BCcross.rda"))

dir.Rdata <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/"


## Metadata
model <- c('GR4J', 'GLM')
season <- getSeason(hind_m$uas)
dataset <- "System5"
site <- c('mtbold') #, 'wuppertalsperre')

####
sim.folder <-  "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM"
tmpdir <- tempdir()
ifelse( length(list.files(tmpdir)) == 0, print('Empty temp directory!'), print(list.files(tmpdir)))
dir.create(file.path(tmpdir, 'output'))
nml.file <- file.path(sim.folder,'glm3_wbal.nml')
nml_list <- read_nml(nml.file)

## File names
out <- file.path(tmpdir, 'output//output.nc')
ech_outfile <- 'ech_inflow_S5_GR4J.csv'
onk_outfile <- 'onk_inflow_S5_GR4J.csv'
pipe_outfile <- 'pipe_inflow.csv'
inf_outfile <- 'inflow.csv' # Onka + pipe
outflow_outfile <- 'outflow.csv'
met_outfile <- 'meteo_seas.csv'


## Catchment model data
# Echunga
ech_catch <- 31.9
onk_catch <- 324.87
#wupper_param <- as.vector(unlist(read.csv('../Wupper/GR4J/Param.csv')))
ech_param <- as.vector(unlist(read.csv('../GR4J/Echunga/echunga_ERA5_gr4j_calib_param.csv')))[1:4]
onk_param <- as.vector(unlist(read.csv('../GR4J/Onkaparinga/onka_ERA5_gr4j_calib_param.csv')))[1:4]



#####
# Create mean pipe & outflow
create_meanflow(start = "1980-01-01 00:00:00", stop = '2019-01-01 00:00:00',
                matrix_file = 'pipe_matrix_2000_2006.csv',
                fname = file.path(tmpdir, pipe_outfile), index = 'mean')
create_meanflow(start = "1980-01-01 00:00:00", stop = '2019-01-01 00:00:00',
                matrix_file = 'mtbold_withdrawal_matrix_2011_2017.csv',
                fname = file.path(tmpdir, outflow_outfile), index = 'mean')

water_level <- read.table( file="MtBold_reservoir_height_1999-2018.dat", header=T,sep = "\t")
names(water_level)<- c("date", "level")


####
# Prepare lists for hindcast output
#hind <- list("wupper_q" = hind_m$uas, "surftemp" = hind_m$uas, "bottemp" = hind_m$uas) #, "watertemp" = hind_m$uas)
hind <- list("ech_q" = subsetGrid(hind_m$uas, years = tg.years),
             "onk_q" = subsetGrid(hind_m$uas, years = tg.years),
             "surftemp" = subsetGrid(hind_m$uas, years = tg.years),
             "bottemp" = subsetGrid(hind_m$uas, years = tg.years),
             "wlev" = subsetGrid(hind_m$uas, years = tg.years)) 

attr(hind$ech_q$Variable, "longname") <- paste("Discharge")
attr(hind$ech_q$Variable, "description") <- paste("Discharge for Echunga river")
hind$ech_q$Variable$varName <- "ech_q"
attr(hind$ech_q$Variable, "units") <- "m3.s-1"

attr(hind$onk_q$Variable, "longname") <- paste("Discharge")
attr(hind$onk_q$Variable, "description") <- paste("Discharge for Onkaparinga river")
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

attr(hind$wlev$Variable, "longname") <- paste("Water Level")
attr(hind$wlev$Variable, "description") <- paste("Height of water level")
hind$wlev$Variable$varName <- "wlev"
attr(hind$wlev$Variable, "units") <- "m"

########

dir <- paste0("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data\\MtBold\\CLIMATE\\System5_", paste(season, collapse = ""))


#Select obs and mod files required for running the model
obs.files <- list.files(dir)[grep('ERA_5',list.files(dir))]
fc.files <- list.files(dir)[grep('System5',list.files(dir))]


## Time vector for subsetting outputs
fc_time <- format(as.POSIXct(hind$ech_q$Dates$start), format =  '%Y-%m-%d %H:%M:%S')

#Create matrices for output
mat_ech <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_onk <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_surftemp <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_bottemp <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))
mat_wlev <- matrix(NA, nrow = nrow(hind_m$uas$Data), ncol = ncol(hind_m$uas$Data))

# Configure nml file ----
# init
nml_list <- set_nml(nml_list,arg_name = "meteo_fl", arg_val = met_outfile)
nml_list <- set_nml(nml_list,arg_name = "the_depths", arg_val = c(0, 15))
nml_list <- set_nml(nml_list,arg_name = "the_temps", arg_val = c(12, 12))
nml_list <- set_nml(nml_list,arg_name = "the_sals",arg_val = c(0, 0))
nml_list <- set_nml(nml_list,arg_name = "lake_depth",arg_val = 41.5)

# inflows
nml_list <- set_nml(nml_list, 'num_inflows', 2)
nml_list <- set_nml(nml_list, 'names_of_strms', c('Onka+Pipe', 'Echunga'))
nml_list <- set_nml(nml_list, 'inflow_fl', c(inf_outfile, ech_outfile))
nml_list <- set_nml(nml_list, 'subm_flag', c(F,F))
nml_list <- set_nml(nml_list, 'inflow_varnum', c(2,2))
nml_list <- set_nml(nml_list, 'strm_hf_angle', c(79.6,77.6))
nml_list <- set_nml(nml_list, 'strmbd_slope', c(0.33,0.47))
nml_list <- set_nml(nml_list, 'strmbd_drag', c(0.015,0.015))
nml_list <- set_nml(nml_list, 'inflow_factor', c(1,1))
nml_list <- set_nml(nml_list, 'inflow_vars', c('FLOW', 'TEMP'))

#outflow
nml_list <- set_nml(nml_list, 'outl_elvs', 202)
nml_list <- glmtools::set_nml(nml_list, 'num_outlet', 1)
nml_list <- glmtools::set_nml(nml_list, 'outflow_fl', outflow_outfile)

write_nml(nml_list, file = file.path(tmpdir, "glm3.nml"))

#file.copy('output_temp.yaml', 'output.yaml', overwrite = T)
season <- getSeason(hind$ech_q)

fc.dates <- as.POSIXct(hind$ech_q$Dates$start, tz = 'UTC')
e <- 0

# Seasonal Forecast Loop ----
for(i in fc.files) {
  #i=fc.files[88]

  met <- read.delim(file.path(dir,i), header = T, stringsAsFactors = F)
  met$tp[which(met$tp<0)] <- 0
  met$petH[which(met$petH<0)] <- 0
  
  dups <- duplicated(met$Date)
  met[dups,]
  #met$pr_m.s.1 <- 1.157e-8*met$pr_mm
  # met$ps_Pa <- met$ps_millibars *100 #Convert from mbar to Pa
  #colnames(met)[1] <- 'DateTime'
  # met[,-1] <- signif(met[,-1], digits = 5)
  met.glm <- data.frame(time=met$Date ,
                        ShortWave=met$ssrd,
                        LongWave = met$strd,
                        AirTemp = met$t2m,
                        RelHum = loadeR::tdps2hurs(met$t2m + 273.15, met$d2m + 273.15),
                        WindSpeed = met$wss,
                        Rain = met$tp / 1000)
  
  
  
  write.table(met.glm, file.path(tmpdir, met_outfile), row.names = F, quote = F, col.names = T, sep = ",")
  
  
  # Extract year and member
  met$year <- year(as.POSIXct(met[,1]))
  txt1 <- strsplit(i,'_')[[1]][5]
  txt2 <- strsplit(txt1, '-')[[1]][2]
  yr = year(as.POSIXct(txt2, format = '%Y%m%d'))
  mem = as.numeric(gsub("member", "", strsplit(i,'_')[[1]][6])) #as.numeric(strsplit(i,'_')[[1]][5])
  
  # Run Echunga ----
  ech_q  <- run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH, pre = met$tp, param = ech_param, catch_size = ech_catch,
                     out_file = file.path(tmpdir, ech_outfile), airt = met$t2m, calc_T = T, vector = TRUE, warmup_unit = 'year', warmup_n = 1, model = 'GLM')
  
  onk_q  <- run_gr4j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH, pre = met$tp, param = onk_param, catch_size = onk_catch,
                     out_file = file.path(tmpdir, onk_outfile), airt = met$t2m, calc_T = T, vector = TRUE, warmup_unit = 'year', warmup_n = 1, model = 'GLM')
  
  # Add Pipe to Onka
  pip <- read.csv(pipe_outfile, stringsAsFactors = F)
  onk <- read.csv(onk_outfile, stringsAsFactors = F)
  # pip[pip$Time >= onk[1,1] & pip$Time <= onk[nrow(onk),1],]
  inf <- merge(onk, pip, by = 1, all.x = T)
  inf$FLOW <- inf$FLOW.x + inf$FLOW.y
  inf <- inf[, c('Time', 'FLOW', 'TEMP')]
  write.csv(inf, file.path(tmpdir, inf_outfile), row.names = F, quote = F)
  
  # Subset to last 5 months
  ech_q <- ech_q[(ech_q$Time >= (ech_q$Time[nrow(ech_q)] %m-% months(5))),]
  onk_q <- onk_q[(onk_q$Time >= (onk_q$Time[nrow(onk_q)] %m-% months(5))),]
  # Extract index for data to extract and member
  ind_ext1 <- which(ech_q[,1] %in% fc.dates)
  ind_inp1 <- which(fc.dates %in% ech_q[,1])
  ind_row <- which(is.na(mat_ech[mem,]))[1]
  
  #Input data in matrix
  mat_ech[mem, ind_inp1] <- ech_q[ind_ext1,2]
  mat_onk[mem, ind_inp1] <- onk_q[ind_ext1,2]
  
  ## Set start stop time for GLM - Always ~ June 30
  if (month(met$Date[nrow(met)]) <= 7 ) {
    dif <- 1 + 12 - ( 7 - month(met$Date[nrow(met)]))
  } else if (month(met$Date[nrow(met)]) %in% c(6,7,8) ) {
    dif <- 1 + 12 + month(met$Date[nrow(met)]) - 7
  } else {
    dif <- 1 + month(met$Date[nrow(met)]) - 7
  }
  start <- as.character(ymd_hms(met$Date[nrow(met)]) %m-% years(1) %m-% months(dif))
  
  #start = met$DateTime[1]
  stop <- met$Date[nrow(met)]
  #stop =as.character(ymd_hms(met$DateTime[1])%m+% years(2))
  nml_list <- set_nml(nml_list,arg_name = "start",arg_val = start)
  nml_list <- set_nml(nml_list,arg_name = "stop",arg_val =  stop)
  
  write_nml(nml_list, file = file.path(tmpdir,  "glm3.nml"))
  
  my.seq <- seq(from = as.POSIXct(start, tz="UTC"), to= as.POSIXct(stop, tz="UTC"), by = "days")
  
  
  
  # Run GLM
  flag <- FALSE
  out_fct <- 1
  nml_list <- set_nml(nml_list,arg_name = "outflow_factor",arg_val =  out_fct <- 1)
  write_nml(nml_list, file = file.path(tmpdir,  "glm3.nml"))
  log_file <- paste0('Outflow_factor_log_', paste(season, collapse = ''), '.txt')
  
  if( i == fc.files[1] ) {
    unlink(log_file) # Delete previous log file
  }
  
  while( !flag) {
    error <- try(run_glm(tmpdir, verbose = F))
    chk_sh <- get_surface_height(out)
    min_chk <- min(chk_sh$surface_height, na.rm = T)
    chk_sh <- chk_sh[(chk_sh$DateTime >= (chk_sh$DateTime[nrow(chk_sh)] %m-% months(4))),]
    med_chk <- median(chk_sh$surface_height, na.rm = T)
    
    # If running out of water reduce outflow
    if( min_chk < min_wlev | med_chk < median_wlev | is.na(med_chk) ){
      out_fct <- get_nml_value(nml_list, 'outflow_factor')
      out_fct <- out_fct - 0.1
      nml_list <- set_nml(nml_list,arg_name = "outflow_factor",arg_val =  out_fct)
      write_nml(nml_list, file = file.path(tmpdir,  "glm3.nml"))
      print(out_fct)
      # Break if out_fct is less than 0
      if( out_fct < 0 ) {
        break
      }
      
    } else {
      flag <- TRUE
      log <- data.frame(Year = year(chk_sh[nrow(chk_sh),1]), Member = mem,
                        out_factor = out_fct)
      write(x = unlist(log),
            file = log_file, append = TRUE)
    }
    
  }
  
  
  if (error == 0) {
    temp.surf <- get_temp(out, reference = 'surface', z_out = 1)
    temp.bott <- get_temp(out, reference = 'bottom', z_out = 1)
    surf.hgh <- get_surface_height(out)
  } else {
    e <- e +1
    temp.surf <- data.frame(date=my.seq, temp=rep(NA,length(my.seq)))
    temp.bott <- data.frame(date=my.seq, temp=rep(NA,length(my.seq)))
    surf.hgh <- data.frame(date=my.seq, temp=rep(NA,length(my.seq)))
    
  }
  
  wtemp <- data.frame(date = temp.surf[,1], surface=temp.surf[,2], bottom= temp.bott[,2])
  
  wtemp <- wtemp[(wtemp$date >= (wtemp$date[nrow(wtemp)] %m-% months(5))),]
  
  surf.hgh <- surf.hgh[(surf.hgh$DateTime >= (surf.hgh$DateTime[nrow(surf.hgh)] %m-% months(5))),]
  
  ind_ext2 <- which(wtemp[,1] %in% fc.dates)
  ind_inp2 <- which(fc.dates %in% wtemp[,1])
  
  surftemp <- wtemp[ind_ext2,2]
  bottemp <- wtemp[ind_ext2,ncol(wtemp)]
  wlev <- surf.hgh[ind_ext2, 2]
  
  
  #Input data in matrix
  mat_surftemp[mem, ind_inp2] <- surftemp
  mat_bottemp[mem, ind_inp2] <- bottemp
  mat_wlev[mem, ind_inp2] <- wlev
  
}

## Insert matrix into list w/ attributes
# Echunga
hind$ech_q$Data <- as.array(mat_ech)
attributes(hind$ech_q$Data) <- attributes(hind_m$uas$Data) 
# Onkaparinga
hind$onk_q$Data <- as.array(mat_onk)
attributes(hind$onk_q$Data) <- attributes(hind_m$uas$Data)
# Surface temperature
hind$surftemp$Data <- as.array(mat_surftemp)
attributes(hind$surftemp$Data) <- attributes(hind_m$uas$Data)
# Bottom temperature
hind$bottemp$Data <- as.array(mat_bottemp)
attributes(hind$bottemp$Data) <- attributes(hind_m$uas$Data)
# Water level
hind$wlev$Data <- as.array(mat_wlev)
attributes(hind$wlev$Data) <- attributes(hind_m$uas$Data)
visualizeR::temporalPlot(hind$wlev)

#temporalPlot(hind$wupper_q$Data)
#temporalPlot(hind$surftemp, hind$bottemp)

# save Rdata for posterior bias correction of seasonal forecasts
dataset <- strsplit(fc.files[1], '_')[[1]][1]
saveRDS(hind, file = paste0(dir.Rdata, paste(dataset, collapse = '_'), '_', paste0(model, collapse = '_'), "_", paste0(season,collapse = "_"), "_", paste0(names(hind), collapse = "_"), ".rds"))


