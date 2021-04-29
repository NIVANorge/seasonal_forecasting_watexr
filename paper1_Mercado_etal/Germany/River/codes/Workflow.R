Sys.setenv(TZ = "UTC")

setwd("C:\\Users\\shikhani\\Documents/WatexR_MS/")
library(glmtools)
library(airGR)
library(lubridate)
library(transformeR)
library(loadeR.ECOMS)
library(loadeR)
library(visualizeR)
library(convertR)
library(drought4R)
library(downscaleR)
library(GLM3r)

min_vec <- c(0.2)
max_vec <- c(0.8)
n=1
x=1
## Prepare output file
obs_m <- get(load("ERA5_daily_Interpolated_March2020.RData"))

## Rdata folder
dir.Rdata <- "C:\\Users\\shikhani\\Documents/WatexR_MS/Rdata_2016\\"

## Metadata
model = c('GR6J', 'GLM')
season <- getSeason(obs_m$uas)
dataset <- "ERA5"
site = c('wupper', 'wuppertalsperre')
## File names
out = 'output.nc'
wupper_outfile = 'GLM\\GLM3_GR6J_ERA5\\inflow_Era5_GR6J.csv'
met_outfile <- 'GLM\\GLM3_GR6J_ERA5\\meteo.csv'
#####
inflow_ERA5 <- read.csv("GLM\\GLM3_GR6J_S5\\inflow_Era5_GR6J.csv", stringsAsFactors = F)
outflow_ERA5 <- read.csv("GLM\\GLM3_GR6J_S5\\outflow_fixed_GR6JGLM3calbirated.csv", stringsAsFactors = F)
## Catchment model data
# wupper
wupper_catch = 214.7
wupper_param = as.vector(unlist(read.csv('GR6J/Param_GR6J.csv')))
####

sim.folder <-  "C:\\Users\\shikhani\\Documents/WatexR_MS/GLM\\GLM3_GR6J_ERA5\\"
nml.file <- file.path(sim.folder,'glm3.nml')
nml.vlaues <- read_nml(nml.file)
start = "1991-01-01 00:00:00"
stop = "2016-12-31 00:00:00"
tg.years <- year(start):year(stop)
#####

## Create list for outputs and input new attributes
#####
# Observed
#test = subsetGrid(obs_m$u10, years=tg.years[-1])
obs <- list("wupper_q" = subsetGrid(obs_m$u10, years=tg.years[-1]),  "surftemp" = subsetGrid(obs_m$u10, years=tg.years[-1]), "bottemp" = subsetGrid(obs_m$u10, years=tg.years[-1])) #, "watertemp" = obs_m$uas)

attr(obs$wupper_q$Variable, "longname") <- paste("Discharge")
attr(obs$wupper_q$Variable, "description") <- paste("Discharge for Wupper")
obs$wupper_q$Variable$varName <- "wupper_q"
attr(obs$wupper_q$Variable, "units") <- "m3.s-1"

attr(obs$surftemp$Variable, "longname") <- paste("Surface temperature")
attr(obs$surftemp$Variable, "description") <- paste("Surface temperature")
obs$surftemp$Variable$varName <- "surftemp"
attr(obs$surftemp$Variable, "units") <- "degC"

attr(obs$bottemp$Variable, "longname") <- paste("Bottom temperature")
attr(obs$bottemp$Variable, "description") <- paste("Bottom temperature")
obs$bottemp$Variable$varName <- "bottemp"
attr(obs$bottemp$Variable, "units") <- "degC"


#####


## Load observed Met data
met_inp <-"C:\\Users\\shikhani\\Documents/WatexR_MS/ERA5_all_meteo_file_19900101-20200331_member01.dat"
met <- read.delim(met_inp, header =T)
range(met$petH_mm)
met$tp_mm[which(met$tp_mm<0)] <- 0
met$petH_mm[which(met$petH_mm<0)] <- 0
## Run catchment models and generate GOTM inputs
met<- met[which(met$DateTime== start):which(met$DateTime== stop),]
wupper_q  <- run_gr6j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm, pre = met$tp_mm, airt = met$tas_.C, warmup_unit = 'year', warmup_n = 1, param = wupper_param, catch_size = wupper_catch, out_file = wupper_outfile, calc_T = T, vector = FALSE, model="GLM")


