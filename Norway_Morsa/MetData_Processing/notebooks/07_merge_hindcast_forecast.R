#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
options(java.parameters = "-Xmx8000m")
library(transformeR)
library(loadeR)
library(downscaleR)

# Unpack args
variables <- unlist(strsplit(args[1], split=","))
model <- args[2]
season <- args[3]
mem_list <- as.integer(unlist(strsplit(args[4], split=':')))
members <- c(mem_list[1]:mem_list[2]) 

# Read data
rdata_fold <- '/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/RData/'

load(paste0(rdata_fold, 's5_morsa_', model, '_hindcast_', season, '.rda'))
hind <- data

load(paste0(rdata_fold, 's5_morsa_', model, '_forecast_', season, '.rda'))
fore <- data
    
# Merge
merge <- lapply(1:length(variables), 
                function(x) bindGrid(hind[[x]], 
                                     fore[[x]], 
                                     dimension = "time"
                                    )
                )

names(merge) <- variables

# Save raw data
save(merge, 
     file = paste0(rdata_fold, 's5_morsa_', model, '_merged_', season, '.rda'))

# Convert each meber to CSV and save
dates <- merge[[1]]$Dates
yymmdd <- as.Date(dates$start)

for (i in members) {
  # Build dataframe
  single.member <- lapply(merge, function(x) subsetGrid(x, members = i))
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
              paste0(data_fold, 's5_morsa_', model, '_merged_', season, '_', member, '.csv'), 
              sep = ",", 
              row.names = FALSE, 
              col.names = TRUE, 
              quote = FALSE
             )
}             