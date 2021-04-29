setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM")

library(GLM3r)
library(tidyverse)
library(gotmtools)
library(glmtools)
source('functions/create_meanflow.R')

# Copy in ERA5 discharge files ----
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Onka_Murray_pipe/onka_ERA5_GR4J_flow_1980_2019_wTemp.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/onka_ERA5_GR4J_flow_1980_2019.csv", overwrite = T)
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Echunga/echunga_ERA5_GR4J_flow_1980_2019.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/echunga_ERA5_GR4J_flow_1980_2019.csv", overwrite = T)
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Outflow_Spill/mtbold_withdrawal_matrix_2011_2017.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/mtbold_withdrawal_matrix_2011_2017.csv", overwrite = T)
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Onka_Murray_pipe/pipe_matrix_2000_2006.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/pipe_matrix_2000_2006.csv", overwrite = T)
####

# Read in observed lake level
lev <- read.delim('MtBold_reservoir_height_1999-2018.dat')
colnames(lev) <- c('DateTime', 'lev')
lev$DateTime <- as.POSIXct(lev$DateTime, tz = 'UTC')
p1 <- ggplot(lev, aes(DateTime, lev))+
  geom_line(aes(colour = 'Obs'), size = 1.2)+
  theme_classic(base_size = 16)+
  coord_cartesian(ylim = c(0,45))+
  theme(panel.border = element_rect(colour = 'black', fill = NA))
p1

# Run GLM with no outflow ----
file.copy(from = 'glm3.nml', 'glm3_master.nml')
nml_file <- 'glm3.nml'
met_file <- 'meteo_ERA5.csv'
out <- 'output/output.nc'
start <- '2014-06-01 00:00:00'
stop <- '2018-03-06 00:00:00'

nml <- read_nml('glm3_master.nml')
# nml <- read_nml('glm3_wbal.nml')
nml <- set_nml(nml, 'num_outlet', 0)
nml <- set_nml(nml, 'num_inflows', 0)
nml <- set_nml(nml, 'meteo_fl', met_file)
# nml <- set_nml(nml, 'names_of_strms', 'Onka')
# nml <- set_nml(nml, 'inflow_fl', 'onka_1973_2018_1day.csv')
# nml <- set_nml(nml, 'inflow_varnum', 1)
# nml <- set_nml(nml, 'inflow_vars', 'FLOW')
nml <- set_nml(nml, 'start', start)
nml <- set_nml(nml, 'stop', stop)
nml <- set_nml(nml, 'num_depths', 2)
nml <- set_nml(nml, 'the_depths', c(0,15))
nml <- set_nml(nml, 'the_temps', c(12,12))
nml <- set_nml(nml, 'the_sals', c(0,0))
nml <- set_nml(nml, 'lake_depth', 41.5)
glmtools::write_nml(nml, nml_file)

GLM3r::run_glm()

sh1 <- get_surface_height(out)
p1 <- p1 +
  geom_line(data = sh1, aes(DateTime, surface_height, colour = 'No in/out/pipe'))+
  coord_cartesian(xlim = range(sh1$DateTime))
plot_var(out, reference = 'bottom')
#####

# Add GR4J ERA5 inflows ----
onk_file <- 'onka_ERA5_GR4J_flow_1980_2019.csv'
ech_file <- 'echunga_ERA5_GR4J_flow_1980_2019.csv'
nml <- set_nml(nml, 'num_outlet', 0)
nml <- set_nml(nml, 'num_inflows', 2)
nml <- set_nml(nml, 'names_of_strms', c('Onka', 'Echunga'))
nml <- set_nml(nml, 'inflow_fl', c(onk_file, ech_file))
nml <- set_nml(nml, 'inflow_varnum', c(1,1))
nml <- set_nml(nml, 'subm_flag', c(F,F))
nml <- set_nml(nml, 'inflow_varnum', c(1,1))
nml <- set_nml(nml, 'strm_hf_angle', c(77.6,77.6))
nml <- set_nml(nml, 'strmbd_slope', c(0.47,0.47))
nml <- set_nml(nml, 'strmbd_drag', c(0.015,0.015))
nml <- set_nml(nml, 'inflow_factor', c(1,1))
nml <- set_nml(nml, 'inflow_vars', c('FLOW', 'TEMP'))
glmtools::write_nml(nml, nml_file)

