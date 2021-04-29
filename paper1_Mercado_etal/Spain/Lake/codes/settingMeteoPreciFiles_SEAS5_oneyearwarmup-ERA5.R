########## SETTING FILES TO RUN GOTM AND SAVE SELECTED VARIABLES -----------------------
library(transformeR);library(loadeR.ECOMS);library(loadeR);library(downscaleR);library(lubridate)
library(visualizeR); library(sp);library(rgdal);library(loadeR.2nc); library(RNetCDF); library(sp)
library(ncdf4); library(raster);library(convertR);library(drought4R);library(imputeTS)
library(lubridate);library(mgcv); library(rowr)

#···········Setting Observation
setwd("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Forecast/Hindcast/SEAS5/ERA5")
load("/home/ry4902/Documents/Workflow/Atmosphere/ERA5/ERA5_daily_Interpolated.RData") #En realidad está de 1979-2013

#Setting available years for SEAS5 (1994-2016), from 1988-1994 can be used for warm-up
data.interp <- lapply(ERA5_daily.interp, function(x) subsetGrid(x, years = 1988:2016))

# Give format to dates
yymmdd <- as.Date(data.interp$uas$Dates$start)
hhmmss <- format(as.POSIXlt(data.interp$uas$Dates$start), format = "%H:%M:%S") 

data_matrix <- lapply(data.interp, function(x) x$Data)
# data.frame creation...Ojo: se repite 2019-01-01
df <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss)), data_matrix)
df$wtemp <- 0.799*df$tas+5.120
df <- df[1:which(df$dates1=="2016-11-30"),]

#Setting temperatures t_1 and t_2 for up and botton layers in GOTM: using EWEMBI simulation
data_ERA5 <- c()
for (depth in c(1, 50)){
  my.data <-open.nc("/home/ry4902/Documents/Workflow/Lake/GOTM/SAU/Reanalisis/ERA5/output.nc")
  my.object <- var.get.nc(my.data, "temp") #[220, 3631]
  if (depth==1){
    #data_ERA5 <- my.object[round(nrow(my.object)-(depth*220/60.54)),]
    data_ERA5 <- my.object[round(nrow(my.object)-(depth*120/60)),]
  }else{
    #data_ERA5 <- cbind.fill(data_ERAI, my.object[round(nrow(my.object)-(depth*220/60.54)),], fill = -9999)
    data_ERA5 <- cbind.fill(data_ERA5, my.object[round(nrow(my.object)-(depth*120/60)),], fill = -9999)
  }
}
level <- var.get.nc(my.data, "zeta") #[220, 3631]
data_ERA5 <- cbind.fill(data_ERA5, level, fill = -9999)
data_ERA5 <- data.frame(data_ERA5, date=seq(as.Date('1988-01-01'), as.Date('2020-01-31'), by=1))
colnames(data_ERA5) <- c("temp1","temp50","level", "dates1")

#Setting level values
#levels <- read.csv("/home/ry4902/Documents/GOTM/SAU/forcedbyERAI/ToPrepare/LevelAnalysis.csv")

#Inflow data ERA5
daily_discharge <- read.csv("/home/ry4902/Documents/Workflow/River/mhm-5.9_obs7/ERA5/Third_Ter/output_b1/daily_discharge.out", sep="")
df$inflow <- c(rep(-9999, (which(df$dates1==as.Date(paste(daily_discharge$Year[1], 
                                                          daily_discharge$Mon[1], 
                                                          daily_discharge$Day[1], sep="-")))-1)),
               daily_discharge$Qsim_0000000113[1:which(as.Date(paste(daily_discharge$Year, 
                                                                     daily_discharge$Mon, 
                                                                     daily_discharge$Day, sep="-"))=="2016-11-30")])

#Inflow data model
load("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/simulated.RData")
#Inflow initializers, ladmonth=0
load("/home/ry4902/Documents/Workflow/River/mHM_LeadMonth0/SEAS5/ERA5/Hindcast/TotalOutputs/initializers.RData")

is.leapyear=function(year){
  #http://en.wikipedia.org/wiki/Leap_year
  return(((year %% 4 == 0) & (year %% 100 != 0)) | (year %% 400 == 0))
}

