library(lubridate)
library(airGR)
library(dynatopmodel)
library(hydroGOF)
library(greenbrown)
catch.area = 214.7#in km2 
setwd("C:\\Users\\shikhani\\Documents\\WatexR_MS")

ERA5_daily <- get(load("ERA5_daily_Interpolated_March2020.RData"))
par(mfrow = c(2, 1))
start.date <-"1991-01-01"
stop.date <-"2016-12-31"
calb.date <- "2011-12-31"
val.date <- "2012-01-01"

met.gr4j <- data.frame(date=seq.Date(as.Date(ERA5_daily$tp$Dates$start[1]),as.Date(ERA5_daily$tp$Dates$end[length(ERA5_daily$tp$Dates$end)]),1), pr=ERA5_daily$tp$Data, PET=ERA5_daily$petH$Data)
met.g <- met.gr4j[which(met.gr4j$date ==start.date):which(met.gr4j$date == calb.date),]
#met.g$date <- 

inflow <- read.table("inflow_calc_NOV90_2020.csv", sep = ",", header =T , stringsAsFactors = F) 
head(inflow)
colnames(inflow) <- c("date", "flow", "temp")
range(inflow$date)
inflow$date <- ymd(inflow$date)
inflow$flow[which(inflow$flow < 0.1)] <- 0.1
#inflow <- inflow[which(inflow$date < "2014-01-01"),]
#inflow <- inflow[which(inflow$date >= "2003-01-01"),]

met.g$date <- as.POSIXct(as.character(met.g$date), tz = 'UTC')
#met.g <- met.g[which(met.g$date >= "2003-01-01"),]
range(met.g$date)
input_overlap <- data.frame(Date= inflow$date[which(inflow$date ==start.date):which(inflow$date == calb.date)], rain=met.g$pr[which(met.g$date ==as.POSIXct(start.date, tz= "UTC")):which(met.g$date == as.POSIXct(calb.date, tz= "UTC"))], evapo= met.g$PET[which(met.g$date ==as.POSIXct(start.date, tz= "UTC")):which(met.g$date == as.POSIXct(calb.date, tz= "UTC"))], inflow_m3per_s=inflow$flow[which(inflow$date ==start.date):which(inflow$date == calb.date)])

input_overlap$Date <- as.POSIXct(as.character(input_overlap$Date), tz = 'UTC')
input_overlap$flow.mm.day <- (input_overlap$inflow_m3per * (1000*60*60*24)) / (catch.area *1e6)

str(input_overlap)
#################
inputs <- CreateInputsModel(RunModel_GR6J, DatesR = met.g$date, Precip = met.g$pr, PotEvap = met.g$PET)
#inputs <- CreateInputsModel(RunModel_GR4J, DatesR =as.POSIXct( met.g$DateTime), Precip = met.g$tp_mm, PotEvap = met.g$petH_mm)
####
Ind_Run <- which(met.g[,1] >= input_overlap[1,1] & met.g[,1] <= input_overlap[nrow(input_overlap),1])
#Ind_Run <- which(met.g[,1] == as.Date("1992-01-01")) : which(met.g[,1] == input_overlap[nrow(input_overlap),1])

#Ind_Run <- 1:366
warm_up <- 1:(Ind_Run[1]-1)
#warm_up <- 1:5000

opts <- CreateRunOptions(RunModel_GR6J, InputsModel = inputs,IndPeriod_Run = Ind_Run, IndPeriod_WarmUp = warm_up)

Param = c(174.13, 1, 82.69, 0.5,  0.424,  4.759) #From Excel File

#wupper_q  <- run_gr4j(time = as.POSIXct(met.g[,1], tz = 'UTC'), pet = met.g$petH_mm, pre = met.g$tp_mm, warmup_ratio = NULL, param = wupper_param, catch_size = wupper_catch, out_file = wupper_outfile, airt = met.g$tas_?C, calc_T = TRUE, vector = TRUE)

mod1 = RunModel_GR6J(InputsModel = inputs, RunOptions = opts, Param = Param)
err_crit <- CreateInputsCrit(ErrorCrit_KGE, InputsModel = inputs, RunOptions = opts, Obs = input_overlap$flow.mm.day)
#err_crit <- CreateInputsCrit(ErrorCrit_KGE, InputsModel = inputs, RunOptions = opts, Obs = input_overlap$flow.mm.day[Ind_Run])

CalibOptions <- CreateCalibOptions(FUN_MOD = RunModel_GR6J, FUN_CALIB = Calibration_Michel)
#str(CalibOptions)

OutputsCalib <- Calibration_Michel(InputsModel = inputs, RunOptions = opts, InputsCrit = err_crit, CalibOptions = CalibOptions, FUN_MOD = RunModel_GR6J)

