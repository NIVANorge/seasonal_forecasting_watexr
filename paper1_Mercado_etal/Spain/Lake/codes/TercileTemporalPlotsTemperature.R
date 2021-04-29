library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster); library(rowr); library(RNetCDF)

database <- "SEAS5"
reanalisis <- "ERA5"

#Opening observed data
temperature <- c(); temperature_ok <- c()
for (depth in c(0,5,10, 15, 20,30,40,50)){
  my.data <-open.nc(paste0("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Reanalisis/", reanalisis, "/output.nc"))
  my.data_ok <- open.nc(paste0("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Reanalisis/ERA5/CalibrationValidation/output_all.nc"))
  my.object <- var.get.nc(my.data, "temp") #[220, 3631]
  my.object_ok <- var.get.nc(my.data_ok, "temp") #[220, 3631]
  temperature <- cbind(temperature, my.object[round(nrow(my.object)-(depth*120/60)),])
  temperature_ok <- cbind(temperature_ok, my.object_ok[round(nrow(my.object_ok)-(depth*120/60)),])
  #if (depth==1){
    #temperature <- my.object[round(nrow(my.object)-(depth*120/60)),]
  #}else{
  #  temperature <- cbind.fill(temperature, my.object[round(nrow(my.object)-(depth*120/60)),], fill = -9999)
  #}
  #data_total <- cbind.fill(data_total, temperature, fill = -9999)
  #names_data <- c(names_data, paste("temp", depth, sep=""))
}
level <- var.get.nc(my.data, "zeta") #[220, 3631]
temperature <- cbind.fill(temperature, level, fill = -9999)
temperature <- data.frame(temperature, date=seq(as.Date('1988-01-01'), as.Date('2018-10-28'), by=1))
level_ok <- var.get.nc(my.data_ok, "zeta") #[220, 3631]
temperature_ok <- cbind.fill(temperature_ok, level_ok, fill = -9999)
temperature_ok <- data.frame(temperature_ok, date=seq(as.Date('1988-01-01'), as.Date('2018-07-23'), by=1))
colnames(temperature_ok) <- c("temp0","temp5","temp10",
                           "temp15","temp20","temp30",
                           "temp40","temp50","level", "dates1")

# Opening Hindcast data
load(paste("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Forecast/Hindcast/", database, reanalisis,"/Output/data_total_season.RData", sep="/"))
winter <- data_total_season$winter
spring <- data_total_season$spring
summer <- data_total_season$summer
autumn <- data_total_season$autumn

# Opening netcdf data template
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/winter_BC.RData")
winter1 <- lapply(1:length(data.bc.cross), function(x) subsetGrid(data.bc.cross[[x]], season = c(12,1,2)))
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/spring_BC.RData")
spring1 <- lapply(1:length(data.bc.cross), function(x) subsetGrid(data.bc.cross[[x]], season = c(3:5)))
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/summer_BC.RData")
summer1 <- lapply(1:length(data.bc.cross), function(x) subsetGrid(data.bc.cross[[x]], season = c(6:8)))
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/autumn_BC.RData")
autumn1 <- lapply(1:length(data.bc.cross), function(x) subsetGrid(data.bc.cross[[x]], season = c(9:11)))
model_data <- lapply(1:length(winter1), function(x) bindGrid(winter1[[x]], spring1[[x]], 
                                                             summer1[[x]], autumn1[[x]],
                                                             dimension = c("time")))
