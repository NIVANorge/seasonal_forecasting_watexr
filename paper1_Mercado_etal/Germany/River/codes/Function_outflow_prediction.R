outflow_fix <- function(model,outflow, inflow_mod, warmup_dates, fc_dates, out_file){
  outflow.fc = predict(model, data.frame(inflow= inflow_mod[which(as.POSIXct(inflow_mod[,1], tz = 'UTC') %in% as.POSIXct(fc_dates, tz = 'UTC')),2]))
  outflow.warmup = outflow[which(as.POSIXct(outflow[,1], tz = 'UTC') %in%as.POSIXct(warmup_dates, tz = 'UTC')),2]
  my.outflow <- data.frame(time= c(as.POSIXct(warmup_dates, tz = 'UTC'), as.POSIXct(fc_dates, tz = 'UTC')), flow= c(outflow.warmup, outflow.fc))
  write.csv(my.outflow, out_file, row.names = F, quote = F)
 return(my.outflow)
}