#··········Setting Seasonal Forecasting Data
data_total_season <- list(); data_total_season_lead <- list(); num_season <- 0
for (season in c("autumn", "spring", "summer", "winter")){
  print(paste("··················Starts:", season, "·································"))
  print(paste("··················Starts:", season, "·································"))
  print(paste("··················Starts:", season, "·································"))
  print(paste("··················Starts:", season, "·································"))
  num_season <- num_season + 1
  load(paste("/home/ry4902/Documents/Workflow/Atmosphere/SEAS5/hindcast/BC_ERA5_SAU_SQD/", season,"_BC.RData", sep=""))
  #Cloud cover
  #data.bc.cross$cc <- data.bc.cross$tcc
  #Dew point
  data.bc.cross$tdew <- data.bc.cross$dp 
  data.bc.cross$petH <- data.bc.cross$pet
  
  # Give format to dates
  yymmdd <- as.Date(data.bc.cross$uas$Dates$start)
  hhmmss <- format(as.POSIXlt(data.bc.cross$uas$Dates$start), format = "%H:%M:%S") 
  
  data_matrix <- lapply(data.bc.cross, function(x) x$Data)
  
  data_total_member <- list(); data_total_member_lead <- list()
  for (member_number in 1:25){
    print(paste("··················Starts:", season, "·································"))
    print(paste("··················Starts member:", member_number, "·································"))
    print(paste("··················Starts member:", member_number, "·································"))
    print(paste("··················Starts member:", member_number, "·································"))
    
    data_matrix_member <- lapply(data_matrix, function(x) x[member_number,])
    # data.frame creation
    df_model <- data.frame(c(list("dates1" = yymmdd, "dates2" = hhmmss)), data_matrix_member)
    df_model$wtemp <- 0.799*df_model$tas+5.120
    
    #---------Setting streamflow data
    if (season=="winter"){
      inflow_data <- rbind(data.frame(No=1:30, Day=1:30, Mon=rep(11,30),Year=rep(1993,30), Qobs_0000000113=rep(-9999,30), Qsim_0000000113=rep(-9999,30)),
                           total_simulated[[member_number]])
      inflow_data$date1 <- as.Date(paste(inflow_data$Year, inflow_data$Mon, inflow_data$Day, sep="-"))
    }else{
      inflow_data <- total_simulated[[member_number]]
      inflow_data$date1 <- as.Date(paste(inflow_data$Year, inflow_data$Mon, inflow_data$Day, sep="-"))
    }
    
    df_model <- merge(df_model, data.frame(inflow=inflow_data$Qsim_0000000113, dates1=inflow_data$date1), by=c("dates1"))
    
    data_total_year <- c(); data_total_year_lead <- c()
    for (year in c(1994:2016)){
      print(paste("··················Starts:", season, "·································"))
      print(paste("··················Starts member:", member_number, "·································"))
      print(paste("··················Starts year:", year, "·································"))
      print(paste("··················Starts year:", year, "·································"))
      if (season=="autumn"){
        ini_day <- "01"; ini_month <- "09"; end_day <- "30"; end_month <- "11"
        ini_date <- as.Date(paste(year, ini_month, ini_day, sep="-"))
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
        end_date_lm0 <- as.Date(paste(year, "08", "31", sep="-"))
        ini_date_lm0 <- as.Date(paste(year, "08", "01", sep="-"))
      }
      if (season=="winter"){
        ini_day <- "01"; ini_month <- "12"; end_day <- "28"; end_month <- "02"
        ini_date <- as.Date(paste(year-1, ini_month, ini_day, sep="-"))
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
        end_date_lm0 <- as.Date(paste(year-1, "11", "30", sep="-"))
        ini_date_lm0 <- as.Date(paste(year-1, "11", "01", sep="-"))
      }
      if (season=="spring"){
        ini_day <- "01"; ini_month <- "03"; end_day <- "31"; end_month <- "05"
        ini_date <- as.Date(paste(year, ini_month, ini_day, sep="-"))
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
        end_date_lm0 <- as.Date(paste(year, "02", "28", sep="-"))
        ini_date_lm0 <- as.Date(paste(year, "02", "01", sep="-"))
      }
      if (season=="summer"){
        ini_day <- "01"; ini_month <- "06"; end_day <- "31"; end_month <- "08"
        ini_date <- as.Date(paste(year, ini_month, ini_day, sep="-"))
        end_date <- as.Date(paste(year, end_month, end_day, sep="-"))
        end_date_lm0 <- as.Date(paste(year, "05", "31", sep="-"))
        ini_date_lm0 <- as.Date(paste(year, "05", "01", sep="-"))
      }
      
      #Setting lead month data
      lead_month <- df_model[which(df_model$dates1==ini_date_lm0):which(df_model$dates1==end_date_lm0),]
      #Setting lead month inflow
      initializers <- total_initializers[[member_number]]
      initializers$dates1 <- as.Date(paste(initializers$Year, 
                                         initializers$Mon,
                                         initializers$Day, sep="-"))
      lead_month$inflow <- initializers[which(initializers$dates1==ini_date_lm0):which(initializers$dates1==end_date_lm0),]$Qsim_0000000113
      lead_month$pr <- lead_month$pr/(1000*24*60*60)#from mm/d to m/s
      lead_month <- lead_month[,c("dates1","dates2","uas","vas","dp","tas","cc","pr","rsds","rlds","pet","ps","tasmin","tasmax","wtemp","inflow")]
      
      #Setting seasonal forecast data
      model_total <- df_model[which(df_model$dates1==(ini_date)):which(df_model$dates1==end_date),]
      model_total$pr <- model_total$pr/(1000*24*60*60)#from mm/d to m/s
      model_total <- model_total[,c("dates1","dates2","uas","vas","dp","tas","cc","pr","rsds","rlds","pet","ps","tasmin","tasmax","wtemp","inflow")]
      
      #Merging all data to run: 1 year warm-up + 1 lead month + 3 months of seasonal forecast
      #Setting observation (No need it if level and temperature are set one day before the lead.month)
      observation_total <- df[which(df$dates1==(ini_date-365)):which(df$dates1==(ini_date_lm0-1)),]
      observation_total$evap<-NULL
      observation_total$uas <- abs(observation_total$uas)
      observation_total$pet <- observation_total$pet*-1000
      observation_total <- observation_total[,c("dates1","dates2","uas","vas","dp","tas","cc","pr","rsds","rlds","pet","ps","tasmin","tasmax","wtemp","inflow")]
      
      data_total <- list(obs=observation_total, leadmonth=lead_month, model=model_total)
      data_total <- rbind(data_total$obs, data_total$leadmonth[names(data_total$obs)], data_total$model[names(data_total$obs)])

      #Merging all data to run: 1 lead month + 3 months of seasonal forecast
      #data_total <- list(leadmonth=lead_month, model=model_total)
      #data_total <- rbind(data_total$leadmonth, data_total$model)
      
      #Saving files needed to run GOTM

      #Saving meteofile:dates, hours, E_Wind, N_Wind, pressure in hPa and the rest the variables
      meteo <- cbind(data_total[,1:2], round(data_total[c("uas", "vas", "ps", "tas", "dp", "cc", "rsds")],2), data_total[c("pr")])

      write.table(meteo, paste(getwd(), "/meteo_file.dat", sep=""),
                  sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)

      #Saving inflow file
      inflow_save <- cbind(data_total[,1:2], round(data_total$inflow, 2), round(data_total$wtemp, 2))
      if (NaN %in% inflow_save[,3]){
        data_to_save <- data_total[which(data_total$dates1==(ini_date)):which(data_total$dates1==end_date),]
        data_to_save <- data.frame(data_to_save, temp0=rep(NaN, nrow(data_to_save)),
                                   temp5=rep(NaN, nrow(data_to_save)),
                                   temp10=rep(NaN, nrow(data_to_save)),
                                   temp15=rep(NaN, nrow(data_to_save)),
                                   temp20=rep(NaN, nrow(data_to_save)),
                                   temp30=rep(NaN, nrow(data_to_save)),
                                   temp40=rep(NaN, nrow(data_to_save)),
                                   temp50=rep(NaN, nrow(data_to_save)),
                                   level=rep(NaN, nrow(data_to_save)))
        
        data_to_save_lead <- data_total[which(data_total$dates1==(ini_date_lm0)):which(data_total$dates1==end_date_lm0),]
        data_to_save_lead <- data.frame(data_to_save_lead, temp0=rep(NaN, nrow(data_to_save_lead)),
                                        temp5=rep(NaN, nrow(data_to_save_lead)),
                                        temp10=rep(NaN, nrow(data_to_save_lead)),
                                        temp15=rep(NaN, nrow(data_to_save_lead)),
                                        temp20=rep(NaN, nrow(data_to_save_lead)),
                                        temp30=rep(NaN, nrow(data_to_save_lead)),
                                        temp40=rep(NaN, nrow(data_to_save_lead)),
                                        temp50=rep(NaN, nrow(data_to_save_lead)),
                                        level=rep(NaN, nrow(data_to_save_lead)))
        
        data_total_year <- rbind(data_total_year, data_to_save) 
        data_total_year_lead <- rbind(data_total_year_lead, data_to_save_lead)
      }else{
        write.table(inflow_save, paste(getwd(), "/inflow.dat", sep=""),
                    sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
        
        #Changing obs.nml and gotmrun.nml files according to start and end dates
        #File to change: gotm.yaml
        gotmyaml_file  <- readLines(paste(getwd(),"/gotm.yaml", sep=""))
        gotmyaml_file[10] <- paste("   start : ",  (ini_date-365), " 00:00:00", sep="") 
        gotmyaml_file[11] <- paste("   stop : ",  end_date, " 00:00:00", sep="") 
        gotmyaml_file[26] <- paste("      t_1 : ",  round(data_ERA5$temp1[which(as.Date(data_ERA5$dates1)==(ini_date-365))],2), sep="")
        gotmyaml_file[27] <- paste("      t_2 : ",  round(data_ERA5$temp50[which(as.Date(data_ERA5$dates1)==(ini_date-365))],2), sep="")
        writeLines(gotmyaml_file, con=paste(getwd(),"/gotm.yaml", sep=""))

        #Running GOTM model
        system("./gotm")
        print(paste("··················Model run season:", season, "·································"))
        print(paste("··················Model run member:", member_number, "·································"))
        print(paste("··················Model run year:", year, "·································"))
        print(paste("··················Model run Finished·································"))
        
        
        names_data <- colnames(data_total)
        temperature <- c() 
        #c("abiotic_water_sDDOMW", "abiotic_water_sDIMW", "abiotic_water_sDPOMW")
        #c("phytoplankton_water_oChlaBlue", "phytoplankton_water_oChlaDiat", "phytoplankton_water_oChlaGren")
        #abiotic_water_sO2W
        
        #if (is.leapyear(year) ){
        
        #}
        leap_year_date <- 0
        for (depth in c(0,5,10,15,20,30,40,50)){ #
          my.data <-open.nc(paste(getwd(), "/output.nc", sep=""))
          my.object <- var.get.nc(my.data, "temp") #[220, 3631]
          temperature <- my.object[round(nrow(my.object)-(depth*120/60)),]
          #temperature <- my.object[round(nrow(my.object)-(depth*220/120)),]
          if (nrow(data_total)!=length(temperature)){
            leap_year_date <- which(seq(ini_date-365, end_date, by=1)==paste(year, "02", "29", sep = "-"))
            temperature <- temperature[-leap_year_date]
          }
          #if(length(leap_year_date)==1){
          #  temperature <- temperature[-leap_year_date]
          #}
          data_total <- cbind(data_total, temperature)
          names_data <- c(names_data, paste("temp", depth, sep=""))
        }
        level <- var.get.nc(my.data, "zeta") #[220, 3631]
        if(length(leap_year_date)==1 & nrow(data_total)!=length(level)){
          level <- level[-leap_year_date]
        }
        #data_total <- cbind.fill(data_total, level, fill = -9999)
        data_total <- cbind(data_total, level)
        names_data <- c(names_data, "level")
        colnames(data_total) <-  names_data
        
        #Exporting water quality variables: 
        #MO = sDDOMW+sDIMW+sDPOMW
        #for (MO in c("abiotic_water_sDDOMW", "abiotic_water_sDIMW", "abiotic_water_sDPOMW")){
        #  variable_MO <- var.get.nc(my.data, MO) #[220, 3631]
        #  data_total <- cbind.fill(data_total, variable_MO, fill = -9999)
        #  names_data <- c(names_data, MO)
        #  colnames(data_total) <-  names_data
        #}
        #clorofila 
        data_to_save <- data_total[which(data_total$dates1==(ini_date)):which(data_total$dates1==end_date),]
        data_to_save_lead <- data_total[which(data_total$dates1==(ini_date_lm0)):which(data_total$dates1==end_date_lm0),]
        
        data_total_year <- rbind(data_total_year, data_to_save) 
        data_total_year_lead <- rbind(data_total_year_lead, data_to_save_lead)
      }
      
      #data_total_year <- rbind(data_total_year, data_to_save) 
      #data_total_year_lead <- rbind(data_total_year_lead, data_to_save_lead)
      
    }
    data_total_member[[member_number]] <- data_total_year
    data_total_member_lead[[member_number]] <- data_total_year_lead
  }
  data_total_season[[num_season]] <- data_total_member
  data_total_season_lead[[num_season]] <- data_total_member_lead
  save.image(paste(getwd(),"/Output/season", num_season,".RData", sep=""))
}
names(data_total_season) <- c("autumn", "spring", "summer", "winter")
save(data_total_season, file=paste(getwd(),"/Output/data_total_season.RData", sep=""))

names(data_total_season_lead) <- c("autumn", "spring", "summer", "winter")
save(data_total_season_lead, file=paste(getwd(),"/Output/data_total_season_lead.RData", sep=""))