obs$wupper_q$Data <- as.array(wupper_q$FLOW)
attributes(obs$wupper_q$Data) <- attributes(subsetGrid(obs_m$u10, years=tg.years[-1])$Data) 


# Plots
#temporalPlot(obs$wupper_q)

### Preparing GOTM
## Set background config
#####
met.glm <- data.frame(time=met$DateTime,
                      Shortwave=met$rsds_watt.m...2,
                      Cloud=met$cc_frac,
                      AirTemp=met$tas_.C,
                      RelHum=tdps2hurs(met$tas_.C+273.15, met$tdps_.C+273.15),
                      WindSpeed=sqrt((met$uas_m.s...1^2)+(met$vas_m.s...1^2)),
                      Rain=met$tp_mm/1000,
                      #Rain= wt.balance$rain,
                      Longwave= met$rlds_watt.m...2
                      
)

write.table(met.glm,met_outfile, row.names = F, quote = F, col.names = T, sep = ",")

## Set gotm.yaml met config


nml.vlaues <- set_nml(nml.vlaues,arg_name = "start",arg_val = "1991-12-31 00:00:00")

nml.vlaues <- set_nml(nml.vlaues,arg_name = "stop",arg_val =  stop)
#nml.vlaues <- set_nml(nml.vlaues,arg_name = "inflow_fl",arg_val = 'inflow_Era5_GR6J.csv')
nml.vlaues <- set_nml(nml.vlaues,arg_name = "meteo_fl",arg_val = 'meteo.csv')
nml.vlaues <- set_nml(nml.vlaues,arg_name = "min_layer_thick",arg_val = min_vec[n])
nml.vlaues <- set_nml(nml.vlaues,arg_name = "max_layer_thick",arg_val = max_vec[x])

write_nml(nml.vlaues,file=paste(sim.folder, "glm3.nml", sep = "\\"))

# Run GLM


run_glm(sim.folder,verbose = TRUE)

# Extract water temp
nc.file <- file.path(sim.folder, 'output/output.nc')
temp.surf <- get_temp(nc.file, reference = 'surface', z_out = 0.1)
temp.bott <- get_temp(nc.file, reference = 'bottom', z_out = 0.1)
wtemp <- data.frame(date = temp.surf[,1], surface=temp.surf[,2], bottom= temp.bott[,2])
surftemp <- wtemp[,2]
bottemp <- wtemp[,ncol(wtemp)]

# Input into list
obs$surftemp$Data <- as.array(surftemp)
attributes(obs$surftemp$Data) <- attributes(subsetGrid(obs_m$u10, years=tg.years[-1])$Data) 

obs$bottemp$Data <- as.array(bottemp)
attributes(obs$bottemp$Data) <- attributes(subsetGrid(obs_m$u10, years=tg.years[-1])$Data) 

#obs
# Plots
#temporalPlot(obs$surftemp, obs$bottemp)

# obs$watertemp <- NULL

#Save as .rda object
save(obs, file = paste0(dir.Rdata, paste(dataset, collapse = '_'), '_', paste(model, collapse = '_'), "_", paste0(season, collapse = "_"), "_", paste0(names(obs), collapse = "_"), ".rda"))


#############################


hind_m <- get(load("System5_seasonal_25_5_6_7_8_uas_vas_tdps_tas_cc_tp_rsds_rlds_petH_BCcross.rda"))
tg.years <- 1994:2016
hind_m_uas <-  subsetGrid(hind_m$uas, years = tg.years)
range(hind_m$uas$Dates$start)
range(hind_m$uas$Dates$end)
dir <- "C:\\Users\\shikhani\\Documents/WatexR_MS/Data_for_models/Summer/"


## Metadata
model = c('GR6J', 'GLM')
season <- getSeason(hind_m_uas)
dataset <- "System5"
site = c('wupper', 'wuppertalsperre')

