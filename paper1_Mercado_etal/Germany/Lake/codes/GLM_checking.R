setwd("C:\\Users\\shikhani\\Documents\\WatexR_MS")

library(glmtools)
library(lubridate)
library(rLakeAnalyzer)
library(airGR)
library(dynatopmodel)
my_nc <- "GLM/GLM3_GR6J_ERA5_testRMSE_calb/output/output.nc"
my_field <- "temp_profiles.csv"

#thermo_values <-compare_to_field(my_nc,my_field,metric = 'thermo.depth', as_value = TRUE)
temp_rmse <- compare_to_field(my_nc,my_field,  metric = 'water.temperature', as_value = FALSE)
print(paste(round(temp_rmse,3),'deg C RMSE'))




#plot_temp_compare(my_nc,my_field)
r2f <- resample_to_field(my_nc,my_field, var_name = "temp")
surf.temp.wupper <- get_temp(my_nc, reference = "surface", z_out = 0.1)
r2f <- r2f[-which(is.na(r2f$Modeled_temp)),]
r2f.st <- r2f[which(r2f$Depth < 0.3),]
NSE(r2f$Modeled_temp, r2f$Observed_temp)

plot_var_compare(my_nc,my_field, 'temp', resample = FALSE) ##makes a plot



#############################
my_nc <- "GLM/GLM3_GR6J_ERA5_testRMSE_vald///output/output.nc"
my_field <- "temp_profiles.csv"

#thermo_values <-compare_to_field(my_nc,my_field,metric = 'thermo.depth', as_value = TRUE)
temp_rmse <- compare_to_field(my_nc,my_field,  metric = 'water.temperature', as_value = FALSE)
print(paste(round(temp_rmse,3),'deg C RMSE'))

r2f <- resample_to_field(my_nc,my_field, var_name = "temp")
surf.temp.wupper <- get_temp(my_nc, reference = "surface", z_out = 0.1)
r2f <- r2f[-which(is.na(r2f$Modeled_temp)),]
r2f.st <- r2f[which(r2f$Depth < 0.3),]
NSE(r2f$Modeled_temp, r2f$Observed_temp)

plot_var_compare(my_nc,my_field, 'temp', resample = FALSE) ##makes a plot



#plot_temp_compare(my_nc,my_field)
r2f <- resample_to_field(my_nc,my_field, var_name = "temp")
surf.temp.wupper <- get_temp(my_nc, reference = "surface", z_out = 0.1)
r2f <- r2f[-which(is.na(r2f$Modeled_temp)),]
r2f.st <- r2f[which(r2f$Depth < 0.3),]
NSE(r2f$Modeled_temp, r2f$Observed_temp)
# 
# plot(surf.temp.wupper$DateTime, surf.temp.wupper$temp_0.1, type = "l", xlab = "Date", ylab = "surface temperature", main = "Surface Temperature GLM")
# points(r2f.st$DateTime, r2f.st$Observed_temp, col="red")
# legend( 1524877795,34, c("Simulated", "Observed"), bty = "n", lty = c(1,NA), col = c("black", "red"),pch=c(NA,1), cex = 1, xjust=1)
#########
plot(r2f$Observed_temp, r2f$Modeled_temp, xlim = c(0,30), ylim = c(0,30), ylab = "Simulated", xlab = "Observed", main = "whole lake temperture 2011-2016")
abline(0,1)
text(2.5,25, paste("COR=",round(cor(r2f$Observed_temp,r2f$Modeled_temp),3),sep = " ") )

text(2.5,22, paste("RMSE=",round(rmse(r2f$Observed_temp,r2f$Modeled_temp),3),sep = " ") )





obs2=r2f[,1:3]
simulated.temp.t<-r2f[, c(1,2,4)]


# pdf("C:\\Users\\shikhani\\Desktop\\watexr_git\\WATExR\\Wupper\\results\\profiles\\testRMSEKWfilesdheatingstcalbvaldfinalkw082016.pdf")
# par(fig = c(0, 1, 0, 1),mfrow = c(4, 4), oma =c(6, 4, 1, 1), mar = c(0, 0, 0, 0), new = TRUE, las=1, tcl=0.3, mgp=c(3,0.5,0))
# dd <- unique(as.Date(r2f$DateTime ))
# 
# for (i in 1:length(dd)){
#   
#   daym <- simulated.temp.t[which(as.Date(as.character(simulated.temp.t$DateTime))%in%as.Date(as.character(dd[i]))),]
#   dayy <- obs2[which(as.Date(as.character(obs2$DateTime))==as.Date(as.character(dd[i]))),]
#   
#   plot(daym$Modeled_temp, daym$Depth , type = "l" , xlim=c(0, 32) ,ylim = c(32,0),xaxt = 'n', yaxt='n', col="black", cex.axis=1.8) 
#   #axis(3)
#   axis(1, labels=F)
#   axis(2, labels=F); axis(2,at=seq(0,30,10), labels=F)
#   points( dayy$Observed_temp, dayy$Depth  , col="red")
#   
#   text(22,30,as.Date(dd[i]), cex=1.2)
#   
#   
#   if (i %in% c(13,14,15, 16)){axis(1, at=seq(0,30,10), cex.axis=1.3)}
#   if (i %in% c(1, 5,9,13)){axis(2, at=seq(0,30,10), cex.axis=1.3); axis(2,at=seq(0,80,10), labels=F)}
#   
#   if (i %in% c(14)){mtext("Temperature (°C)", 1, cex=1.1, at=33, line=2.5)}
#   if (i %in% c(5)){mtext("Depth (m)", 2, cex=1.1,las=0, at=45, line=2.2)}
#   
#   if (i %in% c(1)){legend(31,0, c("Simulated", "Observed"), bty = "n", lty = c(1,NA), col = c("black", "red"),pch=c(NA,1), cex = 1, xjust=1)}
#   
# }
# 
# dev.off()
# 
