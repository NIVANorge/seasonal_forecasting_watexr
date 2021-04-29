library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(visualizeR)
library(drought4R); library(convertR)
lonLim <- c(1.5, 3.5) # Or just a point, in this case the interpolation using interpGrid function is not required (but will work even if applying interpGrid)
latLim <- c(41.3, 42.7)
dataset <- "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_Seasonal_25Members_SFC.ncml"
dictionary <- "/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/SYSTEM5_ecmwf_Seasonal_25Members_SFC.dic"
years <- c(1994:2016)
lead.month <- 0
season <- c(2:5)
lake <- list(x = 2.3994, y = 41.9702) # SAU ot SQD
loginUDG("WATExR", "1234567890")
#di <- dataInventory(dataset)
variables <- c("evaporation","uas", "vas", "psl", "tas", 
               "tp", "rsds", "rlds", "tdps", "tcc", "tas", "tas") #tdps=dew point, tp=total precipitation, slp=pressure, evspsbl=evaporation
aggr.fun <- c("mean", "mean", "mean", "mean", "mean", "sum", 
              "mean", "mean", "mean", "mean", "max", "min")
# Define daily aggregation function for each variable selected
loginUDG("WATExR", "1234567890")
spring <- lapply(1:length(variables), function(x) loadSeasonalForecast(dataset, dictionary = dictionary,
                                                                       var = variables[x], years = years, 
                                                                       leadMonth = lead.month, #members = mem,
                                                                       lonLim = lonLim, latLim = latLim, 
                                                                       season = season, time = "DD", aggr.d = aggr.fun[x]))
names(spring) <- c(variables[1:10], "tasmax", "tasmin")
spring$tas <- udConvertGrid(spring$tas, new.units = "celsius")
spring$tasmin <- udConvertGrid(spring$tasmin, new.units = "celsius")
spring$tasmax <- udConvertGrid(spring$tasmax, new.units = "celsius")
spring$psl <- udConvertGrid(spring$psl, new.units = "millibars")
spring$petH<-petGrid(tasmin=spring$tasmin, tasmax=spring$tasmax, method = "hargreaves-samani")
directory <- "/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/"
save(spring, file=paste(directory, "spring.RData", sep=""))

# Bilinear interpolation of the data to the location of the lake
spring.interp <- lapply(spring, function(x) interpGrid(x, new.coordinates = lake, 
                                                       method = "bilinear", 
                                                       bilin.method = "akima"))

save(spring.interp, file=paste(directory, "Interpolation/spring.RData", sep=""))
