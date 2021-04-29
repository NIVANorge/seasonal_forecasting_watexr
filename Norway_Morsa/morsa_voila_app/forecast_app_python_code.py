import subprocess
import pandas as pd
import numpy as np
import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import warnings
import shutil
import datetime as dt
import glob
from pylatex import *
from pylatex.utils import *

def get_seasonal_forecast(year, season):
    """ Downloads and bias-corrects (without CV) the 15-member S4 seasonal forecast 
        for the specified year and season. Uses seasons as defined for the Bayesian 
        network:
        
            winter:       11, 12,  1
            spring:        2,  3,  4
            early_summer:  5,  6,  7
            late_summer:   8,  9, 10
            
        This function takes a while to run and calls a R script in a separate process.
        Progress reporting and error handling is currentlt non-existent and should be
        improved.
        
    Args:
        year:   Int. Year of interest
        season: Str. One of the seasons, as defined above
        
    Returns:
        Int. Subprocess return code. Should be 0 if R script is successful.
    """
    
    # Validate input and get months
    months_dict = {'winter':      '11,12,1',
                   'spring':      '2,3,4',
                   'early_summer':'5,6,7',
                   'late_summer': '8,9,10',
                  }
    
    res = subprocess.check_call(['Rscript',
                                 '--vanilla',
                                 'forecast_app_r_code.R',
                                 str(year),
                                 months_dict[season]],
                                cwd=os.path.dirname(os.path.realpath(__file__)), 
                               )
    
    return res

def get_season(row):
    """ Classifies seasons in dataframe based on months.
    """
    if row['date'].month in (11, 12, 1):
        return 'winter'
    elif row['date'].month in (2, 3, 4):
        return 'spring'
    elif row['date'].month in (5, 6, 7):
        return 'early_summer'
    elif row['date'].month in (8, 9, 10):
        return 'late_summer'
    else:
        return np.nan
    
def calculate_ewembi_quantiles(ewembi_path, quant_path, quants=[0.05, 0.33, 0.67, 0.95],
                               names=['date', 'time', 'uas', 'vas', 'ps', 'tas', 'pr', 'hurs', 'petH']):
    """ Calculate quantiles based on the supplied EWEMBI data.
    
    Args:
        ewembi_path: Raw str. Path to .dat file of EWEMBI data
        quant_path:  Raw str. Name of CSV to create for quantile data
        quants:      List. Quantiles of interest
        names:       List. Names for columns in ewembi_path .dat file
        
    Returns:
        None. The CSV file is saved.
    """
    # Loop over seasons
    df_list = []
    for season in ['winter', 'spring', 'early_summer', 'late_summer']:
        # Read data
        obs_df = pd.read_csv(ewembi_path, sep='\t', encoding='utf-8', names=names)

        # Parse dates
        obs_df['date'] = pd.to_datetime(obs_df['date'], format='%Y-%m-%d')
        obs_df['month'] = obs_df['date'].dt.month
        obs_df['year'] = obs_df['date'].dt.year
        obs_df['season'] = obs_df.apply(get_season, axis=1)

        # January should always be associated with the previous year
        mask = obs_df['month'] == 1
        obs_df['year'][mask] = obs_df['year'][mask] - 1

        # Wind seems to be reported as vectors with E-W and N-S components
        # estimate total of (u**2 + v**2)**0.5, but CHECK THIS!
        obs_df['wind'] = (obs_df['uas']**2 + obs_df['vas']**2)**0.5

        # Filter to cols and season of interest
        par_list = [i for i in obs_df.columns if i not in ('date', 'time', 'year', 'month', 'season')]
        obs_df = obs_df[['year', 'season'] + par_list]
        obs_df = obs_df.query('season == @season')
        obs_df = obs_df.query('year != 1980') # 1980 not valid (as only have Jan from 1981)

        # Groupby year
        obs_df = obs_df.groupby('year').mean()

        # Calculate quantiles
        quant_df = obs_df.quantile(quants)
        quant_df['quantile'] = quant_df.index
        quant_df['season'] = season

        df_list.append(quant_df)

    # Combine
    quant_df = pd.concat(df_list)
    quant_df.reset_index(inplace=True)
    quant_df = quant_df[['season', 'quantile', 'tas', 'pr', 'wind']]

    # Save
    quant_df.to_csv(quant_path, encoding='utf-8', index=False)
    
