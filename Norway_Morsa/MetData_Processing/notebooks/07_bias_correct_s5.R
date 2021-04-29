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

# Read S5 and ERA5 data
rdata_fold <- '/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/RData/'
load(paste0(rdata_fold, 's5_morsa_', model, '_merged_', season, '.rda'))
data <- merge

load(paste0(rdata_fold, 'era5_morsa_1980-2019_daily.rda'))

# Subset all datasets to the same dates as the S5 precipitation.
# I don't fully understand this code yet, but it's taken from here:
#     https://github.com/icra/WATExR/blob/61fc3fa31914b5a7447723cd2ed50df4af277b16/R/seasonalForecast.R#L158
if (sum(names(data)=="tp") > 0){
  data <- lapply(1:length(data), 
                 function(x)  {intersectGrid(data[[x]], 
                                             data[[which(names(data) == "tp")]], 
                                             type = "temporal", 
                                             which.return = 1
                                            )
                              }
                )    
  names(data) <- sapply(data, function(x) getVarNames(x))     
                        
  obs.data <- lapply(1:length(era5_daily), 
                     function(x)  {intersectGrid(era5_daily[[x]], 
                                                 data[[x]], 
                                                 type = "temporal", 
                                                 which.return = 1
                                                )
                                  }
                    ) 
                        
  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x))
                            
} else{
  obs.data <- lapply(1:length(era5_daily), 
                     function(x)  {intersectGrid(era5_daily[[x]], 
                                                 data[[x]], 
                                                 type = "temporal", 
                                                 which.return = 1
                                                )
                                  }
                    ) 
    
  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x))  
}
                            
# Check variable names are consistent
if (!identical(names(obs.data), names(data))) stop("Variables in obs and mod do not match.")

# Bias correction with LOO cross-validation
data.bc <- lapply(1:length(data), function(v)  {
    pre <- FALSE
    if (names(data)[v] == "tp") pre <- TRUE
    biasCorrection(y = obs.data[[v]], 
                   x = data[[v]], 
                   method = "eqm",
                   cross.val = "loo",
                   precipitation = pre,
                   wet.threshold = 1,
                   join.members = TRUE,
                   parallel = TRUE
                  )
}) 

names(data.bc) <- names(data) 
                            
# Save
save(data.bc, 
     file = paste0(rdata_fold, 's5_morsa_', model, '_merged_', season, '_bc.rda'))
                            
# Convert each member to CSV and save
dates <- data.bc[[1]]$Dates
yymmdd <- as.Date(dates$start)

for (i in members) {
  # Build dataframe
  single.member <- lapply(data.bc, function(x) subsetGrid(x, members = i))
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
              paste0(data_fold, 's5_morsa_', model, '_merged_', season, '_', member, '_bc.csv'), 
              sep = ",", 
              row.names = FALSE, 
              col.names = TRUE, 
              quote = FALSE
             )
}      