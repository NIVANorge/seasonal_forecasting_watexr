library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster); library(rowr); library(RNetCDF)

setwd("/home/ry4902/Documents/ExampleTercile/")
season <- "autumn"
year <- 2018
database <- "SEAS5"

if(season=="winter"){season_list <-c(12,1,2); lead.month <- 10; season_num <- 1; rest_winter <- 1}else{rest_winter <- 0}
if(season=="spring"){season_list <- c(3:5); lead.month <- 2; season_num <- 2}
if (season=="summer"){season_list <- c(6:8); lead.month <- 5; season_num <- 3}
if(season=="autumn"){season_list <- c(9:11); lead.month <- 8; season_num <- 4}

#Opening observed data
temperature <- c()
for (depth in c(0,5,10, 15, 20,30,40,50)){
  my.data <-open.nc(paste(getwd(), "/ERAI_output/output.nc", sep=""))
  my.object <- var.get.nc(my.data, "temp") #[220, 3631]
  if (depth==0){
    temperature <- my.object[round(nrow(my.object)-(depth*220/60.54)),] #number of levels/lake depth
  }else{
    temperature <- cbind.fill(temperature, my.object[round(nrow(my.object)-(depth*220/60.54)),], fill = -9999)
  }
}
level <- var.get.nc(my.data, "zeta") #[220, 3631]
temperature <- cbind.fill(temperature, level, fill = -9999)
temperature <- data.frame(temperature, date=seq(as.Date('1988-01-01'), as.Date('2018-10-29'), by=1)) #adding dates for ERA-I running
colnames(temperature) <- c("temp0","temp5","temp10",
                           "temp15","temp20","temp30",
                           "temp40","temp50","level", "dates1")

# Opening Hindcast data
load(paste(getwd(), "/Hindcast/hindcastTercile.RData", sep=""))
winter <- data_total_season$winter
spring <- data_total_season$spring
summer <- data_total_season$summer
autumn <- data_total_season$autumn

# Opening Forecast data
load(paste(getwd(), "/Forecast/", season,"_", year,".RData", sep=""))

# Opening netcdf data templates
load(paste(getwd(), "/template_hindcast.RData", sep=""))
load(paste(getwd(), "/AtmosphereForecast/", season,"_", year,".RData", sep=""))
var.set_for <- subsetGrid(operative[[1]], season = season_list) 

obs.set <- var.set
obs.set$Data <- obs.set$Data[1,,,]
attr(obs.set$Data, "dimensions") <- c("time", "lat", "lon")
dates_obs_set <- data.frame(dates1=as.Date(obs.set$Dates$start))
merge_obs<-merge(dates_obs_set, temperature, by="dates1")
obs.set$InitializationDates<-NULL
obs.set$Members<-NULL
for (temp in c(2,4,6,7,8,9)){ #columns in merge dataframe 
  #2y19(1m), 4y21(10m), 6y23(20m), 7y24(30m), 8y25(40m), 9y26(50m)
  
  #Reanalisis or observation
  obs.set$Data[,1:4,1:5] <- merge_obs[,temp]
  attr(obs.set$Variable, "longname") <- paste("temperature profile", names(merge_obs)[temp], "m")
  
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
    var.set$Data[member_number,,1:4,1:5] <- merge_seasons[,(temp+17)]
  }
  attr(var.set$Variable, "longname") <- paste("temperature profile", names(merge_obs)[temp], "m")
  
  #Forecast
  for (member_number in c(1:51)){
    merge_seasons <- data_total_member[[member_number]]
    var.set_for$Data[member_number,,1:4,1:5] <- merge_seasons[,(temp+17)]
  }
  attr(var.set_for$Variable, "longname") <- paste("temperature profile", names(merge_obs)[temp], "m")
  
  pdf(paste(getwd(), "/Results/tercile_", database, "_" , season, "_", year, "_", names(merge_obs)[temp], ".pdf",sep=""))
  tercilePlot(subsetGrid(var.set, season=season_list), 
              subsetGrid(obs.set, season =season_list),
              var.set_for)
  dev.off()
  
  pdf(paste(getwd(), "/Results/time_", database, "_", season, "_", year, "_", names(merge_obs)[temp], ".pdf",sep=""),
      width = 15)
  print(temporalPlot(obs.set, var.set, var.set_for,
                     cols = c("black", "deepskyblue4", "red"), 
                     xyplot.custom =list(ylim=c(0,35),
                                         #xlim=c(as.Date("1987-12-01"), as.Date("2009-12-01")),
                                         ylab=paste("Temperature ",unlist(strsplit(names(merge_obs)[temp], "temp"))[2], 
                                                    "m (ºC)", sep=""))))
  dev.off()
  
}
