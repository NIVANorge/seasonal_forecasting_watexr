setwd("C:\\Users\\mooret\\OneDrive - Dundalk Institute of Technology\\WateXr\\WATExR\\MtBold\\GLM")

library(tidyverse)
library(gotmtools)
library(glmtools)

onk <- read_csv('onka_1973_2018_1day.csv')
ech <- read_csv('echunga_flow_cumecs_2003_2013.csv')
out <- read_csv('mtbold_withdrawal_2010_2018.csv')

all <- merge(ech, onk, by = 1, all.x = T)
all <- merge(all, out, by = 1, all.x = T)

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

library(GLM3r)
library(reshape2)
nml_file <- 'glm3.nml'
out <- 'output/output.nc'
nml <- read_nml(nml_file)
matrix_file <- 'mtbold_withdrawal_matrix.csv'
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
