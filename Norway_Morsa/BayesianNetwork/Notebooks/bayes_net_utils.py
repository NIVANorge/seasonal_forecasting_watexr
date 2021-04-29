def bayes_net_predict(rfile_fpath, sd_fpath, year, chla_prev_summer, colour_prev_summer,
                      tp_prev_summer, wind_speed, rain):
    """ Make predictions given the evidence provided based on a pre-fitted Bayesian network.
        This function is just a thin "wrapper" around the R function named 'bayes_net_predict' in 'bayes_net_utils.R'. See also bayes_net_predict_operational.
        
        NOTE: 'bayes_net_utils.R' must be in the same folder as this file.
        
    Args:
        rfile_fpath:       Str. Filepath to fitted BNLearn network object (.rds file)
        sd_fpath:          Str. Filepath to csv containing standard deviation info from fitted BN
        year:              Int. Year for prediction
        chla_prevSummer:   Float. Chl-a measured from the previous summer  (mg/l)
        colour_prevSummer: Float. Colour measured from the previous summer (mg Pt/l)
        TP_prevSummer:     Float. Total P measured from the previous summer (mg/l)
        wind_speed:        Float. Predicted wind speed for season of interest (m/s)
        rain:              Float. Predicted precipitation for season of interest (mm)
    
    Returns:
        Dataframe with columns 'year', 'node', 'threshold', 'prob_below_threshold',
       'prob_above_threshold', 'expected_value', 'sd' (standard deviation)
    """
    import pandas as pd
    import rpy2.robjects as ro
    from rpy2.robjects.packages import importr
    from rpy2.robjects import pandas2ri
    from rpy2.robjects.conversion import localconverter
    
    # Load R script
    ro.r.source('bayes_net_utils.R')

    # Call R function with user-specified evidence
    res = ro.r['bayes_net_predict'](rfile_fpath, sd_fpath, year, chla_prev_summer, colour_prev_summer,
                                    tp_prev_summer, wind_speed, rain)

    # Convert back to Pandas df
    with localconverter(ro.default_converter + pandas2ri.converter):
        df = ro.conversion.rpy2py(res)
    
    # Add 'year' to results as unique identifier
    df['year'] = int(year)
    df.reset_index(drop=True, inplace=True)
    
    # Add predicted WFD class
    df['WFD_class'] = df[['threshold','expected_value']].apply(lambda x: discretize([x.threshold], x.expected_value), axis=1)

    return df

def bayes_net_predict_operational(rfile_fpath, year, chla_prev_summer, colour_prev_summer,
                                  tp_prev_summer):
    """ Make predictions given the evidence provided based on the pre-fitted Bayesian network.
        This function is just a thin "wrapper" around the R function named 'bayes_net_predict_operational' in 'bayes_net_utils.R'.
        
        Very similar to bayes_net_predict, but:
        - Drop met nodes for operational forecast
        - Only forecast for TP, colour and cyano (not chla)).
        - Remove standard deviations which were in bayes_net_predict function, as these have changed and aren't used now anyway
        
        NOTE: 'bayes_net_utils.R' must be in the same folder as this file.
        
    Args:
        rfile_fpath:       Str. Filepath to fitted BNLearn network object (.rds file)
        year:              Int. Year for prediction
        chla_prevSummer:   Float. Chl-a measured from the previous summer  (mg/l)
        colour_prevSummer: Float. Colour measured from the previous summer (mg Pt/l)
        TP_prevSummer:     Float. Total P measured from the previous summer (mg/l)
    
    Returns:
        Dataframe with columns 'year', 'node', 'threshold', 'prob_below_threshold',
       'prob_above_threshold', 'expected_value'
    """
    import pandas as pd
    import rpy2.robjects as ro
    from rpy2.robjects.packages import importr
    from rpy2.robjects import pandas2ri
    from rpy2.robjects.conversion import localconverter
    
    # Load R script
    ro.r.source('bayes_net_utils.R')

    # Call R function with user-specified evidence
    res = ro.r['bayes_net_predict_operational'](rfile_fpath, year, chla_prev_summer, colour_prev_summer,
                                                tp_prev_summer)

    # Convert back to Pandas df
    with localconverter(ro.default_converter + pandas2ri.converter):
        df = ro.conversion.rpy2py(res)
    
    # Add 'year' to results as unique identifier
    df['year'] = int(year)
    df.reset_index(drop=True, inplace=True)
    
    # Add predicted WFD class
    df['WFD_class'] = df[['threshold','expected_value']].apply(lambda x: discretize([x.threshold], x.expected_value), axis=1)

    return df

    