def aggregate_seasonal_forecast(season, year, par_list=['tas', 'pr', 'wind'],
                                names=['date', 'time', 'uas', 'vas', 'ps', 'tas', 'pr', 'hurs', 'petH']):
    """ Calculates seasonal averages for the specified variables based on data in
    
            WATExR/Norway_Morsa/Data/Meteorological/05_temporary_forecast_data
            
    Args:
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        par_list: List. Variables of interest
        names:    List. Column names in the S4 .dat files
        
    Returns:
        Dataframe with a single average value for each variable in the specified season.
    
    """   
    # List of output from 15-member ensemble
    months_dict = {'winter':      [11, 12, 1],
                   'spring':      [2, 3, 4],
                   'early_summer':[5, 6, 7],
                   'late_summer': [8, 9, 10],
                  }
    end_month = months_dict[season][-1]

    base_path = r'./data_cache/s4_seasonal/Morsa/CLIMATE'
    search_path = os.path.join(base_path,
                               f'Morsa_NIVA_System4_seasonal_15_seasonal_member*_day_*-{year}{end_month:02d}*',
                                'meteo_file.dat')
    flist = glob.glob(search_path)

    # Loop over ensemble
    df_list = []
    for fpath in sorted(flist):
        # Get member
        member = os.path.split(os.path.split(fpath)[0])[1].split('_')[6][-2:]
        mod_df = pd.read_csv(fpath, sep='\t', encoding='utf-8', names=names)

        # Parse dates
        mod_df['date'] = pd.to_datetime(mod_df['date'], format='%Y-%m-%d')
        mod_df['month'] = mod_df['date'].dt.month
        mod_df['year'] = mod_df['date'].dt.year
        mod_df['season'] = mod_df.apply(get_season, axis=1)

        # January should always be associated with the previous year
        mask = mod_df['month'] == 1
        mod_df['year'][mask] = mod_df['year'][mask] - 1

        # Wind seems to be reported as vectors with E-W and N-S components
        # estimate total of (u**2 + v**2)**0.5, but CHECK THIS!
        mod_df['wind'] = (mod_df['uas']**2 + mod_df['vas']**2)**0.5

        # Filter to cols and season of interest
        mod_df = mod_df[['year', 'season'] + par_list]
        mod_df = mod_df.query('season == @season')
        mod_df = mod_df.query('year != 1980') # 1980 not valid (as only have Jan from 1981)

        # Groupby year
        mod_df = mod_df.groupby('year').mean()

        assert len(mod_df) == 1

        # Tidy 
        mod_df.reset_index(inplace=True, drop=True)
        mod_df['member'] = member

        df_list.append(mod_df)

    # Combine
    mod_df = pd.concat(df_list)
    mod_df = mod_df[['member',] + par_list]
    mod_df.sort_values('member', inplace=True)
    mod_df.set_index('member', inplace=True)

    return mod_df
    
    
def compare_s4_to_ewembi(quant_path, season, mod_df, par_list=['tas', 'pr', 'wind'],
                         normal_quants=[0.33, 0.67], extreme_quants=[0.05, 0.95]):
    """ Compares seasonal averages for each S4 ensemble member to the historic average 
        quantiles in 'quant_path'. For each ensemble member and each variable in 'par_list',
        classifies the predicted seasonal average according to two scales:
        
            ['Below normal', 'Near normal', 'Above normal']
            ['Extreme low', 'Not extreme', 'Extreme high']
            
        The quantile boundaries defining the three classes on each scale are provided by 
        'normal_quants' and 'extreme_quants', respectively.
        
    Args:
        quant_path:     Raw str. Path to CSV of EWEMBI quantiles, as returned by 
                        calculate_ewembi_quantiles() 
        season:         Str. ['winter', 'spring', 'early_summer', 'late_summer'] 
        mod_df:         Dataframe. Summary of S4 model results, as returned by
                        aggregate_seasonal_forecast()
        par_list:       List. Variables of interest
        normal_quants:  List. Two floats specifying bin edges for "normal" scale
        extreme_quants: List. Two floats specifying bin edges for "extreme" scale
        
    Returns:
        Dict. For each variable, contains the most likely class from the "normal" and "extreme"
        scales, together with an indication of forecast confidence (expressed as the percentage 
        of ensemble members in that class).
    """
    assert season in ['winter', 'spring', 'early_summer', 'late_summer'], "'season' must be one of ('winter', 'spring', early_summer', 'late_summer')."
        
    # Read quantiles
    quant_df = pd.read_csv(quant_path)

    # Get season
    quant_df = quant_df.query('season == @season')
    quant_df.index = quant_df['quantile']

    # Labels for terciles and extremes
    terc_labels = ['Below normal', 'Near normal', 'Above normal']
    ext_labels = ['Extreme low', 'Not extreme', 'Extreme high']

    # Loop over variables
    res_dict = {}
    for par in par_list:
        # Build bins for terciles
        terc_bins = quant_df.loc[normal_quants][par].values
        terc_bins = np.insert(terc_bins, 0, -np.inf)
        terc_bins = np.append(terc_bins, np.inf)  

        # Build bins for extremes
        ext_bins = quant_df.loc[extreme_quants][par].values
        ext_bins = np.insert(ext_bins, 0, -np.inf)
        ext_bins = np.append(ext_bins, np.inf)  

        # Get terciles
        terc_df = pd.cut(mod_df[par], 
                         bins=terc_bins,
                         labels=terc_labels)

        terc = terc_df.value_counts().idxmax()
        terc_prob = 100 * terc_df.value_counts().max() / 15

        # Get extremes
        ext_df = pd.cut(mod_df[par], 
                        bins=ext_bins,
                        labels=ext_labels)

        ext = ext_df.value_counts().idxmax()
        ext_prob = 100 * ext_df.value_counts().max() / 15

        # Add to results
        res_dict[par] = {'tercile':terc,
                         'tercile_prob':terc_prob,
                         'extreme':ext,
                         'extreme_prob':ext_prob}

    return res_dict

