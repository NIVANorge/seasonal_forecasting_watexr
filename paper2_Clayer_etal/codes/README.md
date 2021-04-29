# Codes
explore_datasets.m is used to import data from all csv files (with 28 columns: date, obs, ERA5, SEAS5 x 25 mbs) contained in the containing folder.
It calls other functions (stat_terc_test.m; stats_all_calc.m; nashsutcliffe.m; corrcoef.m) to calculate basic stastistics (NS, R_2, RMSE, RMSE/sd, bias) comparing seasonal means of ERA5 vs obs, SEAS5 vs ERA5 and SEAS5 vs obs. It summarizes the statistics in a variety of tables saved as txt files, and one data overview figure.
