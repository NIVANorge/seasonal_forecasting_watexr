rea <- get(load("eugenio_2019_01_10/Rdata/interim075_WATExR_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_pr_rsds_rlds_wss_hurs_tasmax_tasmin_cc_petH_BC.rda"))
obs <- get(load("eugenio_2019_01_10/Rdata/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_pr_rsds_rlds_wss_hurs_tasmax_tasmin_cc_petH.rda"))
hind <- get(load("eugenio_2019_01_10/Rdata/System4_seasonal_15_5_6_7_8_uas_vas_ps_tas_pr_rsds_rlds_wss_hurs_tasmax_tasmin_cc_petH_BC.rda"))
hind$pr$Dates$start <-  hind$uas$Dates$start
  
# prepare temporal domain (4 months)
years <- 1989:2010

hind <- lapply(hind, function(x) subsetGrid(x, years = years))
obs.sub <- lapply(1:length(obs), function(x)  {intersectGrid(obs[[x]], hind[[x]], type = "temporal", which.return = 1)})
names(obs.sub) <- names(rea)
names(hind) <- names(rea)
temporalPlot(obs.sub[[1]],  hind[[1]])

# prepare warm-up period

wups <- lapply(years, function(x) seq(x - 10, x - 1))

eo <- lapply(1:length(rea), function(i){
  r <- rea[[i]]
  lapply(wups, function(x) subsetGrid(r, years = x))
})
names(eo) <- names(rea)

ea <- lapply(1:length(rea), function(i){
  r <- rea[[i]]
  lapply(years, function(x) subsetGrid(r, years = x, season = 1:4))
})
names(ea) <- names(rea)

warmup <- lapply(1:length(eo), function(i){
  o <- eo[[i]]
  a <- ea[[i]]
  lapply(1:length(o), function(x) bindGrid(o[[x]], a[[x]], dimension = "time"))
})
names(warmup) <- names(rea)

fullserie <- lapply(1:length(warmup), function(i){
  wu <- warmup[[i]]
  hi <- hind[[i]]
  lapply(1:15, function(m) {
    h <- subsetGrid(hi, members = m)
    lapply(1:length(wu), function(x) {
      bindGrid(wu[[x]], subsetGrid(h, years = years[x]), dimension = "time")
    })
  })
})
names(fullserie) <- names(rea)

output.dir <- "/media/maialen/work/WORK/LOCAL/WATEXR/eugenio_2019_01_10/output/Arreskov/CLIMATE/"
dataset <- "System4"
datatoexport <- fullserie



# Save a single file for each member
for (i in 1:15) {
  for (n in 1:length(years)) {
  # Build data.frame for a single member
  memyear <- lapply(datatoexport, function(x) (x[[i]][[n]]))
  names(memyear) <- names(datatoexport)
  yymmdd <- as.Date(memyear[[1]]$Dates$start)
  hhmmss <- format(as.POSIXlt(memyear[[1]]$Dates$start), format = "%H:%M:%S") 
  single.member <- lapply(memyear, function(x) redim(x, drop = TRUE)$Data)
  # Remove unwanted variables
  # single.member["rsds"] <- NULL
  # single.member["rlds"] <- NULL
  # data.frame creation
  df <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss), single.member))
  if (i < 10) {
    member <- paste0("member0", i, sep = "", collapse = NULL)
  } else {
    member <- paste0("member", i, sep = "", collapse = NULL)
  }    
  startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
  endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
  dirName <- paste0(output.dir, "/WET/Edited4modeling_summer/", dataset, "_meteo_file_", startTime, "-", endTime, "_", member, "_", years[n], ".dat", sep = "", collapse = NULL)
  write.table(df, dirName, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
  dirName <- paste0(output.dir, "/SWAT/Edited4modeling_summer/", dataset, "_meteo_file_")
  if ("tasmin" %in% colnames(df) & "tasmax" %in% colnames(df)){
    indmin <- which(colnames(df) == "tasmin")
    indmax <- which(colnames(df) == "tasmax")
    df1 <- df[, c(indmax, indmin)]
    df <- df[, -c(indmax, indmin)]
    df1.1 <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), paste0(df1[["tasmax"]], ",", df1[["tasmin"]])))
    write.table(df1.1, paste0(dirName, "tasmax_tasmin_",startTime, "-", endTime, "_", member, "_", years[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
  }
for (v in 3:ncol(df)) {
  df.v <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), df[[colnames(df)[v]]]))
  write.table(df.v, paste0(dirName, colnames(df)[v], "_",startTime, "-", endTime, "_", member, "_", years[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
}
}
}


