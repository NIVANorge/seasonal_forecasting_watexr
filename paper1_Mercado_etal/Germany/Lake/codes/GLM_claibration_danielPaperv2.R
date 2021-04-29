library(glmtools)
# 
setwd("C:\\Users\\shikhani\\Documents\\WatexR_MS")


calib_setup <- data.frame('pars' = as.character(c('wind_factor','Kw','lw_factor',"strm_hf_angle","strmbd_slope","strmbd_drag")),
                          'lb' = c(0.75,0.4,0.8,82,0.1,0.02),
                          'ub' = c(1.25,1.1,1.2,88,5,0.06),
                          'x0' = c(0.8,0.6,1,85,2.5,0.02))


print(calib_setup)

#Example calibration
sim_folder <-  "GLM/GLM3_GR6J_ERA5_2calibrate/"
my_field <- "temp_profiles12.csv"

#field_file <- file.path(sim_folder, 'LakeMendota_field_data_hours.csv')
nml_file <- file.path(sim_folder, 'glm3.nml')

period = get_calib_periods(nml_file = nml_file, ratio = 3)
period

period$calibration$start<- "1992-12-31 12:00:00"
period$calibration$stop <- "2010-12-31 12:00:00"
period$validation$start <- "2011-01-01 12:00:00"
period$validation$stop <- "2016-12-31 12:00:00"

period
#period1 <- period
output = file.path(sim_folder, 'output/output.nc')

var = 'temp' # variable to apply the calibration procedure
calibrate_sim(var = var, path = sim_folder, field_file = my_field,
              nml_file = nml_file, calib_setup = calib_setup,
              glmcmd = NULL,
              first.attempt =T,  period = period, method = 'CMA-ES',
              scaling = TRUE, #scaling should be TRUE for CMA-ES
              verbose = FALSE,
              metric = 'RMSE',plotting = F,
              target.fit = 1,
              target.iter = 150, output = output)

#initvalues <- get_calib_init_validation(nml = nml_file, output = nc_file)