GLM3r::run_glm()

sh2 <- get_surface_height(out)
p2 <- p1 +
  geom_line(data = sh2, aes(DateTime, surface_height, colour = 'No out/pipe'))
p2
plot_var(out, reference = 'bottom')
#####

# Add mean outflow ----
out_matrix_file <- 'mtbold_withdrawal_matrix_2011_2017.csv'
create_meanflow(glm_nml = nml, matrix_file = out_matrix_file,fname = 'outflow.csv', index = 'mean')
nml <- set_nml(nml, 'outl_elvs', 202)
nml <- glmtools::set_nml(nml, 'num_outlet', 1)
nml <- glmtools::set_nml(nml, 'outflow_fl', 'outflow.csv')
nml <- glmtools::set_nml(nml, 'outflow_factor', 0.5)
glmtools::write_nml(nml, nml_file)

# outf <- readr::read_csv('outflow.csv')
# ggplot(outf, aes(Time, FLOW))+
#   geom_line()

GLM3r::run_glm()
plot_var(out, reference = 'bottom')

sh3 <- get_surface_height(out)
p3 <- p2 +
  geom_line(data = sh3, aes(DateTime, surface_height, colour = 'No pipe'))
p3
# plot_var(out, reference = 'bottom')
#####

# Add pipe inflow ----
inf_file <- 'inflow.csv'
pip_matrix_file <- 'pipe_matrix_2000_2006.csv'
pip_file <- 'pipe_inflow.csv'
create_meanflow(glm_nml = nml, matrix_file = pip_matrix_file,fname = pip_file, index = 'mean')
pip <- readr::read_csv(pip_file)
onk <- read_csv(onk_file)
inf <- merge(onk, pip, by = 1)
inf$FLOW <- inf$FLOW.x + inf$FLOW.y
inf <- inf[, c('Time', 'FLOW', 'TEMP')]
write.csv(inf, inf_file, row.names = F, quote = F)

nml <- set_nml(nml, 'num_inflows', 2)
nml <- set_nml(nml, 'names_of_strms', c('Onka+Pipe', 'Echunga'))
nml <- set_nml(nml, 'inflow_fl', c(inf_file, ech_file))
nml <- set_nml(nml, 'subm_flag', c(F,F))
nml <- set_nml(nml, 'inflow_varnum', c(2,2))
nml <- set_nml(nml, 'strm_hf_angle', c(79.6,77.6))
nml <- set_nml(nml, 'strmbd_slope', c(0.33,0.47))
nml <- set_nml(nml, 'strmbd_drag', c(0.015,0.015))
nml <- set_nml(nml, 'inflow_factor', c(1,1))
nml <- set_nml(nml, 'inflow_vars', c('FLOW', 'TEMP'))
nml <- glmtools::set_nml(nml, 'outflow_factor', 1)
glmtools::write_nml(nml, nml_file)

GLM3r::run_glm()

sh4 <- get_surface_height(out)
p4 <- p3 +
  geom_line(data = sh4, aes(DateTime, surface_height, colour = 'All'))
p4
plot_var(out, reference = 'bottom')
file.copy(nml_file, 'glm3_calib.nml', overwrite = T)

#####

# Adjust the outflow factor ----
# nml <- set_nml(nml, 'outflow_factor', 1)
# nml <- set_nml(nml, 'outl_elvs', 202)
# glmtools::write_nml(nml, nml_file)
# GLM3r::run_glm()
# 
# sh6 <- get_surface_height(out)
# p5 <- p4 +
#   geom_line(data = sh6, aes(DateTime, surface_height, colour = '0.7'))
# p5

nml <- set_nml(nml, 'start', '1980-01-01 00:00:00')
nml <- set_nml(nml, 'stop', '2018-01-01 00:00:00')
create_meanflow(glm_nml = nml, matrix_file = out_matrix_file,fname = 'outflow.csv', index = 'mean')
create_meanflow(glm_nml = nml, matrix_file = pip_matrix_file,fname = pip_file, index = 'mean')
pip <- readr::read_csv(pip_file)
onk <- readr::read_csv(onk_file)
inf <- merge(onk, pip, by = 1)
inf$FLOW <- inf$FLOW.x + inf$FLOW.y
inf <- inf[, c('Time', 'FLOW', 'TEMP')]
write.csv(inf, inf_file, row.names = F, quote = F)

