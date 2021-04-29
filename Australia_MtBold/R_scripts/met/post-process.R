rea <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/interim075_WATExR_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_tasmax_tasmin_pr_rsds_rlds_hurs_cc_wss_BC.rda"))
obs <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_tasmax_tasmin_pr_rsds_rlds_hurs_cc_petH.rda"))
hind <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/System4_seasonal_15_2_3_4_5_uas_vas_ps_tas_pr_rsds_rlds_hurs_cc_petH_wss_BC.rda"))

library(Evapotranspiration)
library(lubridate)

# Call ET.HargreavesSamani under the generic function ET
lat_rad <- getCoordinates(rea$tas)$y * pi/180
constants = list("Elev" = 242, "lambda" = 2.45, "lat_rad" = lat_rad, "Gsc" = 0.082)
df <- data.frame(Year = year(rea$tasmax$Dates$start), Month = month(rea$tasmax$Dates$start), Day = day(rea$tasmax$Dates$start),Tmax = rea$tasmax$Data, Tmin = rea$tasmin$Data)
inp <- ReadInputs(varnames = c('Tmax', 'Tmin'), climatedata = df, constants = constants, stopmissing = c(10,5,5))
results <- ET.HargreavesSamani(inp, constants, ts="daily", message="yes", 
                               AdditionalStats="yes", save.csv="no")

#
petH <- rea$tasmax
petH$Data <- as.array(as.double(results$ET.Daily))
attr(petH$Variable, "longname") <- paste("potential_evapotranspiration_hargreaves_samani")
attr(petH$Variable, "description") <- paste("potential_evapotranspiration_hargreaves_samani")
petH$Variable$varName <- "petH"
attr(petH$Variable, "units") <- "mm.day-1"
attr(petH$Data, "dimensions") <- "time"
rea <- c(rea, "petH" = list(petH))

# Compute wss
wss <- obs$uas
wss$Data <- obs$uas$Data^2 + obs$vas$Data^2
# Define correctly the metadata of the object:
wss$Variable$varName <- "wss"
attr(wss$Variable,"units") <- "m s**-1"
attr(wss$Variable,"description") <- "Near-Surface Wind Speed"
attr(wss$Variable,"longname") <- "wss"
obs <- c(obs, "wss" = list(wss))

# petH <- petGrid(tasmin = rea$tasmin, tasmax = rea$tasmax, method = "hargreaves-samani")

temporalPlot("a" = redim(rea$tas, member = FALSE, loc = T))

# Check variable consistency
if (!all(names(obs) %in% names(hind))){
  message("variables in obs.data and data (seasonal forecast) do not match.")
  print(names(obs)[which(!(names(obs) %in% names(hind)))])
}
obs[['tasmin']] <- NULL
obs[['tasmax']] <- NULL
if (!all(names(rea) %in% names(hind))){
  message("variables in obs.data and data (seasonal forecast) do not match.")
  print(names(rea)[which(!(names(rea) %in% names(hind)))])
}
rea[['tasmin']] <- NULL
rea[['tasmax']] <- NULL



rea <- rea[match(names(rea), names(obs))]

names(rea)
names(obs)
names(hind)


range(rea$uas$Dates$start)
range(obs$uas$Dates$start)
range(hind$uas$Dates$start)

# Basic parameter definition (change this according to your experiment)
period <- 1982:2010
warmup.years <- 1

# Prepare c4r grid objects (temporal intersection of hind and obs):
hind <- lapply(hind, function(x) subsetGrid(x, years = period))
obs.sub <- lapply(1:length(obs), function(x)  {intersectGrid(obs[[x]], hind[[x]], type = "temporal", which.return = 1)})
names(obs.sub) <- names(rea)
names(hind) <- names(rea)
temporalPlot(obs.sub[[1]],  hind[[1]])

# Reanalysis months in the target year:
rea.season <- 1 : (getSeason(hind$uas)[1] - 1)

# Reanalysis years for each target year in period
wups <- lapply(period, function(x) seq(x - warmup.years, x - 1))

# Subset reanalysis data (for each variable = loop i) for the warmup years using object wups (loop x). 
# You will get a list (each element is a variable) containing other lists (each element is the grid fot the warmup of a particular year in object period.)
# rea$petH <- NULL
rea.wu <- lapply(1:length(rea), function(i){
  # print(names(rea)[i])
  # print(i)
  r <- rea[[i]]
  z <- lapply(wups, function(x){
    # print(x)
    subsetGrid(r, years = x)
  })
  if (sum(getSeason(hind$uas) - c(11, 12, 1, 2)) == 0) {
    lapply(1:length(z), function(k) {
      yy <- unique(getYearsAsINDEX(z[[k]]))
        if(length(yy) > 1) {
          one <- subsetGrid(z[[k]], years =  yy[-length(yy)])
          two <- subsetGrid(z[[k]], years =  yy[length(yy)], season = rea.season)
          bindGrid(one, two, dimension = "time")
        } else {
          subsetGrid(z[[k]], years =  yy[length(yy)], season = rea.season)
        }
    })
  } else {
    z
  }
})
names(rea.wu) <- names(rea)