Param <- OutputsCalib$ParamFinalR
param.calb <- OutputsCalib$ParamFinalR
#Param <- as.vector(unlist(read.csv('C:\\Users\\shikhani\\Desktop\\watexr_git\\WATExR\\Wupper/GR4J/Param.csv')))
#Param <- param.ewembi
OutputsModel <- RunModel_GR6J(InputsModel = inputs, RunOptions = opts, Param = Param)
#plot(OutputsModel, Qobs = input_overlap$flow.mm.day)
#dev.off()

q_sim_m3_persec <- OutputsModel$Qsim*((catch.area *1e6)/(1000*60*60*24))
q_obs_m3_persec <- input_overlap$flow.mm.day*((catch.area *1e6)/(1000*60*60*24))

my_nse <-paste("NSE=" ,round(NSE(q_sim_m3_persec,q_obs_m3_persec,digits = 3),3), sep="")
my_kge <-paste(" KGE=" ,round(KGE(q_sim_m3_persec,q_obs_m3_persec)[1],3), sep="")
plot(input_overlap$Date,q_obs_m3_persec , type="l", ylab="Q m3/s", xlab = "Date", main = paste("Calibiration ", my_nse, my_kge, sep = ""))
lines(input_overlap$Date, q_sim_m3_persec , col="red")
     

#plot(OutputsModel, Qobs = input_overlap$flow.mm.day)

met.g<- met.gr4j[which(met.gr4j$date ==val.date ):which(met.gr4j$date == stop.date),]
met.g$date <- as.POSIXct(as.character(met.g$date), tz = 'UTC')
input_overlap <- data.frame(Date= inflow$date[which(inflow$date ==val.date ):which(inflow$date == stop.date)], rain=met.g$pr[which(met.g$date ==as.POSIXct(val.date, tz= "UTC")):which(met.g$date == as.POSIXct(stop.date, tz= "UTC"))], evapo= met.g$PET[which(met.g$date ==as.POSIXct(val.date, tz= "UTC") ):which(met.g$date == as.POSIXct(stop.date, tz= "UTC"))], inflow_m3per_s=inflow$flow[which(inflow$date ==val.date ):which(inflow$date == stop.date)])

input_overlap$Date <- as.POSIXct(as.character(input_overlap$Date), tz = 'UTC')
input_overlap$flow.mm.day <- (input_overlap$inflow_m3per * (1000*60*60*24)) / (catch.area *1e6)

#################
inputs <- CreateInputsModel(RunModel_GR6J, DatesR = met.g$date[which(met.g$date ==as.POSIXct(val.date, tz= "UTC") ):which(met.g$date == as.POSIXct(stop.date, tz= "UTC"))], Precip = met.g$pr[which(met.g$date ==as.POSIXct(val.date, tz= "UTC") ):which(met.g$date == as.POSIXct(stop.date, tz= "UTC"))], PotEvap = met.g$PET[which(met.g$date ==as.POSIXct(val.date, tz= "UTC") ):which(met.g$date == as.POSIXct(stop.date, tz= "UTC"))])
#inputs <- CreateInputsModel(RunModel_GR4J, DatesR =as.POSIXct( met.g$DateTime), Precip = met.g$tp_mm, PotEvap = met.g$petH_mm)
####
Ind_Run <- which(met.g[,1] >= input_overlap[1,1] & met.g[,1] <= input_overlap[nrow(input_overlap),1])
#Ind_Run <- which(met.g[,1] == as.Date("1992-01-01")) : which(met.g[,1] == input_overlap[nrow(input_overlap),1])

#Ind_Run <- 1:366
warm_up <- 1:(Ind_Run[1]-1)
#warm_up <- 1:5000

opts <- CreateRunOptions(RunModel_GR6J, InputsModel = inputs,IndPeriod_Run = Ind_Run, IndPeriod_WarmUp = warm_up)

OutputsModel <- RunModel_GR6J(InputsModel = inputs, RunOptions = opts, Param = param.calb)


q_sim_m3_persec <- OutputsModel$Qsim*((catch.area *1e6)/(1000*60*60*24))
q_obs_m3_persec <- input_overlap$flow.mm.day*((catch.area *1e6)/(1000*60*60*24))

my_nse <-paste("NSE=" ,round(NSE(q_sim_m3_persec,q_obs_m3_persec,digits = 3),3), sep="")
my_kge <-paste(" KGE=" ,round(KGE(q_sim_m3_persec,q_obs_m3_persec)[1],3), sep="")
plot(input_overlap$Date,q_obs_m3_persec , type="l", ylab="Q m3/s", xlab = "Date", main = paste("validation ", my_nse, my_kge, sep = ""))
lines(input_overlap$Date, q_sim_m3_persec , col="red")