# nml <- set_nml(nml, 'outflow_factor', 1)
# nml <- set_nml(nml, 'num_inflows', 3)
# nml <- set_nml(nml, 'num_inflows', 3)
# nml <- set_nml(nml, 'names_of_strms', c('Onka', 'Echunga', 'Pipe'))
# nml <- set_nml(nml, 'inflow_fl', c(onk_file, pip_file, ech_file))

# onk <- read_csv(onk_file)
# pip <- read_csv(pip_file)
# 
# inf <- merge(onk, pip, by = 1)
# 
# inf$FLOW <- inf[,2] + inf[,3]
# inf <- inf[, c('Time', 'FLOW')]


# nml <- read_nml('glm3_wbal.nml')
# glmtools::write_nml(nml, nml_file)
GLM3r::run_glm()
plot_var(out, reference = 'bottom')

sh7 <- get_surface_height(out)
ggplot(data = sh7, aes(DateTime, surface_height, colour = 'Cal'))+
  geom_line()
p6 <- p1 +
  geom_line(data = sh7, aes(DateTime, surface_height, colour = 'Cal'))+
  coord_cartesian(xlim = range(sh7$DateTime))
p6

p7 <- ggplot(lev, aes(DateTime, lev, colour = 'Obs')) +
  geom_line() +
  geom_line(data = sh7, aes(DateTime, surface_height, colour = 'GLM')) +
  coord_cartesian(xlim = as.POSIXct(c('2000-01-01', '2018-01-01'), tz = 'UTC'))+
  theme_classic(base_size = 22)
p7

ggsave('wbal.png', p7)

file.copy('glm3.nml', 'glm3_wbal.nml', overwrite = T)
lev2 <- lev
lev2$DateTime <- as.character(lev2$DateTime)
sh72 <- sh7
sh72$DateTime <- as.character(sh72$DateTime)

df <- merge(lev2, sh72, by = "DateTime")
ggplot(df, aes(lev, surface_height))+
  geom_point()+
  coord_equal(xlim = c(5,45), ylim = c(5,45))
cor(df$lev, df$surface_height)
hydroGOF::rmse(df$lev, df$surface_height)

# Extract observed data for Seasonal Forecast
## Prepare output file
library(transformeR)
obs_m <- readRDS("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata/ERA5_1_2_3_4_5_6_7_8_9_10_11_12_u10_v10_sp_t2m_tp_d2m_tcc_mper_wss_petH_ssrd_strd.rds")
range(obs_m$u10$Dates)
obs2 <- lapply(1:length(obs_m), function(x) subsetGrid(obs_m[[x]], years = 1980:2017))
names(obs2) <- names(obs_m)


## Create list for outputs and input new attributes
#####
# Observed
obs <- list("ech_q" = obs2$u10, "onk_q" = obs2$u10, "surftemp" = obs2$u10, "bottemp" = obs2$u10, "wlev" = obs2$u10) #

attr(obs$ech_q$Variable, "longname") <- paste("Discharge")
attr(obs$ech_q$Variable, "description") <- paste("Discharge for Echunga Creek")
obs$ech_q$Variable$varName <- "ech_q"
attr(obs$ech_q$Variable, "units") <- "m3.s-1"

attr(obs$onk_q$Variable, "longname") <- paste("Discharge")
attr(obs$onk_q$Variable, "description") <- paste("Discharge for the Onkaparinga river")
obs$onk_q$Variable$varName <- "onk_q"
attr(obs$onk_q$Variable, "units") <- "m3.s-1"

attr(obs$surftemp$Variable, "longname") <- paste("Surface temperature")
attr(obs$surftemp$Variable, "description") <- paste("Surface temperature")
obs$surftemp$Variable$varName <- "surftemp"
attr(obs$surftemp$Variable, "units") <- "degC"

attr(obs$bottemp$Variable, "longname") <- paste("Bottom temperature")
attr(obs$bottemp$Variable, "description") <- paste("Bottom temperature")
obs$bottemp$Variable$varName <- "bottemp"
attr(obs$bottemp$Variable, "units") <- "degC"

