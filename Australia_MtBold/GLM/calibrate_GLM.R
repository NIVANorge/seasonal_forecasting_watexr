setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM")

library(GLM3r)
library(tidyverse)
library(gotmtools)
library(glmtools)
source('functions/create_meanflow.R')

# Copy in ERA5 discharge files ----
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Onka_Murray_pipe/onka_ERA5_GR4J_flow_1980_2019_wTemp.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/onka_ERA5_GR4J_flow_1980_2019.csv", overwrite = T)
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Echunga/echunga_ERA5_GR4J_flow_1980_2019.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/echunga_ERA5_GR4J_flow_1980_2019.csv", overwrite = T)
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Outflow_Spill/mtbold_withdrawal_matrix_2011_2017.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/mtbold_withdrawal_matrix_2011_2017.csv")
file.copy("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\Mt_Bold_Data\\Onka_Murray_pipe/pipe_matrix_2000_2006.csv", to = "C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM/pipe_matrix_2000_2006.csv")
####

# Run GLM with calc wbal ----
nml_file <- 'glm3.nml'
met_file <- 'meteo_ERA5.csv'
out <- 'output/output.nc'
start <- '2014-06-01 00:00:00'
stop <- '2018-03-06 00:00:00'
sim_folder <- "."

nml <- read_nml('glm3_wbal.nml')
nml <- set_nml(nml, 'meteo_fl', met_file)
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
ggplot() +
  geom_line(data = sh1, aes(DateTime, surface_height, colour = 'GLM'))+
  coord_cartesian(xlim = range(sh1$DateTime))
plot_var(out, reference = 'bottom')
#####

# Calibrate GLM ----
calib_setup <- get_calib_setup()
calib_setup <- calib_setup[1:2, ]
calib_setup$lb <- 0.5
print(calib_setup)

#Example calibration

field_file <- file.path(sim_folder, 'field_data.csv')
nml_file <- file.path(sim_folder, 'glm3.nml')
driver_file <- file.path(sim_folder, met_file)
period = get_calib_periods(nml_file = nml_file, ratio = 1)
output = file.path(sim_folder, 'output/output.nc')

nml <- set_nml(nml, 'start', '2013-06-01 00:00:00')
glmtools::write_nml(nml, nml_file)

var = 'temp' # variable to apply the calibration procedure
calibrate_sim(var = var, path = sim_folder, field_file = field_file,
              nml_file = nml_file, calib_setup = calib_setup,
              glmcmd = NULL,
              first.attempt = TRUE, period = period, method = 'CMA-ES',
              scaling = TRUE, #scaling should be TRUE for CMA-ES
              verbose = FALSE,
              metric = 'RMSE',plotting = FALSE,
              target.fit = 1.5,
              target.iter = 50, output = output)

pars <- read.csv('calib_par_temp.csv')

nml <- set_nml(nml, colnames(pars)[2], round(pars[1,2], 2))
nml <- set_nml(nml, colnames(pars)[3], round(pars[1,3], 2))

glmtools::write_nml(nml, nml_file)

GLM3r::run_glm()

# Compare temperature ----
obs_file <- 'mtbold_wtemp_2014-2018_1m_1day.csv'
wtemp <- read_csv(obs_file)
colnames(wtemp) <- c('time', 'depth', 'obs')
deps <- unique(wtemp$depth)
t_out <- unique(wtemp$time)
# ggplot(wtemp, aes(time, obs, colour = factor(depth))) +
#   geom_line()+
#   theme_classic()

library(reshape2)
mod <- get_var(out, 'temp', reference = 'surface', z_out = deps, t_out = t_out)
mlt <- melt(mod, 'DateTime')
colnames(mlt)[-1] <- c('depth', 'mod')
mlt$depth <- as.numeric(gsub('temp_', '', mlt$depth))

all <- merge(wtemp, mlt, by = c(1,2))
all$res <- all$mod - all$obs

cal_ind <- which(all$time >= period$calibration$start &
                   all$time < period$calibration$stop)
val_ind <- which(all$time >= period$validation$start &
                   all$time < period$validation$stop)


rmse_cal <- rmse(all$mod[cal_ind], all$obs[cal_ind])
nse_cal <- hydroGOF::NSE(all$mod[cal_ind], all$obs[cal_ind])

rmse_val <- rmse(all$mod[val_ind], all$obs[val_ind])
nse_val <- hydroGOF::NSE(all$mod[-cal_ind], all$obs[-cal_ind])

print(paste('Calib: RMSE -', rmse_cal, 'NSE -', nse_cal,
            '\nValid: RMSE -', rmse_val, 'NSE -', nse_val))
  