def classification_error(obs, pred):
    """
    Calculate classification error, the proportion of time the model predicted the class correctly
    
    Input:
        obs: series of observed classes, numeric formats only
        pred: series of predicted classes (must be aligned to obs), numeric formats only
    Output:
        Classification error (float)
    """
    import pandas as pd, numpy as np

    assert len(obs) == len(pred), "observed and predicted series have different lengths"
    
    # Were observed and predictions in the same class? 'right' col is a boolean, 1=Yes the same, 0=no different
    right = np.where((obs == pred), 1, 0)

    classification_error = 1 - (right.sum() / len(right))
    
    return classification_error


def daily_to_summer_season(daily_df):
    """
    Take a dataframe with daily frequency data, and aggregate it to seasonal (6 monthly), just picking results for the summer (May-Oct) season.
    Input: dataframe of daily data. Column names should match those defined in agg_method_dict.keys() (rain, colour, TP, chla, wind_speed, cyano). Any extras need adding to the dictionary.
    Returns: dataframe of seasonally-aggregated data
    """
    import numpy as np, pandas as pd
    # Turn off "Setting with copy" warning, which is returning a false positive
    pd.options.mode.chained_assignment = None  # default='warn'
    
    agg_method_dict = {'rain': np.nansum,
                       'colour': np.nanmean,
                       'TP': np.nanmean,
                       'chla': np.nanmean,
                       'chl-a': np.nanmean,
                       'wind_speed': np.nanmean,
                       'cyano': np.nanmax
                      }
    
    # Drop any dictionary keys that aren't needed
    for key in list(agg_method_dict.keys()):
        if key not in daily_df.columns:
            del agg_method_dict[key]

    # Resample ('Q' for quarterly, '-month' for month to end in). If season function changes, need to change this too
    # Returned df: winter values are stored against the year that corresponds to the second half of the winter (e.g. Nov 99-Apr 2000 stored as 2000).
    # The shift is needed because otherwise the last day of the period (corresponding to the label) is omitted. Checked manually and right.
    season_df = daily_df.shift(periods=-1).resample('2Q-Apr', closed='left').agg(agg_method_dict)

    # Remove frequncy info from index so plotting works right
    season_df.index.freq=None

    # Remove winter rows (a bit long-winded, but works)
        
    def season(x):
        """Input month number, and return the season it corresponds to
        """
        if x in [11,12,1,2,3,4]:
            return 'wint'
        else:
            return 'summ'
        
    season_df['Season'] = season_df.index.month.map(season)    
    summer_df = season_df.loc[season_df['Season']=='summ']
    summer_df.drop('Season',axis=1,inplace=True)

    # Reindex
    summer_df['year'] = summer_df.index.year
    summer_df.set_index('year', inplace=True)
    
    return summer_df


def discretize(thresholds, value):
    """
    Function to compare a number to a list of thresholds and categorise accordingly. E.g. to apply row-wise down a df to
    convert from continuous to categorical data.
    Input:
        thresholds: list of class boundaries that define classes of interest
        value: float to be compared to the thresholds
    Returns: class the value lies in. Classes are defined in factor_li_dict within function according to number of thresholds
    (max 2 class boundaries (thresholds) supported at present)
    
    e.g. of usage:
    # E.g. 1:
    bound_dict = {'TP':[29.5]}
    for col in continuous_df.columns:
        disc_df[col] = continuous_df[col].apply(lambda x: discretize(bound_dict['TP'], x))
    # E.g. 2:
    df['WFD_class'] = df[['threshold','expected_value']].apply(lambda x: discretize([x.threshold], x.expected_value), axis=1)
    """
    import numpy as np
    
    if np.isnan(value):
        return np.NaN
    
    factor_li_dict = {2: [0, 1],
                     3: [0, 1, 2],} # Originally returned class as a string, don't know why. Have changed to integer, may break something...
    
    n_classes = len(thresholds)+1
    
    for i, boundary in enumerate(thresholds):
    
        if value<boundary:
            return factor_li_dict[n_classes][i]
            break # Break out of loop
        
        # If we're up to the last class boundary, and the value is bigger than it, value is in the uppermost class
        if i+1 == len(thresholds) and value >= boundary:
            return factor_li_dict[n_classes][i+1]


def late_summer_met_data(era5_df, s5_df):
    """
    Create daily met data series used for updating Bayesian network predictions during the late summer forecast.
    This daily series is a composite of era5 data for May and June, and System5 data for July-Oct
    Inputs: era5_df, dataframe of daily era5 data; s5_df, dataframe of daily system5 data
    Returns: dataframe of daily met data for the period May-Oct, with the same cols as were present in s5_df.
    """
    import pandas as pd
    # Truncate era5 to start and end dates of s5 data
    era5_df = era5_df.loc['%s-01-01' %s5_df.index.year[0] : '%s-12-31' %s5_df.index.year[-1], :]                
    s5_df = s5_df.reindex_like(era5_df) # S5 data is missing any month outside July-Oct. Add this.
    # Make a new dataframe with joined columns
    met_df = s5_df.copy()
    for col in list(met_df.columns):
        met_df.loc[met_df.index.month.isin([5,6]), col] = era5_df.loc[era5_df.index.month.isin([5,6]), col]
    
    return met_df


