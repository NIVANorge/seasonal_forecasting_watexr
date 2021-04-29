library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster); library(imputeTS)

low_date <- as.Date("1993-12-01") #Fecha limitada por las variables medidas atmosféricas
high_date <- as.Date("2016-11-30")

#START: Setting template to cheat-up discharge netcdf format and plot terciles
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/winter_BC.RData")
winter <- data.bc.cross
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/spring_BC.RData")
spring <- data.bc.cross
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/summer_BC.RData")
summer <- data.bc.cross
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/autumn_BC.RData")
autumn <- data.bc.cross
model_data <- lapply(1:length(winter), function(x) bindGrid(winter[[x]], spring[[x]], 
                                                            summer[[x]], autumn[[x]],
                                                            dimension = c("time")))

model_data[[1]]$Dates$start <- seq(as.Date(low_date), as.Date(high_date), by=1)
model_data[[1]]$Dates$end <- seq(as.Date(low_date), as.Date(high_date), by=1)
model_data[[1]]$Data <- model_data[[1]]$Data[,1:length(model_data[[1]]$Dates$end),,]
#model_data[[1]]$Data <- model_data[[1]]$Data[1,,,,]
#attr(model_data[[1]]$Data, "dimensions") <- c("member", "time", "lat", "lon")
template <- model_data[[1]]
attr(template$Data, "dimensions") <- c("member", "time", "lat", "lon")
#END: Setting template tp cheat-up dischrage netcdf and plot terciles

#START: Opening and setting discharge data using template created
load("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/simulated.RData")
for (m in 1:25){
  template$Data[m,,1:length(template$xyCoords$y),1:length(template$xyCoords$x)] <- as.numeric(total_simulated[[m]]$Qsim_0000000113)  #the tercile plot needs more than one pixel to run, all lat and lon will have the same discharge values (we are just cheating)
}
attr(template$Variable, "longname") <- "Discharge"
attr(template$Variable, "description") <- "Discharge from mHM model"
seafor <- template
#END: Opening and setting discharge data using template created

obs <- subsetGrid(template, members = 1)
total_simulated$member_1$Qobs_0000000113[which(total_simulated$member_1$Qobs_0000000113==-9999)] <- NA

obs$Data[,1:length(template$xyCoords$y),1:length(template$xyCoords$x)] <-  total_simulated$member_1$Qobs_0000000113

#Saving seas and obs

save(seafor, file="/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/HindcastTercile.RData")
save(obs, file="/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/ObservationTercile.RData")

#var.set <- subsetGrid(var.set, years = c(1983:2009)) 
#obs <- subsetGrid(obs, years = c(1983:2009)) 
#pdf("/home/ry4902/Documents/mhm-5.9_membersInitialized/System4/TotalOutputs/AllDates.pdf")
#tercilePlot(var.set, obs)
#dev.off()
years_plot <- 1994:2016
pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/winter-tercile.pdf")
tercilePlot(subsetGrid(seafor, season = c(12,1,2), years = years_plot), 
            subsetGrid(obs, season = c(12,1,2), years = years_plot))
dev.off()
pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/spring-tercile.pdf")
tercilePlot(subsetGrid(seafor, season = c(3:5), years = years_plot),
            subsetGrid(obs, season = c(3:5), years = years_plot))
dev.off()
pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/summer-tercile.pdf")
tercilePlot(subsetGrid(seafor, season = c(6:8), years = years_plot),
            subsetGrid(obs, season = c(6:8), years = years_plot))
dev.off()
pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/autumn-tercile.pdf")
tercilePlot(subsetGrid(seafor, season = c(9:11), years = years_plot),
            subsetGrid(obs, season = c(9:11), years = years_plot))
dev.off()

#Temporal plot
seas5 <- subsetGrid(seafor, years = years_plot)
Obs <- subsetGrid(obs, years = years_plot)
pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/temporalPlot.pdf",
    width=13)
temporalPlot(Obs, seas5, cols = c("black", "deepskyblue4"), 
             xyplot.custom=list(ylim=c(0,250), ylab="Discharge (m3/s)"))
dev.off()

#Cumulative Temporal plot
years_plot <- 2003
seas5 <- subsetGrid(seafor, years = years_plot)
seas5_cum <- seas5
for (m in 1:25){
  seas5_cum_ini <- seas5$Data[m,,1,1]*60*60*24/1e6 # m3/s -> hm3/day
  cumulative <- seas5_cum_ini[1]
  seas5_cum_new <- cumulative
  for (pos in 2:length(seas5_cum_ini)){
    cumulative <- cumulative+seas5_cum_ini[pos]
    seas5_cum_new <- c(seas5_cum_new, cumulative)
  }
  seas5_cum$Data[m,,1:6,1:9] <- seas5_cum_new
}

Obs <- subsetGrid(obs, years = years_plot)
Obs_cum <- Obs
Obs_cum_ini <- na_mean(Obs$Data[,1,1])*60*60*24/1e6 # m3/s -> hm3/day
cumulative <- Obs_cum_ini[1]
Obs_cum_new <- cumulative
for (pos in 2:length(Obs_cum_ini)){
  cumulative <- cumulative+Obs_cum_ini[pos]
  Obs_cum_new <- c(Obs_cum_new, cumulative)
}
Obs_cum$Data[,1:6,1:9] <- Obs_cum_new

pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/temporalPlot_cum.pdf",
    width=13)
temporalPlot(Obs_cum, seas5_cum, cols = c("black", "deepskyblue4"), 
             xyplot.custom=list(ylab="Cumulative Discharge (hm3)"))
dev.off()

#Plot one season and year for fig2
template_ini <- model_data[[1]]
attr(template_ini$Data, "dimensions") <- c("member", "time", "lat", "lon")
template_ini <- subsetGrid(template_ini, season = c(2,5,8,11))
load("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/initializers.RData")
for (m in 1:25){
  template_ini$Data[m,,1:6,1:9] <- as.numeric(total_initializers[[m]]$Qsim_0000000113)  #the tercile plot needs more than one pixel to run, all lat and lon will have the same discharge values (we are just cheating)
}
attr(template_ini$Variable, "longname") <- "Discharge"
attr(template_ini$Variable, "description") <- "Discharge from mHM model"
initializer <- template_ini

#Temporal plot
seas5 <- subsetGrid(seafor, years = 2003, season = c(3:5))
ini <- subsetGrid(initializer, years = 2003, season = 2)
#Obs <- subsetGrid(obs, years = years_plot)
pdf("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/temporalPlot_fig2.pdf",
    width=13)
temporalPlot(ini, seas5, cols = c("black", "deepskyblue4"), 
             xyplot.custom=list(xlim=c(as.Date("2003-01-01"), as.Date("2003-05-31")),ylim=c(0,70), ylab="Discharge (m3/s)"))
dev.off()