# Subset reanalysis data for the target years (for each year in period)
rea.ty <- lapply(1:length(rea), function(i){
  r <- rea[[i]]
  lapply(period, function(x) subsetGrid(r, years = x, season = rea.season))
})
names(rea.ty) <- names(rea)

# Bind warmup and the target year for ranalysis:
warmup <- lapply(1:length(rea.wu), function(i){
  w <- rea.wu[[i]]
  t <- rea.ty[[i]]
  if (sum(getSeason(hind$uas) - c(11, 12, 1, 2)) != 0) {
    lapply(1:length(w), function(x) bindGrid(w[[x]], t[[x]], dimension = "time"))
  } else {
    w
  }
})
names(warmup) <- names(rea)

# check the remporal series If you want:
#temporalPlot(warmup$tas)

# Bind reanalysis and S4
fullserie <- lapply(1:length(warmup), function(i){
  wu <- warmup[[i]]
  hi <- hind[[i]]
  lapply(1:15, function(m) {
    h <- subsetGrid(hi, members = m)
    lapply(1:length(wu), function(x) {
      bindGrid(wu[[x]], subsetGrid(h, years = period[x]), dimension = "time")
    })
  })
})
names(fullserie) <- names(rea)


temporalPlot("tas" = fullserie$tas[[1]][[1]])


# EXPORT DATA -----------------------------------------------------------------------

output.dir.met <- "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\data\\output/"
# output.dir.swat <- "/home/maialen/Descargas/output/SWAT/"

dir.create(output.dir.met)
# dir.create(output.dir.swat)

dataset <- "System4"
datatoexport <- fullserie