lf <- list.files("/home/maialen/Dropbox/WATEXR/output/Arreskov/CLIMATE/WET/Edited4modeling_summer", full.names = T)
for (i in lf) {
  latin = readLines(i)
  latin[1] = "!dates1	dates2	uas	vas	ps	tas	pr	rsds	rlds	wss	hurs	tasmax	tasmin	cc	petH"
  writeLines(latin,i)
}


##########################################################################

obs <- get(load("eugenio_2019_01_10/Rdata/PIK_Obs-EWEMBI_1_2_3_4_5_6_7_8_9_10_11_12_uas_vas_ps_tas_pr_rsds_rlds_wss_hurs_tasmax_tasmin_cc_petH.rda"))

# prepare temporal domain (4 months)
years <- 1989:2010

obs.sub <- lapply(obs, function(x) subsetGrid(x, years = years))
names(obs.sub) <- names(obs)

# prepare warm-up period

wups <- lapply(years, function(x) seq(x - 10, x - 1))

eo <- lapply(1:length(obs), function(i){
  r <- obs[[i]]
  lapply(wups, function(x) subsetGrid(r, years = x))
})
names(eo) <- names(obs)

ea <- lapply(1:length(obs), function(i){
  r <- obs[[i]]
  lapply(years, function(x) subsetGrid(r, years = x, season = 1:8))
})
names(ea) <- names(obs)

warmup <- lapply(1:length(eo), function(i){
  o <- eo[[i]]
  a <- ea[[i]]
  lapply(1:length(o), function(x) bindGrid(o[[x]], a[[x]], dimension = "time"))
})
names(warmup) <- names(obs)

fullserie <- warmup

output.dir <- "/media/maialen/work/WORK/LOCAL/WATEXR/eugenio_2019_01_10/output/Arreskov/CLIMATE/"
dataset <- "PIK_Obs-EWEMBI"
datatoexport <- fullserie

member <- "member01"

# Save a single file for each member

  for (n in 1:length(years)) {
    # Build data.frame for a single member
    memyear <- lapply(datatoexport, function(x) (x[[n]]))
    names(memyear) <- names(datatoexport)
    yymmdd <- as.Date(memyear[[1]]$Dates$start)
    hhmmss <- format(as.POSIXlt(memyear[[1]]$Dates$start), format = "%H:%M:%S") 
    single.member <- lapply(memyear, function(x) redim(x, drop = TRUE)$Data)
    # Remove unwanted variables
    # single.member["rsds"] <- NULL
    # single.member["rlds"] <- NULL
    # data.frame creation
    df <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss), single.member))
    startTime <- format(as.POSIXlt(yymmdd[1]), format = "%Y%m%d")
    endTime <- format(tail(as.POSIXlt(yymmdd), n = 1), format = "%Y%m%d")
    dirName <- paste0(output.dir, "/WET/Edited4modeling_summer/", dataset, "_meteo_file_", startTime, "-", endTime, "_", member, "_", years[n], ".dat", sep = "", collapse = NULL)
    write.table(df, dirName, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
    dirName <- paste0(output.dir, "/SWAT/Edited4modeling_summer/", dataset, "_meteo_file_")
    if ("tasmin" %in% colnames(df) & "tasmax" %in% colnames(df)) {
      indmin <- which(colnames(df) == "tasmin")
      indmax <- which(colnames(df) == "tasmax")
      df1 <- df[, c(indmax, indmin)]
      df <- df[, -c(indmax, indmin)]
      df1.1 <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), paste0(df1[["tasmax"]], ",", df1[["tasmin"]])))
      write.table(df1.1, paste0(dirName, "tasmax_tasmin_", startTime, "-", endTime, "_", member, "_", years[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
    }
    for (v in 3:ncol(df)) {
      df.v <- data.frame(c(gsub("-", replacement = "", x = df[1,1]), df[[colnames(df)[v]]]))
      write.table(df.v, paste0(dirName, colnames(df)[v], "_",startTime, "-", endTime, "_", member, "_", years[n], ".txt", sep = "", collapse = NULL), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
    }
  }


lf <- list.files("/home/maialen/Dropbox/WATEXR/output/Arreskov/CLIMATE/WET/Edited4modeling", full.names = T, pattern = "EWEMBI")
for (i in lf) {
  latin = readLines(i)
  latin[1] = "!dates1	dates2	uas	vas	ps	tas	pr	rsds	rlds	wss	hurs	tasmax	tasmin	cc	petH"
  writeLines(latin,i)
}