def read_era5_csv(fpath):
    """
    Read era5 csv. Calculate wind speed and rename columns ready for seasonal aggregation for use in BBN.
    Input: string giving era5 csv filepath    
    returns: dataframe of daily values with columns 'rain' and 'wind_speed'
    """
    import os, pandas as pd, numpy as np
    met_df = pd.read_csv(fpath, index_col=0, parse_dates=True, dayfirst=True)
    met_df['wind_speed'] = np.sqrt((met_df['uas']**2) + (met_df['vas']**2))
    met_df = met_df[['tp','wind_speed']]
    met_df.columns = ['rain','wind_speed']
    met_df.index.name = 'Date'
        
    return met_df


def read_s5_csv(s5_met_folder, season, member):
    """
    Read data from the system5 csv located in s5_met_folder for the given season and member, picking the csv that is bias corrected using
    era5 data. Calculate wind speed and rename columns ready for seasonal aggregation for use in BBN.
    Inputs:
    s5_met_folder: string. path to folder containing s5 csvs
    season: string. season of interest. Must match name within files in s5_met_folder
    member: string. member number as two figure string (e.g. '01','02',...'10'). Must be present in s5_met_folder members
    
    returns: dataframe of daily values with columns 'rain' and 'wind_speed'
    """
    import os, pandas as pd, numpy as np
    s5_fpath = os.path.join(s5_met_folder, "s5_morsa_bayes_net_merged_%s_member%s_bc.csv" %(season, member))
    met_df = pd.read_csv(s5_fpath, index_col=0, parse_dates=True, dayfirst=True)
    met_df['wind_speed'] = np.sqrt((met_df['uas']**2) + (met_df['vas']**2))
    met_df = met_df[['tp','wind_speed']]
    met_df.columns = ['rain','wind_speed']
    met_df.index.name = 'Date'
        
    return met_df


def tercile_plot_from_dataframes(obs_df, s5_df, var_name, pdf_path):
    """ Creates a tercile plot for visualisation of forecast skill of seasonal climate 
        predictions. This function is just a thin "wrapper" around the R function named 
        'tercile_plot_from_dataframes' in 'bayes_net_utils.R'.
        
        NOTE: 'bayes_net_utils.R' must be in the same folder as this file.
        
        Each dataframe MUST contain data for only a single node/variable.
    
    Args:
        obs_df:   Dataframe. Must have columns named 'year', 'node' and 'value'
        s5_df:    Dataframe. Must have columns named 'year', 'node' and 'sim_s5_01' to 
                  'sim_s5_25' 
        var_name: Str. Name of variable for use in plot title
        pdf_path: Str. File path for PDF to be created
    
    Returns:
        None. The tercile plot is saved as a PDF to 'pdf_path'.
    """
    import pandas as pd
    import rpy2.robjects as ro
    from rpy2.robjects.packages import importr
    from rpy2.robjects import pandas2ri
    from rpy2.robjects.conversion import localconverter
 
    # Check input data
    assert len(obs_df['node'].unique()) == 1, "'obs_df' must contain data for only a single node/variable."
    assert len(s5_df['node'].unique()) == 1, "'s5_df' must contain data for only a single node/variable."
    assert obs_df['year'].duplicated().all() == False, "'obs_df' has duplicated years."
    assert s5_df['year'].duplicated().all() == False, "'s5_df' has duplicated years."
    
    # Sort by year
    obs_df = obs_df.sort_values(by='year').reset_index(drop=True)
    s5_df = s5_df.sort_values(by='year').reset_index(drop=True)
    
    # Intersect years
    df = pd.merge(obs_df, s5_df, how='inner', on=['year', 'node'])
    if (len(df) != len(obs_df)) or (len(df) != len(s5_df)):
        print("WARNING: Years in 'obs_df' and 's5_df' are not the same. Terciles will be computed based on the intersection of years.")
    obs_df = df[obs_df.columns]
    s5_df = df[s5_df.columns]
        
    # Load R script
    ro.r.source('bayes_net_utils.R')
    
    # Convert to R df
    with localconverter(ro.default_converter + pandas2ri.converter):
        obs_df_r = ro.conversion.py2rpy(obs_df)
        s5_df_r = ro.conversion.py2rpy(s5_df)

    # Call R function with user-specified evidence
    res = ro.r['tercile_plot_from_dataframes'](obs_df_r, s5_df_r, var_name, pdf_path)
    
    return None