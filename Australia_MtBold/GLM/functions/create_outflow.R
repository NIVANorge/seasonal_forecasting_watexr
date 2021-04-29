create_outflow <- function(glm_nml, matrix_file, index = 1){
  start <- glmtools::get_nml_value(glm_nml, arg_name = 'start')
  stop <- glmtools::get_nml_value(glm_nml, arg_name = 'stop')
  
  date <- seq.POSIXt(as.POSIXct(start, yz = 'UTC'), as.POSIXct(stop, tz = 'UTC'), '1 day')
  df <- data.frame(date = date, yday = lubridate::yday(date))
  
  with <- read.csv(matrix_file)
  if(index == 'mean'){
    mn = apply(with[,-1], 1, mean)
    with <- cbind(with[,1], mn)
    colnames(with)[1] <- 'yday'
  }else{
    with <- with[,c(1,(1+index))]
  }
  
  df2 <- merge(df, with, by = 'yday')
  df2 <- df2[order(df2$date), ]
  df2$yday <- NULL
  
  colnames(df2) <- c('Time', 'FLOW')
  write.csv(df2, 'outflow.csv', row.names = F, quote = F)
  
  glm_nml <- glmtools::set_nml(glm_nml, 'num_outlet', 1)
  glm_nml <- glmtools::set_nml(glm_nml, 'outflow_fl', 'outflow.csv')
  return(glm_nml)
}