attr(obs$wlev$Variable, "longname") <- paste("Water level")
attr(obs$wlev$Variable, "description") <- paste("Height of the water level")
obs$wlev$Variable$varName <- "wlev"
attr(obs$wlev$Variable, "units") <- "m"

## Load data and input into obs ----
# Echunga
ech_q <- read.csv(ech_file, stringsAsFactors = F)
ech_q <- ech_q[ech_q$Time >= '1980-01-01' & ech_q$Time < '2018-01-01',]
length(obs$ech_q$Data) == nrow(ech_q)
obs$ech_q$Data <- as.array(ech_q$FLOW)
attributes(obs$ech_q$Data) <- attributes(obs2$u10$Data) 
visualizeR::temporalPlot(obs$ech_q)

# Onkaparinga
onk_q <- read.csv(onk_file, stringsAsFactors = F)
onk_q <- onk_q[onk_q$Time >= '1980-01-01' & onk_q$Time < '2018-01-01',]
length(obs$onk_q$Data) == nrow(onk_q)
obs$onk_q$Data <- as.array(onk_q$FLOW)
attributes(obs$onk_q$Data) <- attributes(obs2$u10$Data) 
visualizeR::temporalPlot(obs$onk_q, obs$ech_q)

# Surface temperature
temp.surf <- get_temp(out, reference = 'surface', z_out = 1)
temp.surf <- rbind(temp.surf[1,], temp.surf)
temp.surf[1, 1] <- temp.surf[1, 1] - 1 * 24 *60 * 60
temp.surf <- temp.surf[temp.surf$DateTime >= '1980-01-01' & temp.surf$DateTime < '2018-01-01',]
length(obs$surftemp$Data) == nrow(temp.surf)
obs$surftemp$Data <- as.array(temp.surf$temp_1)
attributes(obs$surftemp$Data) <- attributes(obs2$u10$Data)

# Bottom temperature
temp.bott <- get_temp(out, reference = 'bottom', z_out = 1)
temp.bott <- rbind(temp.bott[1,], temp.bott)
temp.bott[1, 1] <- temp.bott[1, 1] - 1 * 24 *60 * 60
temp.bott <- temp.bott[temp.bott$DateTime >= '1980-01-01' & temp.bott$DateTime < '2018-01-01',]
length(obs$bottemp$Data) == nrow(temp.bott)
obs$bottemp$Data <- as.array(temp.bott$temp.elv_1)
attributes(obs$bottemp$Data) <- attributes(obs2$u10$Data)

visualizeR::temporalPlot(obs$surftemp, obs$bottemp)

# Surface height
# Bottom temperature
wlev <- get_surface_height(out)
wlev <- rbind(wlev[1,], wlev)
wlev[1, 1] <- wlev[1, 1] - 1 * 24 *60 * 60
wlev <- wlev[wlev$DateTime >= '1980-01-01' & wlev$DateTime < '2018-01-01',]
length(obs$wlev$Data) == nrow(wlev)
obs$wlev$Data <- as.array(wlev$surface_height)
attributes(obs$wlev$Data) <- attributes(obs2$u10$Data)

visualizeR::temporalPlot(obs$wlev)

## Rdata folder
dir.Rdata <- 'C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\Rdata\\'
## Save as .rda object
dataset <- 'ERA5'
season <- 1:12
model <- c('GR4J', 'GLM')
saveRDS(obs, file = paste0(dir.Rdata, paste(dataset, collapse = '_'), '_', paste(model, collapse = '_'), "_", paste0(season, collapse = "_"), "_", paste0(names(obs), collapse = "_"), "_v2.rds"))

# Plot observed data
dir.plot <- '../val_plots/ERA5/'
dir.create(dir.plot)
pdf(paste0(dir.plot, paste(dataset, collapse = '_'), '_', paste(model, collapse = '_'), "_", paste0(season, collapse = "_"), "_", paste0(names(obs), collapse = "_"), "_v2.pdf"), width = 12, height = 7)

visualizeR::temporalPlot(obs$onk_q, obs$ech_q)
visualizeR::temporalPlot(obs$surftemp, obs$bottemp)
visualizeR::temporalPlot(obs$wlev)

dev.off()
######

