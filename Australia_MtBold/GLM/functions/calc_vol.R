calc_vol <- function(height, nml_file = NULL, bathA, bathD){
  if(!is.null(nml_file)){
    nml <- glmtools::read_nml(nml_file)
    bathA <- get_nml_value(nml, 'A')
    bathD <- get_nml_value(nml, 'H')
  }
  
  top <- max(bathD)
  bottom <- min(bathD)
  surf <- bottom + height
  layer_d <- seq(top, bottom, -0.1)
  ind <- which(layer_d <= surf)
  layer_a <- stats::approx(bathD, bathA, layer_d[ind])$y
  layer_d <- layer_d[ind]
  vols <- c()
  vols <- lapply(2:length(layer_d), function(i){
    h <- abs(layer_d[i] - layer_d[i - 1])
    cal_v <- (h / 3) * (layer_a[i] + layer_a[i - 1] + sqrt(layer_a[i] * layer_a[i - 1]))
    vols <- c(vols, cal_v)
  })
  vol_hyp <- sum(unlist(vols))
  return(vol_hyp)
}
