setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data/Onka_Murray_pipe/")

library(airGR)
library(hydroGOF)
library(lubridate)
source("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\R_scripts\\modelling\\functions/run_gr4j.R")

catch.area = 324.87
warm_up <- 5 # years
ratio <- 1 # calibration to validation

inp <- read.csv('Onka_no_pipe_1999_2006_cumecs.csv')
inp[,1] <- as.POSIXct(inp[,1], tz = 'UTC')
# inp$flow.mm.day <- (inp$FLOW *1000* (60*60*24)) / (catch.area *1000000)

# inp <- readr::read_csv('Onka_Hahndorf_1999-2006_1day_corrected.csv')
# inp <- readr::read_csv('../../GLM/onka_1973_2018_1day.csv')
inp$flow.m3.day <- inp$FLOW * 86400
# inp$Date <- as.POSIXct(inp$Date, tz = 'UTC')
# inp$flow.m3.day <- inp$Catchment.flow.ML.d * 1000
# inp$flow.m3.s <- inp$Catchment.flow.ML.d * 0.0115740741
inp$flow.mm.day <- (inp$flow.m3.day) / (catch.area *1000)
inp <- as.data.frame(inp)
# inp$flow.mm.day <- (inp$flow.m3.s *1000* (60*60*24)) / (catch.area *1000000)
inp.cal <- inp[(inp[,1] < inp$Time[nrow(inp) / (ratio + 1)]), ]
inp.val <- inp[(inp[,1] >= inp$Time[nrow(inp) / (ratio + 1)]), ]

met <- read.delim("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Meteo/GR4J_Mt.Bold_1950-2018_airt_pet_pre.dat")
met[,1] <- as.POSIXct(met[,1], tz = 'UTC')
met <- met[(met$date >= (inp.cal[1,1] %m-% years(warm_up))), ]

inputs <- CreateInputsModel(RunModel_GR4J, DatesR = met[,1], Precip = met$daily_rain, PotEvap = met$et_morton_potential)
## run period selection
Ind_Run <- which(met[,1] >= inp.cal[1,1] & met[,1] <= inp.cal[nrow(inp.cal),1])
warm_up <- 1:(Ind_Run[1]-1)
opts <- CreateRunOptions(RunModel_GR4J, InputsModel = inputs,IndPeriod_Run = Ind_Run, IndPeriod_WarmUp = warm_up)

Param = c(474.13, -2.65, 12.69, 0.5) #From Excel File

mod1 = RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = Param)
plot(mod1$DatesR, mod1$Qsim, type ='l', col =2)
lines(inp$Time, inp$flow.mm.day)
NSE(mod1$Qsim, inp.cal$flow.mm.day)

dim(inp)
str(inputs)
#Calibration
err_crit <- CreateInputsCrit(ErrorCrit_NSE, InputsModel = inputs, RunOptions = opts, Obs = inp.cal$flow.mm.day)

CalibOptions <- CreateCalibOptions(FUN_MOD = RunModel_GR4J, FUN_CALIB = Calibration_Michel)
str(CalibOptions)

OutputsCalib <- Calibration_Michel(InputsModel = inputs, RunOptions = opts, InputsCrit = err_crit, CalibOptions = CalibOptions, FUN_MOD = RunModel_GR4J)

Param <- OutputsCalib$ParamFinalR
Param #270.426407   0.201336  10.381237   2.949700
param_out <- data.frame(prod.stor.cap_mm = Param[1], inter.exch.coeff_mm.d = Param[2], rout.stor.cap_mm = Param[3], unit.hyd.time.cons_d = Param[4])
write.csv(param_out, 'onka_obs_gr4j_calib_param_cal-period.csv', row.names = F, quote = F)
#Param <- c(474.13,-2.65,12.69,0.5) #Param from excel

OutputsModel <- RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = Param)
str(OutputsModel)

png('Echunga_GR4J_obs_Calib_results.png', height = 900, width = 1600, res =120)
plot(OutputsModel, Qobs = inp.cal$flow.mm.day)
dev.off()

nse_cal <- NSE(OutputsModel$Qsim, inp.cal$flow.mm.day)
kge_cal <- KGE(OutputsModel$Qsim, inp.cal$flow.mm.day)

OutputsCrit <- ErrorCrit_NSE(InputsCrit = err_crit, OutputsModel = OutputsModel)
OutputsCrit <- ErrorCrit_KGE(InputsCrit = err_crit, OutputsModel = OutputsModel)


#Validation data
## run period selection
Ind_Run <- which(met[,1] >= inp.val[1,1] & met[,1] <= inp.val[nrow(inp.val),1])
warm_up <- 1:(Ind_Run[1]-1)
opts <- CreateRunOptions(RunModel_GR4J, InputsModel = inputs,IndPeriod_Run = Ind_Run, IndPeriod_WarmUp = warm_up)

OutputsModel2 <- RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = Param)
str(OutputsModel2)

png('Echunga_GR4J_EWEMBI_Valid_results.png', height = 900, width = 1600, res =120)
plot(OutputsModel2, Qobs = inp.val$flow.mm.day)
dev.off()

nse_val <- NSE(OutputsModel2$Qsim, inp.val$flow.mm.day)
kge_val <- KGE(OutputsModel2$Qsim, inp.val$flow.mm.day)
rmse(OutputsModel2$Qsim, inp.val$flow.mm.day)