# Compare temperature ----
obs_file <- 'mtbold_wtemp_2014-2018_1m_1day.csv'
wtemp <- read_csv(obs_file)
wtemp <- as.data.frame(wtemp)
colnames(wtemp) <- c('time', 'depth', 'obs')
deps <- unique(wtemp$depth)
t_out <- unique(wtemp$time)
ggplot(wtemp, aes(time, obs, colour = factor(depth))) +
  geom_line()+
  theme_classic()

library(reshape2)
mod <- get_var(out, 'temp', reference = 'surface', z_out = deps) #, t_out = t_out)
mlt <- melt(mod, 'DateTime')
colnames(mlt)[-1] <- c('depth', 'mod')
mlt$depth <- as.numeric(gsub('temp_', '', mlt$depth))

rmse <- compare_to_field(out, obs_file, metric = 'water.temperature')

po <- plot_var_compare(out, obs_file, precision = 'days')

po

nse <- hydroGOF::NSE(all$mod, all$obs)

all <- merge(wtemp, mlt, by = c(1,2))
all$res <- all$mod - all$obs
ggplot(all, aes(obs, mod, colour = factor(depth)))+
  geom_point()+
  geom_abline(slope = 1, intercept = 0, linetype = 'dashed')+
  coord_equal(xlim = c(0,30), ylim = c(0,30))

ggplot(all, aes(res, depth, colour = obs))+
  geom_point()+
  scale_y_reverse()+
  geom_vline(xintercept = 0)

ggplot(all, aes(time, res, colour = factor(depth)))+
  geom_point()+
  geom_hline(yintercept = 0)

idx <- which(all$time < '2016-01-01')
hydroGOF::NSE(all$mod[idx], all$obs[idx])
hydroGOF::rmse(all$mod[idx], all$obs[idx])


# Extract data for use in seasonal forecasts ----
lak_file <- 'output/lake.csv'

deps <- seq()
wtemp <- get_var(out, var_name = 'temp', reference = 'bottom')

calib_setup <- get_calib_setup()
print(calib_setup)


onk <- read_csv('onka_1973_2018_1day.csv')
ech <- read_csv('echunga_flow_cumecs_2003_2013.csv')
outf <- read_csv('mtbold_withdrawal_2010_2018.csv')
spill <- read_csv('mtbold_spill_2010_2018_cumecs.csv')
outf$Time <- as.POSIXct(outf$Time, tz = 'UTC')

all <- merge(ech, onk, by = 1, all.x = T)
all <- merge(all, outf, by = 1, all.x = T)

colnames(all) <- c('time', 'ech', 'onk', 'out')
mlt <- reshape2::melt(all, id.vars = 1)
ggplot(mlt, aes(time, value, colour = variable))+
  geom_line()

all$FLOW <- all$ech+all$onk
all_out <- all[,c(1,5)]
date <- seq.POSIXt(all_out[1,1], all_out[nrow(all_out),1], by = '1 day')
df <- data.frame(date)
all_out <- merge(df, all_out, by = 1, all.x = T)
summary(all_out)
all_out[,1] <- format(all_out[,1], format = '%Y-%m-%d %H:$M:%S')
write.csv(all_out, 'inflow1.csv', row.names = F, quote = F)

# Outflow
out$year <- lubridate::year(out$Time)
ggplot(out, aes(Time, FLOW))+
  geom_line()+
  facet_wrap(~year, scales = 'free')

lev <- read_delim('MtBold_reservoir_height_1999-2018.dat', delim = '\t')
colnames(lev) <- c('DateTime', 'lev')
source('functions/calc_vol.R')
nml_file <- 'glm3.nml'
nml <- glmtools::read_nml(nml_file)
bathA <- get_nml_value(nml, 'A')
bathD <- get_nml_value(nml, 'H')

lev$vol <- apply(lev, 1, function(x){
  # print(x)
  calc_vol(height = as.numeric(x[2]), bathA = bathA, bathD = bathD)
})
lev$dVdt <- 0
lev$dVdt[-1] <- diff(lev$vol)
lev$dVdt_cumecs <- lev$dVdt/86400
lev$year <- lubridate::year(lev$DateTime)
lev$yday <- lubridate::yday(lev$DateTime)
ggplot(lev, aes(yday, dVdt_cumecs))+
  geom_hline(yintercept = 0, col = 2)+
  geom_line()+
  coord_cartesian(ylim = c(-20,20))+
  facet_wrap(~year)