def get_colour(res_dict, var):
    """ Get grayscale colours based on forecast probabilities.
    
    Args:
        res_dict: Dict. From compare_s4_to_ewembi()
        var:      Str. Variable of interest
        
    Returns:
        List. [tercile_intensity, extreme_intensity]
    """
    terc_prob = res_dict[var]['tercile_prob']
    ext_prob = res_dict[var]['extreme_prob']
    
    # Colours for terciles
    if terc_prob > 75:
        terc_col = (59/255, 120/255, 255/255)
    elif 50 < terc_prob <= 75:
        terc_col = (145/255, 217/255, 250/255)
    elif 35 < terc_prob <= 50:
        terc_col = (217/255, 245/255, 252/255)
    else:
        terc_col = (212/255, 222/255, 222/255)
        
    # Colours for extremes
    if ext_prob > 75:
        ext_col = (59/255, 120/255, 255/255)
    elif 50 < ext_prob <= 75:
        ext_col = (145/255, 217/255, 250/255)
    elif 35 < ext_prob <= 50:
        ext_col = (217/255, 245/255, 252/255)
    else:
        ext_col = (212/255, 222/255, 222/255)
        
    return [terc_col, ext_col]

def get_performance(season, variable, perf_df, res_dict):
    """
    Args:
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        variable: Str. Variable of interest
        perf_df:  Dataframe. Summary of long-term model performance
        res_dict: Dict. From compare_s4_to_ewembi()
        
    Returns:
        Float. Historic performance ROCSS score from VisualizeR
    """
    terc = res_dict[variable]['tercile']
    
    # FIX THIS!
    if variable == 'wind':
        variable = 'uas'
        
    perf = perf_df.query("(season == @season) and (tercile == @terc)")[variable].values[0]
    
    return perf

