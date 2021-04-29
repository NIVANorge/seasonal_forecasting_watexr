library(transformeR); library(loadeR.ECOMS); library(loadeR); library(downscaleR);
library(lubridate); library(visualizeR); library(sp); library(rgdal); library(RNetCDF); 
library(sp); library(ncdf4); library(raster); library(drought4R); library(loadeR.2nc)

setwd("/home/ry4902/Documents/Workflow/Atmosphere/ERA5/pythonRequest")
di<- dataInventory("1988.nc")

year_list <- list(); var_list <- list(); c <- 0
for (n in names(di)){
  c<- c+1
  c1<-0
  for (y in 1988:2020){
    if (y==2019){
      c1 <- c1+1
      year_list_1.11 <- loadGridData(paste0(getwd(), "/", y, ".nc"), var = paste0(n, "_0001"), season = c(1:12)) #Tiene ERA5 en level=1 y ERA5T en level=5
      year_list_12 <- loadGridData(paste0(getwd(), "/", y, ".nc"), var = paste0(n, "_0005"), season = c(1:12)) #Tiene ERA5 en level=1 y ERA5T en level=5
      #year_list_12 <- loadGridData(paste0(getwd(), "/", y, "_ok.nc"), var = paste0(n, "@", 5), season = 12) #Tiene ERA5 en level=1 y ERA5T en level=5
      year_list[[c1]] <- bindGrid(list(year_list_1.11, year_list_12), dimension = c("time"))
    }else{
      c1 <- c1+1
      year_list[[c1]] <- loadGridData(paste(getwd(), "/", y, ".nc", sep=""), var = n)
    }
  }
  var_list[[c]] <- bindGrid(year_list, dimension = c("time"))
}
#hourly data:
ERA5_hourly <-  var_list
names(ERA5_hourly) <-  c("uas", "vas", "dp", "tas", "cc", "pr", "rsds", "rlds", "evap", "pet", "ps")

#daily data:
ERA5_daily <- lapply(1:length(ERA5_hourly), function(x) aggregateGrid(ERA5_hourly[[x]], aggr.d = list(FUN="mean", na.rm=T))) #na.rm es necesario porque algunas horas no tiene datos, esto sólo para el año 2019 que tiene ERA5 y ERA5T
names(ERA5_daily) <-  c("uas", "vas", "dp", "tas", "cc", "pr", "rsds", "rlds", "evap", "pet", "ps")

#aggregating properly some varibles using FUN=sum
ERA5_daily$tasmin <- aggregateGrid(ERA5_hourly$tas, aggr.d = list(FUN="min", na.rm=T))
ERA5_daily$tasmax <- aggregateGrid(ERA5_hourly$tas, aggr.d = list(FUN="max", na.rm=T))
ERA5_daily$pr <- aggregateGrid(ERA5_hourly$pr, aggr.d = list(FUN="sum", na.rm=T))#pr in m/d
ERA5_daily$evap <- aggregateGrid(ERA5_hourly$evap, aggr.d = list(FUN="sum", na.rm=T))
ERA5_daily$pet <- aggregateGrid(ERA5_hourly$pet, aggr.d = list(FUN="sum", na.rm=T))
ERA5_daily$rsds <- aggregateGrid(ERA5_hourly$rsds, aggr.d = list(FUN="sum", na.rm=T))
ERA5_daily$rlds <- aggregateGrid(ERA5_hourly$rlds, aggr.d = list(FUN="sum", na.rm=T))