message("calib: NSE - ", nse_cal, " KGE - ", kge_cal,
        "\n valid: NSE - ", nse_val, "KGE - ", kge_val)


wup = nrow(met[met$date < '1980-01-01',])

run_gr4j(time = met$date, pet = met$et_morton_potential, pre = met$daily_rain, airt = met$mean_temp, warmup_unit = 'day', warmup_n = wup, param = Param, catch_size = catch.area, out_file = 'onka_obs_GR4J_flow_1980_2018.csv', calc_T = F, vector = F, model = 'GLM')

Param <- data.frame(prod.stor.cap_mm = Param[1], inter.exch.coeff_mm.d = Param[2], rout.stor.cap_mm = Param[3], unit.hyd.time.cons_d = Param[4])
write.csv(Param, 'onka_obs_gr4j_calib_param_1980_2018.csv', row.names = F, quote = F)


# ERA5 ----
met <- read.delim("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Meteo/mt_bold_ERA5_1980_2019_1day.dat")
met[,1] <- as.POSIXct(met[,1], tz = 'UTC')
met$tp_m[met$tp_m < 0] <- 0
met$tp_mm <- met$tp_m * 1000
met$mper_mm.d...1 <- abs(met$mper_mm.d...1)
met$mper_mm.d...1[met$mper_mm.d...1 < 0] <- 0
time <- seq.POSIXt(met[1,1], met[nrow(met),1], by = '1 day')
nrow(met) == length(time)

# GR4J ----
inputs <- CreateInputsModel(RunModel_GR4J, DatesR = met$X.DateTime, Precip = met$tp_mm, PotEvap = met$mper_mm.d...1)
## run period selection
Ind_Run <- which(met[,1] >= inp.cal[1,1] & met[,1] <= inp.cal[nrow(inp.cal),1])
warm_up <- 1:(Ind_Run[1]-1)
opts <- CreateRunOptions(RunModel_GR4J, InputsModel = inputs,IndPeriod_Run = Ind_Run, IndPeriod_WarmUp = warm_up)

Param = c(474.13, -2.65, 12.69, 0.5) #From Excel File

mod1 = RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = Param)
plot(mod1$DatesR, mod1$Qsim, type ='l', col =2)
lines(inp$Time, inp$flow.mm.day)
NSE(mod1$Qsim, inp.cal$flow.mm.day)

dim(inp)
str(inputs)
#Calibration
err_crit <- CreateInputsCrit(ErrorCrit_KGE, InputsModel = inputs, RunOptions = opts, Obs = inp.cal$flow.mm.day)

CalibOptions <- CreateCalibOptions(FUN_MOD = RunModel_GR4J, FUN_CALIB = Calibration_Michel)
str(CalibOptions)

OutputsCalib <- Calibration_Michel(InputsModel = inputs, RunOptions = opts, InputsCrit = err_crit, CalibOptions = CalibOptions, FUN_MOD = RunModel_GR4J)

Param <- OutputsCalib$ParamFinalR
Param #355.0413924  -1.5157529  13.8551754   0.5708907
#Param <- c(474.13,-2.65,12.69,0.5) #Param from excel

nse <- NSE(OutputsModel$Qsim, inp.cal$flow.mm.day)
kge <- KGE(OutputsModel$Qsim, inp.cal$flow.mm.day)

png('Onka_GR4J_ERA5_Calib_results_all.png', height = 900, width = 1600, res =120)
plot(OutputsModel, Qobs = inp.cal$flow.mm.day)
mtext(paste0("KGE = ", round(kge,2), "; NSE = ", round(nse, 2)), side=3, cex = 2)
dev.off()


Param2 <- data.frame(prod.stor.cap_mm = Param[1], inter.exch.coeff_mm.d = Param[2], rout.stor.cap_mm = Param[3], unit.hyd.time.cons_d = Param[4], NSE = nse, KGE = kge)
write.csv(Param2, 'onka_ERA5_gr4j_calib_param.csv', row.names = F, quote = F)



# Create inflow file ----

wup = 0

Param <- read.csv('onka_ERA5_gr4j_calib_param.csv')
Param <- unlist(Param)[1:4]

run_gr4j(time = met$X.DateTime, pet = met$mper_mm.d...1, pre = met$tp_mm, airt = met$t2m_celsius, warmup_unit = 'day', warmup_n = wup, param = Param, catch_size = catch.area, out_file = 'onka_ERA5_GR4J_flow_1980_2019_noTemp.csv', calc_T = F, vector = F, model = 'GLM')
run_gr4j(time = met$X.DateTime, pet = met$mper_mm.d...1, pre = met$tp_mm, airt = met$t2m_celsius, warmup_unit = 'day', warmup_n = wup, param = Param, catch_size = catch.area, out_file = 'onka_ERA5_GR4J_flow_1980_2019_wTemp.csv', calc_T = T, vector = F, model = 'GLM')

Param <- data.frame(prod.stor.cap_mm = Param[1], inter.exch.coeff_mm.d = Param[2], rout.stor.cap_mm = Param[3], unit.hyd.time.cons_d = Param[4])
write.csv(Param, 'onka_ERA5_gr4j_calib_param.csv', row.names = F, quote = F)