var.set <- model_data[[1]]
obs.set <- var.set
obs.set$Data <- obs.set$Data[1,,,]
attr(obs.set$Data, "dimensions") <- c("time", "lat", "lon")
dates_obs_set <- data.frame(dates1=as.Date(obs.set$Dates$start))
merge_obs<-merge(dates_obs_set, temperature_ok, by="dates1")
obs.set$InitializationDates<-NULL
obs.set$Members<-NULL
for (temp in c(0,5,10, 15, 20,30,40,50)){ #columns in merge dataframe 
  #2y19(1m), 4y21(10m), 6y23(20m), 7y24(30m), 8y25(40m), 9y26(50m)
  
  #Reanalisis or observation
  obs.set$Data[,1:dim(obs.set$Data)[2],1:dim(obs.set$Data)[3]] <- merge_obs[,paste0("temp",temp)]
  
  #Hindcast 
  for (member_number in c(1:25)){
    winter_ok <- winter[[member_number]][which(month(as.Date(winter[[member_number]]$dates1)) %in% c(12,1,2)),]
    spring_ok <- spring[[member_number]][which(month(as.Date(spring[[member_number]]$dates1)) %in% c(3:5)),]
    summer_ok <- summer[[member_number]][which(month(as.Date(summer[[member_number]]$dates1)) %in% c(6:8)),]
    autumn_ok <- autumn[[member_number]][which(month(as.Date(autumn[[member_number]]$dates1)) %in% c(9:11)),]
    
    all_seasons <- rbind(winter_ok, spring_ok, summer_ok, autumn_ok)
    all_seasons_ok <- all_seasons[order(as.Date(all_seasons$dates1, format="%Y-%m-%d")),]
    all_seasons_ok$dates1<-as.Date(all_seasons_ok$dates1)
    
    dates_var_set <- data.frame(dates1=as.Date(var.set$Dates$start))
    merge_seasons<-merge(dates_var_set, all_seasons_ok, by="dates1", all=TRUE)
    var.set$Data[member_number,,1:dim(var.set$Data)[3],1:dim(var.set$Data)[4]] <- merge_seasons[,paste0("temp",temp)]
  }
  attr(obs.set$Variable, "longname") <- paste("temperature profile", "temp", temp, "m")
  attr(var.set$Variable, "longname") <- paste("temperature profile", "temp", temp, "m")
  
  save(var.set, file=paste0("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_SAU_SQD/OtherSkills/Hind_temp_",temp,"m.RData"))
  save(obs.set, file=paste0("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_SAU_SQD/OtherSkills/Obs_temp_",temp,"m.RData"))
  
  
  season_list <- 9:11

  #pdf(paste("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Forecast/Forecast/",database,"/",reanalisis, "/Output/", season, "_", year, names(merge_obs)[temp], ".pdf",sep=""))
  tercilePlot(subsetGrid(var.set, season=season_list), 
              subsetGrid(obs.set, season =season_list))
  #dev.off()
  
  #pdf(paste("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Forecast/",database, "/", reanalisis, "/Output/temp_", season, "_", year, names(merge_obs)[temp], ".pdf",sep=""),width = 15)
  print(temporalPlot(obs.set, var.set, var.set_for,
                     cols = c("black", "deepskyblue4", "red"), 
                     xyplot.custom =list(ylim=c(0,35),
                                         #xlim=c(as.Date("1987-12-01"), as.Date("2009-12-01")),
                                         ylab=paste("Temperature ",unlist(strsplit(names(merge_obs)[temp], "temp"))[2], 
                                                    "m (ºC)", sep=""))))
  #dev.off()
  
}


#Forecast
season <- "spring"
year <- 2020

if(season=="winter"){season_list <-c(12,1,2); lead.month <- 10; season_num <- 1; rest_winter <- 1}else{rest_winter <- 0}
if(season=="spring"){season_list <- c(3:5); lead.month <- 2; season_num <- 2}
if (season=="summer"){season_list <- c(6:8); lead.month <- 5; season_num <- 3}
if(season=="autumn"){season_list <- c(9:11); lead.month <- 8; season_num <- 4}

# Opening Forecast data
load(paste("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Forecast/Forecast/", database, "/",reanalisis,"/Output/", season,"_", year,".RData", sep=""))

#Template forecast
load(paste("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/Operational/BC_ERA5_TerRiver/", season,"_", year,".RData", sep=""))
operative <- data.bc.cross
var.set_for <- subsetGrid(operative[[1]], season = season_list) 

for (temp in c(0,5,10,15,20,30,40,50)){ 
  #Forecast members
  for (member_number in c(1:25)){
    merge_seasons <- data_total_member[[member_number]]
    var.set_for$Data[member_number,,1:dim(var.set_for$Data)[3],1:dim(var.set_for$Data)[4]] <- merge_seasons[,paste0("temp",0)]
  }
}
attr(var.set_for$Variable, "longname") <- paste("temperature profile", "temp", temp, "m")

tercilePlot(subsetGrid(var.set, season=season_list), 
            subsetGrid(obs.set, season =season_list),
            var.set_for)