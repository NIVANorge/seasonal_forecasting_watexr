#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
options(java.parameters = "-Xmx8000m")
library(transformeR)
library(loadeR)
library(downscaleR)

# Unpack args
year <- as.integer(args[1])
season <- args[2]
months <- as.integer(unlist(strsplit(args[3], split = ",")))

# Fixed args
variables <- c("uas", "vas", "tas", "tp")
aggr.func <- c("mean", "mean", "mean", "sum")
lead.month <- 1
members <- 1:25
years <- year:year
latLim <- c(59.25, 59.75)
lonLim <- c(10.25, 11.25)
lake <- list(x = 10.895, y = 59.542)
cdsDic <- "SYSTEM5_ecmwf_Seasonal_25Members_SFC.dic"

if (year < 2017) {
  url <- "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_Seasonal_25Members_SFC.ncml"
} else {
  url <- "http://meteo.unican.es/tds5/dodsC/Copernicus/SYSTEM5_ecmwf_forecast_Seasonal_51Members_SFC.ncml"
}

# Login
loginUDG("WATExR", "1234567890")

# Get seasonal forecast data
data.prelim <- lapply(
  1:length(variables),
  function(x) {
    loadSeasonalForecast(url,
      variables[x],
      dictionary = cdsDic,
      members = members,
      lonLim = lonLim,
      latLim = latLim,
      season = months,
      years = years,
      leadMonth = lead.month,
      time = "DD",
      aggr.d = aggr.func[x],
    )
  }
)

names(data.prelim) <- variables

# Bilinear interpolation of the S5 data to the location of the lake
data <- lapply(
  data.prelim,
  function(x) {
    interpGrid(x,
      new.coordinates = lake,
      method = "bilinear",
      bilin.method = "akima"
    )
  }
)

# Read ERA5 data
load("./data_cache/era5_obs/era5_morsa_1980-2019_daily.rda")
era5_daily <- era5_daily[variables] # Just variables of interest

# Subset all datasets to the same dates as the S5 precipitation.
# I don't fully understand this code yet, but it's taken from here:
#     https://github.com/icra/WATExR/blob/61fc3fa31914b5a7447723cd2ed50df4af277b16/R/seasonalForecast.R#L158
if (sum(names(data) == "tp") > 0) {
  data <- lapply(
    1:length(data),
    function(x) {
      intersectGrid(data[[x]],
        data[[which(names(data) == "tp")]],
        type = "temporal",
        which.return = 1
      )
    }
  )
  names(data) <- sapply(data, function(x) getVarNames(x))

  obs.data <- lapply(
    1:length(era5_daily),
    function(x) {
      intersectGrid(era5_daily[[x]],
        data[[x]],
        type = "temporal",
        which.return = 1
      )
    }
  )

  names(obs.data) <- sapply(obs.data, function(x) getVarNames(x))
} else {
  obs.data <- lapply(
    1:length(era5_daily),
    function(x) {
      intersectGrid(era5_daily[[x]],
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

# Bias correction without cross-validation
data.bc <- lapply(1:length(data), function(v) {
  pre <- FALSE
  if (names(data)[v] == "tp") pre <- TRUE
  biasCorrection(
    y = obs.data[[v]],
    x = data[[v]],
    method = "eqm",
    precipitation = pre,
    wet.threshold = 1,
    join.members = TRUE,
    parallel = TRUE
  )
})

names(data.bc) <- names(data)

# Convert each member to CSV and save
dates <- data.bc[[1]]$Dates
yymmdd <- as.Date(dates$start)

# Adjust year back to user-specified year in "winter" for file-naming
if (season == "winter") {
  year <- year - 1
}

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
  data_fold <- "./data_cache/s5_seasonal/"
  write.table(df,
    paste0(data_fold, "s5_morsa_", year, "_", season, "_", member, "_bc.csv"),
    sep = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
}