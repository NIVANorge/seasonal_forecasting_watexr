setwd("C:\\Users\\shikhani\\Documents\\WatexR_MS")

library(visualizeR);library(easyVerification); library(imputeTS)


#hind <- get(load("Rdata_2016/System5_GR6J_GLM_5_6_7_8_wupper_q_surftemp_bottempFinal_Daniel.rda"))

#obs <- get(load('Rdata_2016/ERA5_GR6J_GLM__wupper_q_surftemp_bottempmin= 0.4 max= 0.8Final_Daniel.rda'))

season <- c(6,7,8)
out_dir <- 'Rdata_2016//'
plot_dir <- file.path(out_dir, paste0( paste(season, collapse = '')))
dir.create(plot_dir)
summary(as.vector(obs$wupper_q$Data))
summary(as.vector(hind$wupper_q$Data))

range(hind$wupper_q$Dates$start)
names(obs) ==  names(hind)

# Impact model  
rpss <- list()
for( i in 1:length(hind)) {
  
  pdf(file.path(plot_dir, paste0('Sys5_ERA5_', paste(season, collapse = ''),'_', names(hind)[i], '.pdf')), width = 12, height = 6)
  
  plot.hind <- subsetGrid(hind[[i]], years = c(1994:2016), season = season)
  plot.obs <- subsetGrid(obs[[i]], years = c(1994:2016), season = season)
  attr(plot.obs$Data, "dimensions") <- c("time", "lat", "lon")
  attr(plot.hind$Data, "dimensions") <- c("member", "time", "lat", "lon")
  
  tercilePlot(plot.hind, plot.obs)
  
  dev.off()
  
  # out <- veriApply(verifun = "FairRpss",
  #                  fcst = plot.hind$Data,
  #                  obs = plot.obs$Data,
  #                  prob = c(1/3,2/3),
  #                  tdim = 2, 
  #                  ensdim = 1)
  out <- veriApply(verifun = "FairRpss", 
                   fcst = na_ma(plot.hind$Data,k=4), 
                   obs = plot.obs$Data, 
                   prob = c(1/3,2/3), tdim = 2, ensdim = 1, na.rm=T)
  
  rpss[[i]] <- data.frame(skillscore = out$skillscore, skillscore.sd = out$skillscore.sd)
  
  
}
dat <- do.call('rbind', rpss)
dat$var <- names(hind)
write.csv(dat, file.path(plot_dir, paste0('Sys5_ERA5_', paste(season, collapse = ''), '_impact_model_FairRpss.csv')), row.names = F, quote = F)
