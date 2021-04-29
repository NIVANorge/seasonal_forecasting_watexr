library(transformeR); library(loadeR.ECOMS); library(loadeR); library(downscaleR);
library(lubridate); library(visualizeR); library(sp); library(rgdal); library(RNetCDF); 
library(sp); library(ncdf4); library(raster); library(drought4R); library(loadeR.2nc)

lake_lon <- c(2,2.5)
lake_lat <- c(41.80,42.3)
# Opening Model data
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/winter_BC.RData")
winter <- data.bc.cross
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/spring_BC.RData")
spring <- data.bc.cross
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/summer_BC.RData")
summer <- data.bc.cross
load("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_TerRiver/autumn_BC.RData")
autumn <- data.bc.cross
model_data <- lapply(1:length(winter), function(x) bindGrid(subsetGrid(winter[[x]], season=c(12,1,2)),
                                                            subsetGrid(spring[[x]], season=c(3:5)), 
                                                            subsetGrid(summer[[x]], season=c(6:8)), 
                                                            subsetGrid(autumn[[x]], season=c(9:11)),
                                                            dimension = c("time")))
names(model_data) <- c("pr","tas","pet")

leadMonth_data <- lapply(1:length(winter), function(x) list(subsetGrid(winter[[x]], season=c(11)),
                                                            subsetGrid(spring[[x]], season=c(2)), 
                                                            subsetGrid(summer[[x]], season=c(5)), 
                                                            subsetGrid(autumn[[x]], season=c(8))) )

names(leadMonth_data) <- c("pr","tas","pet")

# Opening observation data
load("/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_daily.RData")
n_var <- names(ERA5_daily)
ERA5_daily <- lapply(1:length(ERA5_daily), function(x) subsetGrid(ERA5_daily[[x]], years = c(1988:2018)) )
names(ERA5_daily) <- n_var
ERA5_daily$pr$Data[which(ERA5_daily$pr$Data<0)] <- 0
#ERA5_daily$pr <- gridArithmetics(ERA5_daily$pr, 1000*86400, operator = "*") # m/s to mm/day
#attr(ERA5_daily$pr$Variable, "units") <- "mm.day-1"
data_obs <- list(pr=ERA5_daily$pr, tas=ERA5_daily$tas, pet=petGrid(tasmin = ERA5_daily$tasmin, tasmax = ERA5_daily$tasmax, method = "hargreaves-samani"))

morpho_res <- raster(xmn=410000, xmx=410000+5*10000, ymn=4620000, ymx=4620000+8*10000, resolution=c(10000,10000))
lat_utm <- seq(morpho_res@extent@ymin, morpho_res@extent@ymax, 10000); lat_utm_mean <-c()
for (ylat in 1:(length(lat_utm)-1) ){lat_utm_mean <-  c(lat_utm_mean, mean(c(lat_utm[ylat+1], lat_utm[ylat])))}
lon_utm <- seq(morpho_res@extent@xmin, morpho_res@extent@xmax, 1e+04); lon_utm_mean <-c()
for (ylat in 1:(length(lon_utm)-1) ){lon_utm_mean <-  c(lon_utm_mean, mean(c(lon_utm[ylat+1], lon_utm[ylat])))}
source("/home/ry4902/Documents/Workflow/River/Inputs_nhm-5.9/MeteorologicalVar/grid2ncUTM.R")

database <- "SEAS5"
reanalisis <- "ERA5"

setwd(paste("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/", database, "/", reanalisis,"/Hindcast", sep=""))

#Opening latitude and longitud corrdinates
load("/home/ry4902/Documents/Workflow/River/Inputs_nhm-5.9/MeteorologicalVar/coord_save.rda")

