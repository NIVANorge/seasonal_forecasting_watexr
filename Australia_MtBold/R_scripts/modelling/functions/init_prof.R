#' Create initial profile for GOTM
#'
#' Extract and format the initial profile for GOTM from the observation file used in ACPy.
#'
#' @param obs_file filepath; Path to observation file
#' @param date character; Date in "YYYY-mm-dd HH:MM:SS" format to extract the initial profile. If using month, the date to which to set the start date
#' @param tprof_file filepath; For the new initial temperature profile file.
#' @param month numeric;select a month if you want to use an 'average profile from a particular month. Defaults to NULL.
#' @param ndeps numeric; number of depths to extract from the monthly average profile. Defaults to 2 (surface and bottom)
#' @param btm_depth numeric; Depth to extract the bottom temperature from, must be negative. If none provided uses the max depth in the observed file. Defaults to NULL
#' @param print logical; Prints the temperature profile to the console
#' @param ... arguments to be passed to read.delim() for reading in observed file e.g "header = TRUE, sep = ','"
#' @return Message stating if the file has been created
#' @import utils
#' @importFrom lubridate month
#' @export
init_prof <- function(obs_file, date, tprof_file, month = NULL, ndeps = 2, btm_depth = NULL, print = TRUE, ...){
  obs <- read.delim(obs_file, stringsAsFactors = F, ...)
  if(!is.null(month)){
    obs[,1] <- as.POSIXct(obs[,1], tz = 'UTC')
    obs$month <- month(obs[,1])
    sub = obs[(obs$month == month),]
    if(nrow(sub) == 0){
      stop('No measurements for that month. Select a different month')
    }
    sub$fdepth <- factor(sub[,2])
    library(plyr)
    sub2 <- ddply(sub, 2, function(df) {
      mn = mean(df[,3], na.rm = T)
      return(mn)
    })
    sub2[,1] <- as.numeric(as.character(sub2[,1]))
    if(is.null(btm_depth)){
      btm = min(sub2[,1])
    }else{
      btm = btm_depth
    }
    top = max(sub2[,1])
    deps = seq(btm, top, length.out = ndeps)
    avg_prof = approx(x = sub2[,1], y = sub2[,2], xout = deps)
    deps = avg_prof$x
    tmp = avg_prof$y
  }else{
    #obs[,1] <- as.POSIXct(obs[,1], tz = 'UTC')
    dat = which(obs[,1] == date)
    ndeps = length(dat)
    deps = obs[dat,2]
    tmp = obs[dat,3]
  }
  tmp = tmp[order(-deps)]
  deps = deps[order(-deps)]
  df <- matrix(NA, nrow =1+ndeps, ncol =2)
  df[1,1] <- date
  df[1,2] <- paste0(ndeps,' ',2)
  df[(2):(1+ndeps),1] = as.numeric(deps)
  df[(2):(1+ndeps),2] = as.numeric(tmp)
  write.table(df, tprof_file, quote = F, row.names = F, col.names = F,
              sep = "\t")
  message('New inital temperature file ', tprof_file, ' has been created.')
  if(print == TRUE){
    print(df)
  }
}