def make_climate_forecast_png(season, res_dict, perf_df, out_png):
    """ Make a PNG summarising the S4 climate forecast based on the agreed
        template.
        
    Args:
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        res_dict: Dict. From compare_s4_to_ewembi()
        perf_df:  Dataframe. Summary of long-term model performance
        out_png:  Raw str. Path for PNG to be created
        
    Returns:
        None. Figure is saved.   
    """
    # Setup figure
    fig, ax = plt.subplots(1, figsize=(7.05, 3.03))

    # Dimensions from Leah's Word doc
    ax.set_xlim((0, 7.05))
    ax.set_ylim((0, 3.03))
    ax.axis('off')

    # Create rectangle patches
    rect1  = patches.Rectangle((0.00, 0.20), 5.40, 0.56, linewidth=1, edgecolor='k', facecolor='none')

    rect2  = patches.Rectangle((0.00, 1.23), 1.02, 1.06, linewidth=1, edgecolor='k', facecolor='none')
    rect3  = patches.Rectangle((1.02, 1.23), 2.20, 1.06, linewidth=1, edgecolor='k', facecolor='none')
    rect4  = patches.Rectangle((3.22, 1.23), 1.75, 1.06, linewidth=1, edgecolor='k', facecolor='none')
    rect5  = patches.Rectangle((4.97, 1.23), 2.04, 1.06, linewidth=1, edgecolor='k', facecolor='none')

    rect6  = patches.Rectangle((0.00, 2.29), 1.02, 0.74, linewidth=1, edgecolor='k', facecolor='none')
    rect7  = patches.Rectangle((1.02, 2.29), 2.20, 0.74, linewidth=1, edgecolor='k', facecolor='none')
    rect8  = patches.Rectangle((3.22, 2.29), 1.75, 0.74, linewidth=1, edgecolor='k', facecolor='none')
    rect9  = patches.Rectangle((4.97, 2.29), 2.04, 0.74, linewidth=1, edgecolor='k', facecolor='none')

    rect10 = patches.Rectangle((1.15, 1.28), 0.40, 0.28, linewidth=0.5, edgecolor='k', facecolor=get_colour(res_dict, 'wind')[0])
    rect11 = patches.Rectangle((1.15, 1.61), 0.40, 0.28, linewidth=0.5, edgecolor='k', facecolor=get_colour(res_dict, 'pr')[0])
    rect12 = patches.Rectangle((1.15, 1.94), 0.40, 0.28, linewidth=0.5, edgecolor='k', facecolor=get_colour(res_dict, 'tas')[0])

    rect13 = patches.Rectangle((3.35, 1.28), 0.40, 0.28, linewidth=0.5, edgecolor='k', facecolor=get_colour(res_dict, 'wind')[1])
    rect14 = patches.Rectangle((3.35, 1.61), 0.40, 0.28, linewidth=0.5, edgecolor='k', facecolor=get_colour(res_dict, 'pr')[1])
    rect15 = patches.Rectangle((3.35, 1.94), 0.40, 0.28, linewidth=0.5, edgecolor='k', facecolor=get_colour(res_dict, 'tas')[1])

    rect17 = patches.Rectangle((0.10, 0.51), 0.22, 0.22, linewidth=0.5, edgecolor='k', facecolor=(59/255, 120/255, 255/255))
    rect16 = patches.Rectangle((0.10, 0.24), 0.22, 0.22, linewidth=0.5, edgecolor='k', facecolor=(145/255, 217/255, 250/255))
    rect19 = patches.Rectangle((2.79, 0.51), 0.22, 0.22, linewidth=0.5, edgecolor='k', facecolor=(217/255, 245/255, 252/255))
    rect18 = patches.Rectangle((2.79, 0.24), 0.22, 0.22, linewidth=0.5, edgecolor='k', facecolor=(212/255, 222/255, 222/255))

    # Add the patches to the axes
    rect_list = [rect1, rect2, rect3, rect4, rect5, rect6, rect7, rect8, rect9,
                 rect10, rect11, rect12, rect13, rect14, rect15, rect16, rect17,
                 rect18, rect19]

    for rect in rect_list:
        ax.add_patch(rect)

    # Column headings
    text = ("Prediction for the coming"
             "\nseason (compared to the"
             "\n1981 - 2010 average)")
    ax.text(2.12, 2.45, text, fontsize=10, weight='bold', ha='center')

    text = ("Risk of extremes")
    ax.text(4.10, 2.62, text, fontsize=10, weight='bold', ha='center')

    text = ("Forecast reliability"
            "\n(historic performance)")
    ax.text(5.99, 2.55, text, fontsize=10, weight='bold', ha='center')

    # Row labels
    text = ("Temperature")
    ax.text(0.05, 2.03, text, fontsize=8, weight='bold')

    text = ("Precipitation")
    ax.text(0.05, 1.69, text, fontsize=8, weight='bold')

    text = ("Wind")
    ax.text(0.05, 1.35, text, fontsize=8, weight='bold')

    # Legend text
    text = ("High (> 75% agreement)")
    ax.text(0.40, 0.56, text, fontsize=8)

    text = ("Medium (50 - 75% agreement)")
    ax.text(0.40, 0.28, text, fontsize=8)

    text = ("Low (35 - 50% agreement)")
    ax.text(3.10, 0.56, text, fontsize=8)

    text = ("Less than low (< 35% agreement)")
    ax.text(3.10, 0.28, text, fontsize=8)

    text = ("Colour intensity represents " + r"$\bf{forecast \ probability*}$")
    ax.text(0.05, 0.90, text, fontsize=8)

    text = ("*percentage of seasonal forecast ensemble members within each class")
    ax.text(0.05, 0.02, text, fontsize=8)

    # Forecast class labels
    # Terciles
    text = (res_dict['tas']['tercile'])
    ax.text(1.65, 2.03, text, fontsize=8, weight='bold')

    text = (res_dict['pr']['tercile'])
    ax.text(1.65, 1.69, text, fontsize=8, weight='bold')

    text = (res_dict['wind']['tercile'])
    ax.text(1.65, 1.35, text, fontsize=8, weight='bold')

    # Extremes
    text = (res_dict['tas']['extreme'])
    ax.text(3.82, 2.03, text, fontsize=8, weight='bold')

    text = (res_dict['pr']['extreme'])
    ax.text(3.82, 1.69, text, fontsize=8, weight='bold')

    text = (res_dict['wind']['extreme'])
    ax.text(3.82, 1.35, text, fontsize=8, weight='bold')

    # Reliability
    text = (str(get_performance(season, 'tas', perf_df, res_dict)))
    ax.text(5.99, 2.03, text, fontsize=8, weight='bold', ha='center')

    text = (str(get_performance(season, 'pr', perf_df, res_dict)))
    ax.text(5.99, 1.69, text, fontsize=8, weight='bold', ha='center')

    text = (str(get_performance(season, 'wind', perf_df, res_dict)))
    ax.text(5.99, 1.35, text, fontsize=8, weight='bold', ha='center')
    
    plt.tight_layout()
    plt.savefig(out_png, dpi=300)

