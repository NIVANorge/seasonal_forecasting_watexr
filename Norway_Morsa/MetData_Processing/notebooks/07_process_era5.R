#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
options(java.parameters = "-Xmx8000m")
library(transformeR)
library(loadeR)
library(downscaleR)

# Unpack args
era5_nc <- args[1]
variables <- unlist(strsplit(args[2], split=","))
aggr.func <- unlist(strsplit(args[3], split=","))
lake_coords <- as.numeric(unlist(strsplit(args[4], split=',')))
lake <- list(x = lake_coords[1], y = lake_coords[2])

# Read ERA5 data and resample to daily
era5_daily <- lapply(1:length(variables), 
                     function(x) loadGridData(era5_nc, 
                                              var = variables[x],
                                              time = "DD",
                                              aggr.d = aggr.func[x]
                                             )
                     )

names(era5_daily) <- variables

# Convert units
era5_daily$tas$Data <- era5_daily$tas$Data - 273.15 # K to deg C
attr(era5_daily$tas$Variable, "units") <- "C"

era5_daily$tdps$Data <- era5_daily$tdps$Data - 273.15 # K to deg C
attr(era5_daily$tdps$Variable, "units") <- "C"

era5_daily$tp$Data <- era5_daily$tp$Data * 1000 # m to mm
attr(era5_daily$tp$Variable, "units") <- "mm"

era5_daily$rsds$Data <- era5_daily$rsds$Data / 86400 # J.m-2.day-1 to W.m-2
attr(era5_daily$rsds$Variable, "units") <- "W.m-2"

era5_daily$rlds$Data <- era5_daily$rlds$Data / 86400 # J.m-2.day-1 to W.m-2
attr(era5_daily$rlds$Variable, "units") <- "W.m-2"

# Bilinear interpolation to the location of the lake
era5_daily <- lapply(era5_daily, 
                     function(x) interpGrid(x, 
                                            new.coordinates = lake, 
                                            method = "bilinear", 
                                            bilin.method = "akima"
                                           )
                     )

# Save raw data
rdata_fold <- '/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/RData/'
save(era5_daily, 
     file = paste0(rdata_fold, 'era5_morsa_1980-2019_daily.rda'))

# Convert to CSV and save
dates <- era5_daily[[1]]$Dates
yymmdd <- as.Date(dates$start)
data <- lapply(era5_daily, function(x) x$Data)
df <- data.frame(c(list("dates" = yymmdd)), data)
 
data_fold <- '/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/06_era5/'
write.table(df, 
            paste0(data_fold, 'era5_morsa_1980-2019_daily.csv'), 
            sep = ",", 
            row.names = FALSE, 
            col.names = TRUE, 
            quote = FALSE
           )