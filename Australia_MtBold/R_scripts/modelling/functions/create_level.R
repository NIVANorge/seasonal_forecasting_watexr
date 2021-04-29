#' Create lake level file based on a typical year
#'
#' Constructs a daily time series of lake level from a standard supplied year for Mt. Bold
#'
#' @param from as.POSIXct; Date for which to start the time series
#' @param to as.POSIXct; Date for which to end the time series
#' @param in_file filepath; File which contains the input data which has two columns; year day and lake level
#' @param out_file filepath; File which is to be written with prescribed level.
#' @examples from = as.POSIXct('2010-01-01')
#' to = as.POSIXct('2011-01-01')
#' in_file = 'median_height.dat'
#' out_file = 'level.dat'
#' @export

create_level <- function(from, to, in_file, out_file){
  inp <- read.delim(in_file, header = T)
  dates <- seq.POSIXt(from = from, to = to, by = '1 day')
  df = data.frame(dates = dates, yday = yday(dates))
  new <- df
  new$level <- NA
  for(i in 1:nrow(new)){
    new$level[i] <- inp[which(inp$yday == new$yday[i]),2]
  }
  new <- new[,c(1,3)]
  new[,1] <- format(new[,1], format = '%Y-%m-%d %H:%M:%S')
  colnames(new) <- c('!Date', 'level')
  write.table(new, out_file, row.names = F, col.names = T, quote = F, sep = '\t')
  message('Wrote new wlevel file: ', out_file)
  return(new[1,2])
}