# Save a single file for each member
for (i in 1:15) {
  for (n in 1:length(period)) {
    # Build data.frame for a single member
    memyear <- lapply(datatoexport, function(x) (x[[i]][[n]]))
    names(memyear) <- names(datatoexport)
    yymmdd <- as.Date(memyear[[1]]$Dates$start)
    hhmmss <- format(as.POSIXlt(memyear[[1]]$Dates$start), format = "%H:%M:%S") 
    datetime = paste(yymmdd, hhmmss)
    single.member <- lapply(memyear, function(x) redim(x, drop = TRUE)$Data)
    units <- lapply(memyear, function(x) attributes(x$Variable)$units)
    units$cc <- 'frac'
    cnams <- paste0(names(datatoexport),'_', units)
    # Remove unwanted variables
    # single.member["rsds"] <- NULL
    # single.member["rlds"] <- NULL
    # data.frame creation
    df <- data.frame(c(list("DateTime" = datetime), single.member))
    colnames(df) <- c("DateTime",cnams)
    if (i < 10) {
      member <- paste0("member0", i, sep = "", collapse = NULL)
    } else {
      member <- paste0("member", i, sep = "", collapse = NULL)
    }    
    startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
    endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
    dirName <- paste0(output.dir.met, "/", dataset, "_meteo_file_", startTime, "-", endTime, "_", member, "_", period[n], ".dat", sep = "", collapse = NULL)
    write.table(df, dirName, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
    # dirName <- paste0(output.dir.swat, "/", dataset, "_meteo_file_")
    # if ("tasmin" %in% colnames(df) & "tasmax" %in% colnames(df)){
    #   indmin <- which(colnames(df) == "tasmin")
    #   indmax <- which(colnames(df) == "tasmax")
    #   df1 <- df[, c(indmax, indmin)]
    #   df <- df[, -c(indmax, indmin)]
    #   df1.1 <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), paste0(df1[["tasmax"]], ",", df1[["tasmin"]])))
    #   write.table(df1.1, paste0(dirName, "tasmax_tasmin_",startTime, "-", endTime, "_", member, "_", period[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
    # }
    # for (v in 3:ncol(df)) {
    #   df.v <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), df[[colnames(df)[v]]]))
    #   write.table(df.v, paste0(dirName, colnames(df)[v], "_",startTime, "-", endTime, "_", member, "_", period[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
    # }
  }
}




##########CREATE THE SAME SERIES FOR THE OBSERVATION##########################################################################

obs <- get(load("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_tasmax_tasmin_pr_rsds_rlds_hurs_cc_petH.rda"))

obs.sub <- lapply(obs, function(x) subsetGrid(x, years = period))
names(obs.sub) <- names(obs)

# prepare warm-up period
wups <- lapply(period, function(x) seq(x - warmup.years, x - 1))

obs.wu <- lapply(1:length(obs), function(i){
  r <- obs[[i]]
  lapply(wups, function(x) subsetGrid(r, years = x))
})
names(obs.wu) <- names(obs)

obs.ty <- lapply(1:length(obs), function(i){
  r <- obs[[i]]
  if (sum(getSeason(hind$uas) - c(11, 12, 1, 2)) != 0) {
    lapply(period, function(x) subsetGrid(r, years = x, season = c(rea.season, getSeason(hind$uas))))  
  } else {
    lapply(period, function(x) subsetGrid(r, years = x, season = c(1:2)))  
  }
  
})
names(obs.ty) <- names(obs)

warmup <- lapply(1:length(obs.wu), function(i){
  w <- obs.wu[[i]]
  t <- obs.ty[[i]]
  lapply(1:length(w), function(x) bindGrid(w[[x]], t[[x]], dimension = "time"))
})
names(warmup) <- names(obs)

fullserie <- warmup


####### EXPORT DATA ----------------------------------------

dataset <- "PIK_Obs-EWEMBI"
datatoexport <- fullserie

member <- "member01"

# Save a single file for each member

for (n in 1:length(period)) {
  # Build data.frame for a single member
  memyear <- lapply(datatoexport, function(x) (x[[n]]))
  names(memyear) <- names(datatoexport)
  yymmdd <- as.Date(memyear[[1]]$Dates$start)
  hhmmss <- format(as.POSIXlt(memyear[[1]]$Dates$start), format = "%H:%M:%S") 
  datetime = paste(yymmdd, hhmmss)
  single.member <- lapply(memyear, function(x) redim(x, drop = TRUE)$Data)
  units <- lapply(memyear, function(x) attributes(x$Variable)$units)
  units$cc <- 'frac'
  cnams <- paste0(names(datatoexport),'_', units)
  # Remove unwanted variables
  # single.member["rsds"] <- NULL
  # single.member["rlds"] <- NULL
  # data.frame creation
  df <- data.frame(c(list("DateTime" = datetime), single.member))
  colnames(df) <- c("DateTime",cnams)
  startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
  endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
  dirName <- paste0(output.dir.met, "/", dataset, "_meteo_file_", startTime, "-", endTime, "_", member, "_", period[n], ".dat", sep = "", collapse = NULL)
  write.table(df, dirName, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
  # dirName <- paste0(output.dir.swat, "/", dataset, "_meteo_file_")
  # if ("tasmin" %in% colnames(df) & "tasmax" %in% colnames(df)) {
  #   indmin <- which(colnames(df) == "tasmin")
  #   indmax <- which(colnames(df) == "tasmax")
  #   df1 <- df[, c(indmax, indmin)]
  #   df <- df[, -c(indmax, indmin)]
  #   df1.1 <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), paste0(df1[["tasmax"]], ",", df1[["tasmin"]])))
  #   write.table(df1.1, paste0(dirName, "tasmax_tasmin_", startTime, "-", endTime, "_", member, "_", period[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
  # }
  # for (v in 3:ncol(df)) {
  #   df.v <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), df[[colnames(df)[v]]]))
  #   write.table(df.v, paste0(dirName, colnames(df)[v], "_",startTime, "-", endTime, "_", member, "_", period[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
  # }
}


# Save one file with complete obs
# Build data.frame for a single member
memyear <- obs
yymmdd <- as.Date(memyear[[1]]$Dates$start)
hhmmss <- format(as.POSIXlt(memyear[[1]]$Dates$start), format = "%H:%M:%S") 
datetime = paste(yymmdd, hhmmss)
single.member <- lapply(memyear, function(x) redim(x, drop = TRUE)$Data)
units <- lapply(memyear, function(x) attributes(x$Variable)$units)
units$cc <- 'frac'
cnams <- paste0(names(obs),'_', units)
# Remove unwanted variables
# single.member["rsds"] <- NULL
# single.member["rlds"] <- NULL
# data.frame creation
df <- data.frame(c(list("DateTime" = datetime), single.member))
colnames(df) <- c("DateTime",cnams)
startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
dirName <- paste0(output.dir.met, "/", dataset, "_all_meteo_file_", startTime, "-", endTime, "_", member, ".dat", sep = "", collapse = NULL)
write.table(df, dirName, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)

