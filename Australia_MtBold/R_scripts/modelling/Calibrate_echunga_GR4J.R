setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GR4J\\Echunga")

library(airGR)
library(hydroGOF)

catch.area = 31.9

inp <- read.csv('input_data.csv')
inp$Date <- as.POSIXct(inp$Date, tz = 'UTC')
inp$flow.mm.day <- (inp$Débit..m3.s. *1000* (60*60*24)) / (catch.area *1000000)
inp.cal <- inp[(inp[,1] < '2008-01-01'),]
inp.val <- inp[(inp[,1] >= '2008-01-01' & inp[,1] <= '2010-12-31'),]

met <- read.delim('../../data/MtBold/CLIMATE/MtBold_DkIT_EWEMBI_observations_member01_day_19790101-20101231/meteo_file.dat')
met$DateTime <- as.POSIXct(met$DateTime, tz = 'UTC')

inputs <- CreateInputsModel(RunModel_GR4J, DatesR = met$DateTime, Precip = met$pr_mm, PotEvap = met$petH_mm.day.1)
## run period selection
Ind_Run <- which(met[,1] >= inp.cal[1,1] & met[,1] <= inp.cal[nrow(inp.cal),1])
warm_up <- 1:(Ind_Run[1]-1)
opts <- CreateRunOptions(RunModel_GR4J, InputsModel = inputs,IndPeriod_Run = Ind_Run, IndPeriod_WarmUp = warm_up)

Param = c(474.13, -2.65, 12.69, 0.5) #From Excel File

mod1 = RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = Param)
plot(mod1$DatesR, mod1$Qsim, type ='l', col =2)
lines(inp$Date, inp$Débit..mm.j.)
NSE(mod1$Qsim, inp.cal$Débit..mm.j.)

dim(inp)
str(inputs)
#Calibration
err_crit <- CreateInputsCrit(ErrorCrit_NSE, InputsModel = inputs, RunOptions = opts, Obs = inp.cal$flow.mm.day)

CalibOptions <- CreateCalibOptions(FUN_MOD = RunModel_GR4J, FUN_CALIB = Calibration_Michel)
str(CalibOptions)

OutputsCalib <- Calibration_Michel(InputsModel = inputs, RunOptions = opts, InputsCrit = err_crit, CalibOptions = CalibOptions, FUN_MOD = RunModel_GR4J)

Param <- OutputsCalib$ParamFinalR
Param #355.0413924  -1.5157529  13.8551754   0.5708907
#Param <- c(474.13,-2.65,12.69,0.5) #Param from excel

OutputsModel <- RunModel_GR4J(InputsModel = inputs, RunOptions = opts, Param = Param)
str(OutputsModel)

png('Echunga_GR4J_EWEMBI_Calib_results.png', height = 900, width = 1600, res =120)
plot(OutputsModel, Qobs = inp.cal$flow.mm.day)
dev.off()

NSE(OutputsModel$Qsim, inp.cal$flow.mm.day)
rmse(OutputsModel$Qsim, inp.cal$flow.mm.day)

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

NSE(OutputsModel2$Qsim, inp.val$flow.mm.day)
rmse(OutputsModel2$Qsim, inp.val$flow.mm.day)

err_crit <- CreateInputsCrit(ErrorCrit_NSE, InputsModel = inputs, RunOptions = opts, Obs = inp.val$flow.mm.day)

OutputsCrit <- ErrorCrit_NSE(InputsCrit = err_crit, OutputsModel = OutputsModel2)
OutputsCrit <- ErrorCrit_KGE(InputsCrit = err_crit, OutputsModel = OutputsModel2)
Param
Param <- data.frame(prod.stor.cap_mm = Param[1], inter.exch.coeff_mm.d = Param[2], rout.stor.cap_mm = Param[3], unit.hyd.time.cons_d = Param[4])
write.csv(Param, 'echunga_gr4j_calib_param.csv', row.names = F, quote = F)


