#' Create hypsograph based on the initialisation height of the reservoir
#'
#' GOTM needs the hypsograph to match the height of the initial water level if using a prescribed water level. This function adjusts the hypsograph to match the initial water level.
#'
#' @param in_file filepath; File which contains the input data which has two columns; year day and lake level
#' @param out_file filepath; File which is to be written with prescribed level.
#' @examples 
#' in_file = 'hypsograph.dat'
#' out_file = 'norm_hypsograph.dat'
#' lake_level = 35.4
#' match_hyps(in_file, out_file, lake_level)
#' @export
match_hyps <- function(in_file, out_file, lake_level){
  headr <-read.delim(in_file, header = F, sep = ' ', nrows = 1)
  inp <- read.delim(in_file, skip = 1, header = F, sep = ' ')
  new <- inp
  offset <- new[nrow(new),1] -- lake_level
  new[,1] <- new[,1] -offset
  colnames(new) <- headr
  write.table(new, out_file, quote = F, row.names = F, col.names = T, sep = '\t')
  message('Wrote new hypsograph file: ', out_file)
  
}