## File names
out = 'output.nc'
wupper_outfile = 'GLM\\GLM3_GR6J_S5\\inflow_S5_GR6J.csv'
met_outfile <- 'GLM\\GLM3_GR6J_S5\\meteo.csv'
outflow_outfile <- 'GLM\\GLM3_GR6J_S5\\outflow_predicted.csv'
#####
inflow_ERA5 <- read.csv("GLM\\GLM3_GR6J_S5\\inflow_Era5_GR6J.csv", stringsAsFactors = F)
outflow_ERA5 <- read.csv("GLM\\GLM3_GR6J_S5\\outflow_fixed_GR6JGLM3calbirated.csv", stringsAsFactors = F)
outflow_ERA5 <- outflow_ERA5[which(ymd(outflow_ERA5$date) > ymd("1991-12-31")),]
outflow.lm <- lm(outflow ~ inflow, data = data.frame(inflow=inflow_ERA5[,2], outflow=outflow_ERA5[,2]))
## Catchment model data
# wupper
wupper_catch = 214.7
wupper_param = as.vector(unlist(read.csv('GR6J/Param_GR6J.csv')))
####

sim.folder <-  "C:\\Users\\shikhani\\Documents/WatexR_MS\\GLM\\GLM3_GR6J_S5\\"
nml.file <- file.path(sim.folder,'glm3.nml')
nml.vlaues <- read_nml(nml.file)
nc.file <- file.path(sim.folder, 'output/output.nc')

###
water_level <- read.table( file="water_level_March2020.csv", header=T,sep = ",", stringsAsFactors = F)
water_level$date <- ymd(water_level$date)


####
hind <- list("wupper_q" = hind_m_uas, "surftemp" = hind_m_uas, "bottemp" =hind_m_uas) 

attr(hind$wupper_q$Variable, "longname") <- paste("Discharge")
attr(hind$wupper_q$Variable, "description") <- paste("Discharge for Wupper river")
hind$wupper_q$Variable$varName <- "wupper_q"
attr(hind$wupper_q$Variable, "units") <- "m3.s-1"


attr(hind$surftemp$Variable, "longname") <- paste("Surface temperature")
attr(hind$surftemp$Variable, "description") <- paste("Surface temperature")
hind$surftemp$Variable$varName <- "surftemp"
attr(hind$surftemp$Variable, "units") <- "degC"

attr(hind$bottemp$Variable, "longname") <- paste("Bottom temperature")
attr(hind$bottemp$Variable, "description") <- paste("Bottom temperature")
hind$bottemp$Variable$varName <- "bottemp"
attr(hind$bottemp$Variable, "units") <- "degC"


########

#Select obs and mod files required for running the model
obs.files <- list.files(dir)[grep('ERA_5',list.files(dir))]
fc.files <- list.files(dir)[grep('System5',list.files(dir))]
#fc.files <-fc.files[145:160]
fc.files <- fc.files[which(as.numeric(gsub(".dat", "",sapply(strsplit(fc.files,'_')[1:length(fc.files)], `[`, 6)))%in%tg.years)]

## Time vector for subsetting outputs
fc_time <- format(as.POSIXct(hind$wupper_q$Dates$start), format =  '%Y-%m-%d %H:%M:%S')