def hyperlink(url, text):
    """ Insert Latex hyperlink.
    """
    text = escape_latex(text)
    return NoEscape(r'\href{' + url + '}{' + text + '}')

def get_months(season):
    """ Get the start and end months for the specified season.
    """
    if season == 'winter':
        return ['November', 'January']
    elif season == 'spring':
        return ['February', 'April']
    elif season == 'early_summer':
        return ['May', 'July']
    elif season == 'late_summer':
        return ['August', 'October']

def make_forecast_pdf(year, season):
    """ Create a PDF summarising the forecast, based on the agreed template.
    
    Args:
        year:         Int. The forecast year of interest
        season:       Str. ['winter', 'spring', 'early_summer', 'late_summer']
        
    Returns:
        None. The PDF is saved.
    """
    
    # Table of "seasons" added as an image
    table_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'forecast_output', 'forecast_table.png')
    seas_table = r"""
    \begin{wrapfigure}{L}{0.5\textwidth}
    \centering
    \vspace{-15pt}
    \includegraphics[width=0.5\textwidth]{%s}
    \vspace{-10pt}
    \end{wrapfigure}
    """ % table_path
    
    # Create document structure
    geometry_options = {"tmargin": "1.5cm", "lmargin": "2cm", "bmargin": "2cm"}
    doc = Document(geometry_options=geometry_options)

    # Load packages
    doc.packages.append(Package('hyperref'))
    doc.packages.append(Package('wrapfig'))
    doc.packages.append(Package('graphicx'))
    #doc.packages.append(Package('Arev'))

    # Add title
    with doc.create(MiniPage(align='c')):
        doc.append(LargeText(bold("WATExR: Seasonal forecast of weather and lake water quality")))

    # Introduction
    if season == 'winter':
        end_year = year + 1
    else:
        end_year = year
    
    months = get_months(season)
    date = dt.datetime.today()
    date = date.strftime("%B %d. %Y")
    doc.append(MediumText(bold(f"\n\n\nForecast for Lake Vansjø: {months[0]} {year} – {months[1]} {end_year}")))
    doc.append(MediumText(bold(f"\nForecast issued {date}")))

    doc.append('\n\nThis page shows temperature, rainfall and wind conditions expected '
               'for south-eastern Norway during the next 3 months. For summer (May-Oct), '
               'lake water quality forecasts for the western basin of Lake Vansjø are also '
               'produced, where the aim is to predict ecological status according to the '
               'Water Framework Directive.')

    doc.append('\n\nWeather forecasts are issued four times a year, as follows:\n')

    doc.append(NoEscape(seas_table))

    doc.append('Forecasts are generated using an ensemble of bias-corrected '
               'seasonal climate forecasts (15 members) provided by the ECMWF System 4. '
               'Lake ecological status forecasts are based on statistical modelling '
               '(click ')
    doc.append(hyperlink("https://github.com/icra/WATExR", "here "))
    doc.append('for further information).\n\n')

    doc.append(NoEscape(r'\rule{\textwidth}{1.5pt}'))

    # Climate forecast summary
    doc.append(MediumText(bold(f'\n\nWeather forecast for {months[0]} {year} – {months[1]} {end_year}')))
    clim_forecast_png = os.path.join(os.path.dirname(os.path.realpath(__file__)), 
                                     'forecast_output', 
                                     'climate_forecast_summary.png')
    with doc.create(Figure(position='h!')) as fc_summary:
        fc_summary.add_image(clim_forecast_png, width='5.5in')

    doc.append(NoEscape(r'\noindent\rule{\textwidth}{1.5pt}'))

    # Water quality forecast summary
    doc.append(MediumText(bold('\n\nLake water quality forecast for May 2001 – July 2001')))  
    qual_forecast_png = os.path.join(os.path.dirname(os.path.realpath(__file__)), 
                                     'forecast_output', 
                                     'quality_forecast_summary.png')
    with doc.create(Figure(position='h!')) as fc_quality:
        fc_quality.add_image(qual_forecast_png, width='5.5in')        

    # Save as PDF
    forecast_pdf = os.path.join(os.path.dirname(os.path.realpath(__file__)), 
                                'forecast_output', 
                                f'morsa_forecast_{season}_{year}')
    doc.generate_pdf(forecast_pdf, clean_tex=True)
    
    print('Forecast saved to:')
    print('    ' + forecast_pdf + '.pdf')
    