# Run GLM with no outflow ----
out <- 'output/output.nc'
nml <- read_nml(nml_file)
nml <- set_nml(nml, 'num_outlet', 0)
nml <- set_nml(nml, 'num_inflows', 1)
nml <- set_nml(nml, 'names_of_strms', 'Onka')
nml <- set_nml(nml, 'inflow_fl', 'onka_1973_2018_1day.csv')
nml <- set_nml(nml, 'inflow_varnum', 1)
nml <- set_nml(nml, 'inflow_vars', 'FLOW')
nml <- set_nml(nml, 'start', '2000-09-09 00:00:00')
nml <- set_nml(nml, 'stop', '2018-03-06 00:00:00')
nml <- set_nml(nml, 'num_depths', 2)
nml <- set_nml(nml, 'the_depths', c(0,15))
nml <- set_nml(nml, 'the_temps', c(12,12))
nml <- set_nml(nml, 'the_sals', c(0,0))
nml <- set_nml(nml, 'lake_depth', 41.5)
glmtools::write_nml(nml, nml_file)

GLM3r::run_glm()
plot_var(out, reference = 'bottom')
# Calculate dVdt
lake <- read.csv('output/lake.csv', stringsAsFactors = F)
lake[,1] <- as.POSIXct(lake[,1], tz = 'UTC') - 24*60*60
lake$mod_dVdt <- (lake$Tot.Inflow.Vol + lake$Local.Runoff + (lake$Rain) + lake$Overflow.Vol
                  - lake$Tot.Outflow.Vol - (lake$Evaporation))/86400

plot(lake$time, lake$mod_dVdt, type = 'l', ylim = c(0,10))
lines(lev$DateTime, lev$dVdt_cumecs, col = 2)
colnames(lev)[3] <- 'obs_vol'

dat <- merge(lake[,c('time', 'mod_dVdt', 'Volume', 'Lake.Level')], lev, by = 1)
dat$Volume[1] - dat$obs_vol[1]
dat$vol_diff <- dat$Volume - dat$obs_vol
dat$dVdt_diff <- dat$mod_dVdt - dat$dVdt_cumecs
summary(dat)
plot(outf$Time, outf$FLOW, type = 'l', ylim = c(0,20))
lines(dat$time, dat$dVdt_diff, col = 2)
abline(h = 8)

dat2 <- merge(dat, outf, by = 1)
plot(dat2$dVdt_diff, dat2$FLOW, xlim = c(0,10), ylim = c(0,10))
abline(0,1)
cor(dat2$dVdt_diff, dat2$FLOW)

mod_outflow <- dat2[,c('time', 'dVdt_diff')]
summary(mod_outflow)
mod_outflow$dVdt_diff[mod_outflow$dVdt_diff > 8] <- 8
mod_outflow$dVdt_diff[mod_outflow$dVdt_diff < 0] <- 0
plot(mod_outflow, type = 'l')
lines(outf$Time, outf$FLOW, col = 2)

library(GLM3r)
library(reshape2)

matrix_file <- 'mtbold_withdrawal_matrix.csv'

# Calc volume from hypsograph ----
# Calculate volume from hypsograph - converted to function?
## Needs to be double checked!


# Run with no outflow

list_vars(out, T)
plot_var(out)
vol <- get_var(out, 'Tot_V')
plot(vol)
abline(h = vol_hyp)


plot(lake$Lake.Level, type = 'l')
max(lake$Lake.Level)

# Calculate change in volume



# input_nml(nml, 'time', 'start', "'2010-06-30 00:00:00'")
# input_nml(nml, 'time', 'start', "'2013-06-20 00:00:00'")

# Run ensemble withdrawal regimes ----
out_sh <- lapply(1:7, function(x){
  nml <- create_outflow(nml, matrix_file, x)
  glmtools::write_nml(nml, nml_file)
  GLM3r::run_glm()
  sh <- (get_surface_height(out))
})
out_sh <- lapply(out_sh, function(x){
  mn = min(x[,2])
  if(mn < 15){
    return(NULL)
  }else{
    return(x)
  }
})
df <- bind_rows(out_sh, .id = 'source')