#Create matrices for output
mat_wupper <- matrix(NA, nrow = nrow(hind_m_uas$Data), ncol = ncol(hind_m_uas$Data))
mat_surftemp <- matrix(NA, nrow = nrow(hind_m_uas$Data), ncol = ncol(hind_m_uas$Data))
mat_bottemp <- matrix(NA, nrow = nrow(hind_m_uas$Data), ncol = ncol(hind_m_uas$Data))
fc.dates <- as.POSIXct(hind$wupper_q$Dates$start, tz = 'UTC')
c <-0
e <- 0
for(i in fc.files){
  #i=fc.files[87]
  #i
  met <- read.delim(file.path(dir,i), header = T, stringsAsFactors = F)
  met$tp_mm[which(met$tp_mm<0)] <- 0
  met$petH_mm[which(met$petH_mm<0)] <- 0
  
  
  
  # Extract year and member
  met$year <- year(as.POSIXct(met[,1]))
  txt1 <- strsplit(i,'_')[[1]][4]
  txt2 <- strsplit(txt1, '-')[[1]][2]
  yr = year(as.POSIXct(txt2, format = '%Y%m%d'))
  mem = as.numeric(gsub("member", "", strsplit(i,'_')[[1]][5])) #as.numeric(strsplit(i,'_')[[1]][5])
  
  # Run Wupper
  
  wupper_q  <- run_gr6j(time = as.POSIXct(met[,1], tz = 'UTC'), pet = met$petH_mm, pre = met$tp_mm, warmup_unit = "year", warmup_n = 1, param = wupper_param, catch_size = wupper_catch, out_file = wupper_outfile, airt = met$tas_Â.C, calc_T = TRUE, vector = FALSE, model="GLM")
  
  dates_wupper_q <-  as.POSIXct(wupper_q[,1], tz = 'UTC')

  
  wupper_q$Time <- as.POSIXct(wupper_q$Time)
  wupper_q <- wupper_q[(wupper_q$Time >= (wupper_q$Time[nrow(wupper_q)] %m-% months(5))),]
  
  ind_ext1 <- which(as.POSIXct(wupper_q[,1], tz = 'UTC') %in% fc.dates)
  ind_inp1 <- which(fc.dates %in% as.POSIXct(wupper_q[,1], tz = 'UTC'))
  ind_row <- which(is.na(mat_wupper[mem,]))[1]
  dates_fc <- wupper_q[ind_ext1,1]
  dates_wrm <- dates_wupper_q [-which(dates_wupper_q  %in% dates_fc)]
    
  outflow.fc <- outflow_fix(model = outflow.lm, outflow = outflow_ERA5, inflow_mod= wupper_q, warmup_dates = dates_wrm, fc_dates = dates_fc, out_file =outflow_outfile )
  ###
  
  met.glm <- data.frame(time=as.POSIXct(as.character(met$DateTime)) ,
                        Shortwave=met$rsds_watt.m...2,
                        Cloud=met$cc_frac,
                        AirTemp=met$tdps_Â.C,
                        RelHum=tdps2hurs(met$tas_Â.C+273.15, met$tdps_Â.C+273.15),
                        WindSpeed=sqrt((met$uas_m.s...1^2)+(met$vas_m.s...1^2)),
                        #Rain= rep(0,length(met$DateTime)),
                        # Rain=wt.balance$rain,
                        Rain=met$tp_mm/1000,
                        Longwave= met$rlds_watt.m...2
                        
  )
  
  write.table(met.glm,met_outfile, row.names = F, quote = F, col.names = T, sep = ",")
  
  ## Set start stop time for GLM
  start = as.character(ymd_hms(met$DateTime[1])%m+% years(1))
  stop = met$DateTime[nrow(met)]
  nml.vlaues <- set_nml(nml.vlaues,arg_name = "start",arg_val = start)
  nml.vlaues <- set_nml(nml.vlaues,arg_name = "stop",arg_val =  stop)
  nml.vlaues <- set_nml(nml.vlaues,arg_name = "min_layer_thick",arg_val = min_vec[n])
  nml.vlaues <- set_nml(nml.vlaues,arg_name = "max_layer_thick",arg_val = max_vec[x])
  nml.vlaues <- set_nml(nml.vlaues,arg_name = "the_depths",arg_val =c(1,5,10,12,15,(water_level[which(as.character(water_level$date)==start),2]-223.25)))
  nml.vlaues <- set_nml(nml.vlaues,arg_name = "lake_depth",arg_val =(water_level[which(as.character(water_level$date)==start),2]-223.25))
  write_nml(nml.vlaues,file=paste(sim.folder, "glm3.nml", sep = "\\"))
  my.seq <- seq(from = as.POSIXct(start, tz="UTC"), to= as.POSIXct(stop, tz="UTC"), by = "days")
  # Run GLM
  #errort <- try(run_glm(sim.folder,verbose = T))
  
  
  run_glm(sim.folder,verbose = T)
  error <- try(get_temp(nc.file, reference = 'surface', z_out = 0.1))
  #print(error)
  if (!is.character(error)){
    # run_glm(sim.folder,verbose = TRUE)
    nc.file <- file.path(sim.folder, 'output/output.nc')
    temp.surf <- get_temp(nc.file, reference = 'surface', z_out = 0.1)
    temp.bott <- get_temp(nc.file, reference = 'bottom', z_out = 0.1)
    
  }else{
    e <- e +1
    
    # temp.surf <- data.frame(date=my.seq, temp=c(get_temp(nc.file, reference = 'surface', z_out = 0.1)[,2],rep(NA,(length(my.seq)-length(get_temp(nc.file, reference = 'surface', z_out = 0.1)[,1])))))
    #temp.bott <- data.frame(date=my.seq, temp=c(get_temp(nc.file, reference = 'bottom', z_out = 0.1)[,2],rep(NA,(length(my.seq)-length(get_temp(nc.file, reference = 'bottom', z_out = 0.1)[,1])))))
    temp.surf <- data.frame(date=my.seq, temp=rep(NA,length(my.seq)))
    temp.bott <- data.frame(date=my.seq, temp=rep(NA,length(my.seq)))
  }
  
  
  wtemp <- data.frame(date = temp.surf[,1], surface=temp.surf[,2], bottom= temp.bott[,2])
  wtemp$date <- as.POSIXct(wtemp$date)
  wtemp <- wtemp[(wtemp$date >= (wtemp$date[nrow(wtemp)] %m-% months(5))),]
  
  ind_ext2 <- which(wtemp[,1] %in% fc.dates)
  ind_inp2 <- which(fc.dates %in% wtemp[,1])
  
  surftemp <- wtemp[ind_ext2,2]
  bottemp <- wtemp[ind_ext2,ncol(wtemp)]
  
  #Input data in matrix
  mat_wupper[mem, ind_inp1] <- wupper_q[ind_ext1,2]
  mat_surftemp[mem, ind_inp2] <- surftemp
  mat_bottemp[mem, ind_inp2] <- bottemp
  
  c <- c+1
  cat(paste0(round(c / length(fc.files) * 100), '% completed'))
}
## Insert matrix into list w/ attributes
# Wupper
hind$wupper_q$Data <- as.array(mat_wupper)
attributes(hind$wupper_q$Data) <- attributes(hind_m_uas$Data) 
#Surface temperature
hind$surftemp$Data <- as.array(mat_surftemp)
attributes(hind$surftemp$Data) <- attributes(hind_m_uas$Data) 
#Bottom temperature
hind$bottemp$Data <- as.array(mat_bottemp)
attributes(hind$bottemp$Data) <- attributes(hind_m_uas$Data) 


