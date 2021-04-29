outflow_fix <- function(inflow_obs, inflow_mod, outflow_obs, min_outflow, out_file, inflow_add_file, met, airt){
  
  outflow.diff <- data.frame(date=as.Date(inflow_mod[,1]), flow=inflow_obs[which(as.Date(inflow_obs[,1])%in%as.Date(inflow_mod[,1])),2] - inflow_mod[,2])
  
  inflow.add <- inflow_obs[which(as.Date(inflow_obs$date)%in%as.Date(met[,1])),]
  inflow.add[,2] <- rep(0,length(inflow.add[,1]))
  collector5 <- NULL
  for (j in 5:length(airt)) {
    
    x5 <- mean(c(airt[j],airt[j-1],airt[j-2],airt[j-3],airt[j-4]))
    
    collector5 <- c(collector5, x5)
    
  }
  
  
  
  inflow.temp.5days<- 3.79945+0.73078*collector5
  inflow.temp.1day <- 4.37786+0.66756*airt[1:4]
  
  inflow.temp <- c(inflow.temp.1day,inflow.temp.5days)
  
  inflow.temp[which(inflow.temp<4)] <- 4
  inflow.add[,3] <- inflow.temp
  date2index <- outflow.diff$date[which(outflow.diff$flow > min_outflow)]
  
  inflow.add[which(as.Date(met[,1])%in%as.Date(date2index)),2] <- outflow.diff$flow[which(outflow.diff$flow > min_outflow)]
  #outflow.fixed[which(outflow.fixed <= min_outflow)] <- min_outflow
  outflow2write <- data.frame(date=as.Date(met[,1]), flow= rep(0,length(met[,1])))
  date2index2 <- outflow.diff$date[which(outflow.diff$flow < min_outflow)]
  outflow2write[which(as.Date(outflow2write[,1])%in%as.Date(date2index2)),2] <- -1*outflow.diff$flow[which(outflow.diff$flow < min_outflow)]
  
  water_balance_correction <- data.frame(date=as.Date(met[,1]), outflow=outflow2write$flow, inflow=inflow.add$flow)
  write.csv(outflow2write, out_file, row.names = F, quote = F)
  write.csv(inflow.add,inflow_add_file, row.names = F, quote = F )
  return(water_balance_correction)
}