ggplot(df, aes(DateTime, surface_height, colour = source))+
  geom_line()+
  geom_line(data = lev, aes(DateTime, lev, colour = 'meas'), size = 2)+
  coord_cartesian(ylim = c(0,45), xlim = range(df$DateTime))+
  theme_classic(base_size = 22)

#####

# Test with & w/o evap ----
nml <- set_nml(nml, 'disable_evap', TRUE)
write_nml(nml, nml_file)
GLM3r::run_glm()
p1 <- plot_var(out, reference = 'bottom',plot.title = 'NO evap')
sh <- (get_surface_height(out))
p1b <- ggplot(sh, aes(DateTime, surface_height, colour = 'GLM'))+
  geom_line()+ ggtitle('NO evap') +
  geom_line(data = lev, aes(DateTime, lev, colour = 'meas'))+
  coord_cartesian(ylim = c(0,45), xlim = range(sh$DateTime))

nml <- set_nml(nml, 'disable_evap', FALSE)
write_nml(nml, nml_file)
GLM3r::run_glm()
p2 <- plot_var(out, reference = 'bottom', plot.title = 'w/ evap')
sh <- (get_surface_height(out))
p2b <- ggplot(sh, aes(DateTime, surface_height, colour = 'GLM'))+
  geom_line()+ ggtitle('w/ evap') +
  geom_line(data = lev, aes(DateTime, lev, colour = 'meas'))+
  coord_cartesian(ylim = c(0,45), xlim = range(sh$DateTime))
ggpubr::ggarrange(p1, p2, nrow = 2, align = 'v')


ggpubr::ggarrange(p1b, p2b, nrow = 2, align = 'v')




sh <- (get_surface_height(out))
sh$surface_height[is.nan(sh$surface_height)] <- NA
# p1 <- ggplot(mlt, aes(time, value, colour = variable))+
#   geom_line()+
#   coord_cartesian(xlim = range(sh$DateTime))
p2 <- ggplot(sh, aes(DateTime, surface_height, colour = 'GLM'))+
  geom_line()+
  geom_line(data = lev, aes(DateTime, lev, colour = 'meas'))+
  coord_cartesian(ylim = c(0,45), xlim = range(sh$DateTime))
# p2
ggpubr::ggarrange(p1, p2, nrow = 2, align = 'v')

obs <- '../LER/mtbold_wtemp_2014-2018_1m_1day.csv'
file.copy(obs, 'field_data.csv', overwrite = T)
obs<- read.csv('field_data.csv')
colnames(obs) <- c('DateTime', 'Depth', 'temp')
write.csv(obs, 'field_data.csv', row.names = F, quote = F)
obs <- read_csv('field_data.csv')
wid <- pivot_wider(obs, id_cols = 'DateTime', names_from = 'Depth', names_prefix = 'wtr_', values_from = 'temp')
colnames(wid)[1] <- 'datetime'

deps <- unique(obs$Depth)
mod <- get_var(out, 'temp', reference = 'surface', z_out = deps)
colnames(mod) <- c('datetime', gsub('temp', 'wtr', colnames(mod)[-1]))

lst <- list('GLM' = mod, 'Obs' = wid)
p <- plot_resid(var_list = lst)
ggpubr::ggarrange(plotlist = p)
sub <- lapply(lst, function(x)x[x$datetime < '2014-04-01',])
p <- plot_resid(var_list = sub)
calc_fit(list = sub, model = 'GLM', var = 'watertemp')
ggpubr::ggarrange(plotlist = p)

bath <- read.csv('../LER/mtbold_hypsograph.csv', col.names = c('depths', 'areas'))
td <- lapply(lst, function(x)ts.schmidt.stability(x, bath))
df <- dplyr::bind_rows(td, .id = 'Model')
ggplot(df, aes(datetime, thermo.depth, colour = Model))+
  geom_line()

mod <- melt(mod, id.vars = 1)
mod[,2] <- as.numeric(gsub('temp_', '', mod[,2]))
all <- merge(obs, mod, by = c(1,2))

diag_plots(mod = all[,c(1,2,4)], obs = all[,1:3])


compare_to_field(out, field, nml, metric = 'water.temperature')
