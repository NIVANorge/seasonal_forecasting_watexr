create_meanflow <- function(glm_nml = NULL, start, stop, matrix_file, fname, index = 1){
  
  if(!is.null(glm_nml)) {
    start <- glmtools::get_nml_value(glm_nml, arg_name = 'start')
    stop <- glmtools::get_nml_value(glm_nml, arg_name = 'stop')
  }
  
  
  date <- seq.POSIXt(as.POSIXct(start, tz = 'UTC'), as.POSIXct(stop, tz = 'UTC'), '1 day')
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
  df2$Time <- format(df2$Time, format = '%Y-%m-%d %H:%M:%S')
  write.csv(df2, fname, row.names = F, quote = F)
}