#changing some units according to GOTM inputs:
ERA5_daily$rsds <- gridArithmetics(ERA5_daily$rsds, 86400, operator = "/" )
attr(ERA5_daily$rsds$Variable,"units") <- "W/m2"
ERA5_daily$rlds <- gridArithmetics(ERA5_daily$rlds, 86400, operator = "/" )
attr(ERA5_daily$rlds$Variable,"units") <- "W/m2"
ERA5_daily$tas <- gridArithmetics(ERA5_daily$tas, 273.15, operator = "-" )
attr(ERA5_daily$tas$Variable,"units") <- "ºC"
ERA5_daily$dp <- gridArithmetics(ERA5_daily$dp, 273.15, operator = "-" )
attr(ERA5_daily$dp$Variable,"units") <- "ºC"
ERA5_daily$tasmin <- gridArithmetics(ERA5_daily$tasmin, 273.15, operator = "-" )
attr(ERA5_daily$tasmin$Variable,"units") <- "ºC"
ERA5_daily$tasmax <- gridArithmetics(ERA5_daily$tasmax, 273.15, operator = "-" )
attr(ERA5_daily$tasmax$Variable,"units") <- "ºC"
ERA5_daily$ps <- gridArithmetics(ERA5_daily$ps, 100, operator = "/" )
attr(ERA5_daily$ps$Variable,"units") <- "hPa"
ERA5_daily$pr <- gridArithmetics(ERA5_daily$pr, 1000, operator = "*" )
attr(ERA5_daily$pr$Variable,"units") <- "mm/d"
ERA5_daily$evap <- gridArithmetics(ERA5_daily$evap, 1000, operator = "*" )
attr(ERA5_daily$evap$Variable,"units") <- "mm/d"
ERA5_daily$pet <- gridArithmetics(ERA5_daily$pet, 1000, operator = "*" )
attr(ERA5_daily$pet$Variable,"units") <- "mm/d"

names_watexr <- c("uas", "vas", "dp", "tas", "cc", "pr", "rsds", "rlds", "evap", "pet", "ps", "tasmin","tasmax")
for (v in 1:length(ERA5_daily)){
  ERA5_daily[[v]]$Variable$varName <- names_watexr[v]
}

units_copernicus <- c(); units_gotm <- c()
for (v in 1:11){
  units_copernicus <- c(units_copernicus, attr(ERA5_hourly[[v]]$Variable,"units"))
  units_gotm <- c(units_gotm, attr(ERA5_daily[[v]]$Variable,"units"))
}
data.frame(variable=names(ERA5_daily)[1:11], units_copernicus=units_copernicus, units_gotm=units_gotm)

for (p in 1:length(ERA5_daily)){
  pdf(paste(ERA5_daily[[p]]$Variable$varName, ".pdf", sep=""), width=15)
  print(temporalPlot(ERA5_daily[[p]]))
  dev.off()
}

#save(ERA5_hourly, file="/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_hourly.RData")
save(ERA5_daily, file="/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_daily.RData")

#Interpolation
# Bilinear interpolation of the data to the location of the lake
lake <- list(x = 2.3994, y = 41.9702) # SAU ot SQD
ERA5_daily.interp <- lapply(ERA5_daily, function(x) interpGrid(x, new.coordinates = lake, 
                                                               method = "bilinear", 
                                                               bilin.method = "akima"))

save(ERA5_daily.interp, file="/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_daily_Interpolated.RData")

#Plot spatial plots
load("/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_daily.RData")
Ter_basin <- readOGR("/home/ry4902/Documents/Workflow/River/Inputs_nhm-5.9/MorphologicalVar/DEM_Sources_Hydrosheds/Ter_basin_eu_bas_15s_beta.shp")

#for (p in 1:length(ERA5_daily)){
#  pdf(paste(ERA5_daily[[p]]$Variable$varName, ".pdf", sep=""))
 print(spatialPlot(climatology(ERA5_daily[[p]]),  sp.layout = list(Ter_basin, first = F, pch = 19, cex = 0.5 )))
#  dev.off()
#}

#Check with obseration
var <- "pr"
load("/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_daily_Interpolated.RData")
localdata <- loadStationData("/home/ry4902/Documents/Workflow/Atmosphere/ERA5/LoaderStations", var=var)

spatialPlot(climatology(localdata),  sp.layout = list(Ter_basin, first = F, pch = 19, cex = 0.5 ))
spatialPlot(climatology(ERA5_daily[[var]]),  sp.layout = list(Ter_basin, first = F, pch = 19, cex = 0.5 ))

Local_SAU <- subsetGrid(localdata, station.id = "V7_SAU")
if (var=="pr"){
  ERA5_SAU <- gridArithmetics(subsetGrid(ERA5_daily.interp[[var]], years = 1997:2006), 8.64e+7, operator = "*" )
}else{
  ERA5_SAU <- subsetGrid(ERA5_daily.interp[[var]], years = 1997:2006)
}


temporalPlot(ERA5_SAU, Local_SAU)