def make_forecast(download, year, season):
    """ Wraps the functions above to create all forecast components.
    
    Args:
        download: Bool. Whether to update or relace S4 data
        year:     Int. Year of interest
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        
    Returns:
        None. Components are saved to PDF.
    """

    print('Getting forecast...')
            
    if download:
        # Download and bias correct S4 data
        print('  Downloading and bias-correcting seasonal forecast data...')        
        res = get_seasonal_forecast(year, season)
        
        if res != 0:
            print('  Failed :-(')
            raise ValueError()
            
    # Check data exists for season and year
    months_dict = {'winter':      [11, 12, 1],
                   'spring':      [2, 3, 4],
                   'early_summer':[5, 6, 7],
                   'late_summer': [8, 9, 10],
                  }
    end_month = months_dict[season][-1]

    base_path = r'./data_cache/s4_seasonal/Morsa/CLIMATE'
    search_path = os.path.join(base_path,
                               f'Morsa_NIVA_System4_seasonal_15_seasonal_member*_day_*-{year}{end_month:02d}*',
                                'meteo_file.dat')
    flist = glob.glob(search_path)
    
    if len(flist) != 15:
        message = ('ERROR: Cannot find cached forecast data for the selected season and year.\n'
                   '       Consider trying again with the "Update/replace" option checked.')
        print(message)        
        raise ValueError(message)
        
    # Delete existing climate_forecast_summary.png to avoid confusion later
    clim_forecast_png = r'./forecast_output/climate_forecast_summary.png'
    if os.path.isfile(clim_forecast_png):
        os.remove(clim_forecast_png)
        
    # Summarise EWEMBI data
    ewembi_path = r'./data_cache/ewembi_obs/ewembi_obs_1981-2010.dat'
    quant_path = r'./data_cache/ewembi_obs/ewembi_obs_quantiles_1981-2010.csv'
    calculate_ewembi_quantiles(ewembi_path, 
                                  quant_path, 
                                  quants=[0.05, 0.33, 0.67, 0.95],
                                  names=['date', 'time', 'uas', 'vas', 'ps', 'tas', 'pr', 'hurs', 'petH'],
                                 )

    # Average seasonal data
    s4_df = aggregate_seasonal_forecast(season, 
                                           year,
                                           par_list=['tas', 'pr', 'wind'],
                                           names=['date', 'time', 'uas', 'vas', 'ps', 'tas', 'pr', 'hurs', 'petH'],
                                          )

    # Classify forecast
    res_dict = compare_s4_to_ewembi(quant_path, 
                                       season, 
                                       s4_df, 
                                       par_list=['tas', 'pr', 'wind'],
                                       normal_quants=[0.33, 0.67], 
                                       extreme_quants=[0.05, 0.95],
                                      )

    # Read table of historic performance
    xl_path = r'./data_cache/seasonal_forecast_performance_1981-2010.xlsx'
    perf_df = pd.read_excel(xl_path)

    # Make summary image
    make_climate_forecast_png(season, res_dict, perf_df, clim_forecast_png)
    
    print('Done.')
    
    # Export PDF
    make_forecast_pdf(year, season)