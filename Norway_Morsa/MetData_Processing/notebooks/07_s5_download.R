#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
options(java.parameters = "-Xmx8000m")
library(transformeR)
library(loadeR)
library(downscaleR)

# Unpack args
url <- args[1]
variables <- unlist(strsplit(args[2], split=","))
mem_list <- as.integer(unlist(strsplit(args[3], split=':')))
members <- c(mem_list[1]:mem_list[2])                   
lonLim <- as.numeric(unlist(strsplit(args[4], split=',')))
latLim <- as.numeric(unlist(strsplit(args[5], split=',')))
season <- as.integer(unlist(strsplit(args[6], split=',')))
year_list = as.integer(unlist(strsplit(args[7], split=':')))
years <- c(year_list[1]:year_list[2])
lead.month <- as.integer(args[8])
aggr.func <- unlist(strsplit(args[9], split=","))
lake_coords <- as.numeric(unlist(strsplit(args[10], split=',')))
lake <- list(x = lake_coords[1], y = lake_coords[2])
period <- args[11]
model <- args[12]
season_name <- args[13]
cdsDic <- 'SYSTEM5_ecmwf_Seasonal_25Members_SFC.dic'

# Login
loginUDG("WATExR", "1234567890")
                           
# Get seasonal forecast data
data.prelim <- lapply(1:length(variables), 
                      function(x) loadSeasonalForecast(url, 
                                                       variables[x], 
                                                       dictionary = cdsDic,
                                                       members = members,
                                                       lonLim = lonLim, 
                                                       latLim = latLim, 
                                                       season = season, 
                                                       years = years,
                                                       leadMonth = lead.month, 
                                                       time = "DD", 
                                                       aggr.d = aggr.func[x], 
                                                      )
                      )   

names(data.prelim) <- variables

# Bilinear interpolation of the S5 data to the location of the lake
data <- lapply(data.prelim, 
               function(x) interpGrid(x, 
                                      new.coordinates = lake, 
                                      method = "bilinear", 
                                      bilin.method = "akima"
                                     )
               )
                           
# Save raw data
rdata_fold <- '/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/RData/'
save(data, 
     file = paste0(rdata_fold, 's5_morsa_', model, '_', period, '_', season_name, '.rda'))
                                                        
# Convert each member to CSV and save
dates <- data[[1]]$Dates
yymmdd <- as.Date(dates$start)

for (i in members) {
  # Build dataframe
  single.member <- lapply(data, function(x) subsetGrid(x, members = i))
  single.member <- lapply(single.member, function(x) x$Data)
  df <- data.frame(c(list("dates" = yymmdd)), single.member)
                          
  # Save
  if (i < 10) {
    member <- paste0("member0", i, sep = "", collapse = NULL)
  } else {
    member <- paste0("member", i, sep = "", collapse = NULL)
  }    
  data_fold <- '/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/07_s5_seasonal/'
  write.table(df, 
              paste0(data_fold, 's5_morsa_', model, '_', period, '_', season_name, '_', member, '.csv'), 
              sep = ",", 
              row.names = FALSE, 
              col.names = TRUE, 
              quote = FALSE
             )
}                          