setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\LER")

library(LakeEnsemblR)
library(lubridate)
# Functions ----
source('../R_scripts/modelling/functions/create_level.R')
source('../R_scripts/modelling/functions/match_hyps.R')
source('../R_scripts/modelling/functions/init_prof.R') #beta version - will be updated into gotmtools soon
source('../R_scripts/modelling/functions/run_gr4j.R')
source('../R_scripts/modelling/functions/streams_switch.R')

# LER set functions ----
config_file <- 'LakeEnsemblR.yaml'
model = c('GLM')
export_config(config_file = config_file, model = model)
export_meteo(config_file = config_file, model = model)
export_init_cond(config_file, model) #
run_ensemble(config_file, model)
run_glm('GLM/')

# Plot ensemble
ncdf <- ncdf <- file.path('output', get_yaml_value(config_file, 'output', 'file'))
plot_ensemble(ncdf, model, var = 'watertemp', depth =1)
p <- plot_resid(ncdf)
ggpubr::ggarrange(plotlist = p)

library(glmtools)
glm_out <- 'GLM/output/output.nc'
list_vars(glm_out, long = T)
plot_var(glm_out, var = 'Tot_V')
plot_var(glm_out, reference = 'bottom')

# Calibration
library(gotmtools)
got_yaml <- 'GOTM/gotm.yaml'

input_yaml(file = got_yaml, label = 'airt', 'scale_factor', 0.8)
input_yaml(file = got_yaml, label = 'swr', 'scale_factor', 0.8)
input_yaml(file = got_yaml, label = 'turb_param', 'k_min', 1e-6)

run_ensemble(config_file, model)
p <- plot_resid(ncdf)
ggpubr::ggarrange(plotlist = p)

## Create water level
start <- get_yaml_value(config_file, 'time', 'start')
stop <- get_yaml_value(config_file, 'time', 'stop')
wlevel_median_file = 'GOTM/median_height.dat'
wlevel_out = 'GOTM/wlevel.dat'
init_dep = create_level(from = as.POSIXct(start), to = as.POSIXct(stop), in_file = wlevel_median_file, out_file = wlevel_out)
input_yaml(file = got_yaml, label = 'zeta', key = 'method', value = 2) # 0 = fixed, 2 = from file
input_yaml(file = got_yaml, label = 'zeta', key = 'file', value = basename(wlevel_out))
input_yaml(file = got_yaml, label = 'zeta', key = 'offset', value = -init_dep)

run_ensemble(config_file, model)
ncdf <- file.path('output', get_yaml_value(config_file, 'output', 'file'))
p <- plot_resid(ncdf)
ggpubr::ggarrange(plotlist = p)
p1 <- plot_ensemble(ncdf, model, var = 'watertemp', depth = 1)
p2 <- plot_ensemble(ncdf, model, var = 'watertemp', depth = 10)
p3 <- plot_ensemble(ncdf, model, var = 'watertemp', depth = 25)
p4 <- plot_ensemble(ncdf, model, var = 'watertemp', depth = 30)
ggpubr::ggarrange(plotlist = c(p1,p2, p3,p4))

p2 <- plot_heatmap(ncdf)
out <- 'GOTM/output/output.nc'
p1 <- plot_wtemp(out, size = 2.5)
p1
ggpubr::ggarrange(p1,p2, common.legend = T)

library(ggplot2)
obs <- load_obs('mtbold_wtemp_2014-2018_1m_1day.csv', header = T, sep = ',')
obs[,2] <- -obs[,2]
mod <- get_vari(out, 'temp')
z <- get_vari(out, 'z')
mod <- setmodDepths(mod, z, obs)
p1 <- long_lineplot(mod) + coord_cartesian(xlim = as.POSIXct(c('2014-01-01', '2015-01-01'), tz = 'UTC'), ylim = c(5,35))
p2 <- long_lineplot(obs) + coord_cartesian(xlim = as.POSIXct(c('2014-01-01', '2015-01-01'), tz = 'UTC'), ylim = c(5,35))
ggpubr::ggarrange(p1,p2, common.legend = T)