total_simulated <- list(); total_initializers <- list()
for (member_number in 1:25){
  initializers <- c(); simulated <- c()
  for (year in c(1994:2016)){
    spinup <- 1825 #se hizo el test con el condicional de abajo y los resultados no cambian significativamente osea que este tiempo (5 años) de warm-up es suficiente
    #if (year %in% c(1994,1995)){ 
    #  spinup <- 2160
    #}else if(year %in% c(1996:2001)){
    #  spinup <- 2890
    #  } else{spinup <- 5000}
      
    for (season in list(c(12,1,2), c(3:5), c(6:8), c(9:11))){
      if(unique(season==c(12,1,2))){lead.month <- 11; season_num <- 1; rest_winter <- 1}else{rest_winter <- 0}
      if(unique(season==c(3:5))){lead.month <- 2; season_num <- 2}
      if(unique(season==c(6:8))){lead.month <- 5; season_num <- 3}
      if(unique(season==c(9:11))){lead.month <- 8; season_num <- 4}
      
      for (variable in c("tas", "pet", "pr")){
        
        if(variable=="tas"){variable_save <- "tavg"}
        if(variable=="pet"){variable_save <- "pet"}
        if(variable=="pr"){variable_save <- "pre"}
        
        #Setting observational data
        var.new_obs <- data_obs[[variable]]
        var.new_obs$Dates$start <- paste(as.Date(var.new_obs$Dates$start), "00:00:00 GMT")
        var.new_obs$Dates$end <- paste(as.Date(var.new_obs$Dates$start), "00:00:00 GMT")
      
        #Setting seasonal forecasting data for specific year, season and member
        var.new <- model_data[[variable]]
        var.new_exact <- subsetGrid(var.new, years = year, season = season, members = member_number)
        target_date <- var.new_exact$Dates$start[1]
        position_date <- match(as.Date(target_date), as.Date(var.new_obs$Dates$start))#porque no hay datos observados en el dia exacto, se pone un mes antes porsiaca
        var.new_exact$Dates$start <- paste(as.Date(var.new_exact$Dates$start), "00:00:00 GMT")
        var.new_exact$Dates$end <- paste(as.Date(var.new_exact$Dates$start), "00:00:00 GMT")
        
        #Selecting lead month
        leadmonth_selected <- subsetGrid(leadMonth_data[[variable]][[season_num]], years = (year-rest_winter), members = member_number)
        leadmonth_selected$Dates$start <- paste(as.Date(leadmonth_selected$Dates$start), "00:00:00 GMT")
        leadmonth_selected$Dates$end <- paste(as.Date(leadmonth_selected$Dates$start), "00:00:00 GMT")
        days_before_target_date <- length(leadmonth_selected$Dates$start)
        
        #Selecting observation data: warm-up (xx days before targe season, then lead month, then seasonal forecast)
        obs_selected <- var.new_obs
        pos_obs <- (position_date-spinup):(position_date-days_before_target_date-1)
        obs_selected$Data <- obs_selected$Data[pos_obs,,]
        obs_selected$Dates$start <- obs_selected$Dates$start[pos_obs]
        obs_selected$Dates$end <- obs_selected$Dates$end[pos_obs]
        attr(obs_selected$Data, "dimensions") <- c("time", "lat", "lon")
        
        total_var <- bindGrid(obs_selected, leadmonth_selected, var.new_exact, dimension = c("time"))
        total_var <- subsetGrid(total_var, lonLim = lake_lon, latLim = lake_lat )
        data_array <- total_var$Data
        data_array_save <- array(data = NA, dim = c(length(total_var$Dates$start), 8, 5))
        
        #Primera longitude[lat, lon] OJO PONER PRIMERO SUBSETGRID ARRIBA
        data_array_save[,1:2,1] <- data_array[,1,1] #11323     5     9
        data_array_save[,3:5,1] <- data_array[,2,1]
        data_array_save[,6:8,1] <- data_array[,3,1]
        
        #2-4 longitude
        data_array_save[,1:2,2:4] <- data_array[,1,2]
        data_array_save[,3:5,2:4] <- data_array[,2,2]
        data_array_save[,6:8,2:4] <- data_array[,3,2]
        
        #5ta longitude
        data_array_save[,1:2,5] <- data_array[,1,3]
        data_array_save[,3:5,5] <- data_array[,2,3]
        data_array_save[,6:8,5] <- data_array[,3,3]
        
        attr(data_array_save, "dimensions") <- c("time", "lat", "lon")
        
        total_var_ok <- loadGridData("/home/ry4902/Documents/Workflow/River/Inputs_nhm-5.9/MeteorologicalVar/FromCDO/netcdf_template.nc",  var="tavg")
        total_var_ok$Dates$start <- total_var$Dates$start
        total_var_ok$Dates$end <- total_var$Dates$end
        total_var_ok$xyCoords$x <- unique(coord_save[,1])
        total_var_ok$xyCoords$y <- unique(coord_save[,2])
        attr(total_var_ok$xyCoords, "projection") <- "+proj=utm +zone=31 +datum=WGS84 +units=m +no_defs"
        total_var_ok$Variable$varName <- variable_save 
        attr(total_var_ok$Variable, "longname") <- variable_save 
        attr(total_var_ok$Variable, "description") <- variable_save 
        if (variable=="pr"){
          data_array_save[which(data_array_save<0)] <- 0
        }
        if (variable=="pet"){
          data_array_save[which(data_array_save<0)] <- 0
        }
        total_var_ok$Data <- data_array_save

        grid2ncUTM(total_var_ok, NetCDFOutFile = paste(getwd(), "/input/meteo/", variable_save,"/", variable_save, ".nc", sep=""),
                   lon = lon_utm_mean, lat = lat_utm_mean)
      }
      #Changins mhm.nml file according to start and end dates
      mhm_file  <- readLines(paste(getwd(),"/mhm.nml", sep=""))
      mhm_file[488] <- paste("warming_Days(1) =",  spinup-31) #paste("warming_Days(1) =",  (spinup-50))
      mhm_file[491] <- paste("eval_Per(1)%yStart =",  year(as.Date(target_date)-days_before_target_date))
      mhm_file[494] <- paste("eval_Per(1)%mStart =",  month(as.Date(target_date)-days_before_target_date))
      mhm_file[497] <- paste("eval_Per(1)%dStart =",  day(as.Date(target_date)-days_before_target_date))
      end_day <- as.Date(total_var$Dates$start[length(total_var$Dates$start)])
      mhm_file[500] <- paste("eval_Per(1)%yEnd =",  year(end_day))
      mhm_file[503] <- paste("eval_Per(1)%mEnd =",  month(end_day))
      mhm_file[506] <- paste("eval_Per(1)%dEnd =",  day(end_day))
      writeLines(mhm_file, con=paste(getwd(),"/mhm.nml", sep=""))
      
      #Running mHM model
      system("./mhm")
      
      #Saving discharge results from mHM model
      daily_discharge <- read.csv(paste(getwd(), "/output_b1/daily_discharge.out", sep=""),
                                  sep="", stringsAsFactors = F)
      if(length(which(is.na(daily_discharge$Qsim_0000000113)))==0){
        print("NO HAY NAs")
      }else{write.csv(daily_discharge, paste(getwd(), "/output_b1/daily_discharge_OJO",
                                             year, member_number, season_num,".txt", sep=""),
                      sep="", stringsAsFactors = F)}
      initializers <- rbind(initializers, daily_discharge[1:days_before_target_date,])
      simulated <- rbind(simulated, daily_discharge[(days_before_target_date+1):nrow(daily_discharge),])
    }
  }
  total_simulated[[paste("member", member_number, sep = "_")]] <- simulated
  total_initializers[[paste("member", member_number, sep = "_")]] <- initializers
}

save(total_simulated, file =paste(getwd(), "/TotalOutputs/simulated.RData", sep=""))
save(total_initializers, file = paste(getwd(), "/TotalOutputs/initializers.RData", sep=""))