#temporalPlot(hind$wupper_q$Data)
#temporalPlot(hind$wupper_q)
#temporalPlot(hind$surftemp, hind$bottemp)

# save Rdata for posterior bias correction of seasonal forecasts
dataset <- strsplit(fc.files[1], '_')[[1]][1]
save(hind, file = paste0(dir.Rdata, paste(dataset, collapse = '_'), '_', paste0(model, collapse = '_'), "_", paste0(season,collapse = "_"), "_", paste0(names(hind), collapse = "_"),".rda"))


plot.hind <- subsetGrid(hind$bottemp, years = c(1994:2016), season = c(6,7,8))
plot.obs <- subsetGrid(obs$bottemp, years = c(1994:2016), season = c(6,7,8))
attr(plot.obs$Data, "dimensions") <- c("time", "lat", "lon")
attr(plot.hind$Data, "dimensions") <- c("member", "time", "lat", "lon")
tercilePlot(plot.hind, plot.obs)

plot.hind <- subsetGrid(hind$surftemp, years = c(1994:2016), season = c(6,7,8))
plot.obs <- subsetGrid(obs$surftemp, years = c(1994:2016), season =c(6,7,8))
attr(plot.obs$Data, "dimensions") <- c("time", "lat", "lon")
attr(plot.hind$Data, "dimensions") <- c("member", "time", "lat", "lon")
tercilePlot(plot.hind, plot.obs)
e
