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
    """ Downloads and bias-corrects (without CV) the 25-member S5 seasonal forecast 
        for the specified year and season. Uses seasons as defined for the Bayesian 
        network:
        
            winter:       11, 12,  1
            spring:        2,  3,  4
            early_summer:  5,  6,  7
            late_summer:   8,  9, 10
            
        This function takes a while to run and calls a R script in a separate process.
        Progress reporting and error handling is currently non-existent and should be
        improved.
        
    Args:
        year:   Int. Year of interest
        season: Str. One of the seasons, as defined above
        
    Returns:
        Int. Subprocess return code. Should be 0 if R script is successful.
    """
    # C4R assumes "winter 2007" => Nov & Dec 2006 and Jan 2007
    # For WateXr, we assume "winter 2007" => Nov & Dec 2007 and Jan 2008
    # Adjust year accordingly
    if season == "winter":
        year = year + 1

    # Validate input and get months
    months_dict = {
        "winter": "11,12,1",
        "spring": "2,3,4",
        "early_summer": "5,6,7",
        "late_summer": "8,9,10",
    }

    res = subprocess.check_call(
        [
            "Rscript",
            "--vanilla",
            "forecast_app_r_code_s5.R",
            str(year),
            season,
            months_dict[season],
        ],
        cwd=os.path.dirname(os.path.realpath(__file__)),
    )

    return res


def get_season(row):
    """ Classifies seasons in dataframe based on months.
    """
    if row["date"].month in (11, 12, 1):
        return "winter"
    elif row["date"].month in (2, 3, 4):
        return "spring"
    elif row["date"].month in (5, 6, 7):
        return "early_summer"
    elif row["date"].month in (8, 9, 10):
        return "late_summer"
    else:
        return np.nan


def calculate_s5_quantiles(
    s5_fold, quant_path, quants=[0.05, 0.33, 0.67, 0.95],
):
    """ Calculate quantiles based on the supplied S5 data. Assumes all members are
        sampling from the same underlying distribution i.e. pools data from all
        members and calculates a single set of quantiles.
    
    Args:
        s5_fold:    Raw str. Path to folder containing bias-corrected S5 CSVs.
                    Assumes files are named in the format produced by
                    07_download_s5.ipynb, for example:
                        s5_morsa_bayes_net_merged_late_summer_member12_bc.csv 
        quant_path: Raw str. Name of CSV to create for quantile data
        quants:     List. Quantiles of interest
        
    Returns:
        None. The CSV file is saved.
    """
    df_list = []
    for season in ["winter", "spring", "early_summer", "late_summer"]:
        mem_list = []
        for member in range(1, 26):
            # Read data
            fname = f"s5_morsa_bayes_net_merged_{season}_member{member:02d}_bc.csv"
            fpath = os.path.join(s5_fold, fname)
            df = pd.read_csv(fpath)

            df["member"] = member
            mem_list.append(df)

        # Combine members for season
        df = pd.concat(mem_list)

        # Parse dates
        df["date"] = pd.to_datetime(df["dates"], format="%Y-%m-%d")
        del df["dates"]
        df["month"] = df["date"].dt.month
        df["year"] = df["date"].dt.year
        df["season"] = df.apply(get_season, axis=1)

        # January should always be associated with the previous year
        mask = df["month"] == 1
        df.loc[mask, "year"] = df["year"][mask] - 1

        # Wind reported as vectors with E-W and N-S components
        # estimate total as (u**2 + v**2)**0.5
        df["wind"] = (df["uas"] ** 2 + df["vas"] ** 2) ** 0.5

        # Filter to cols and season of interest
        par_list = [
            i
            for i in df.columns
            if i not in ("member", "date", "year", "month", "season")
        ]
        df = df[["member", "year", "season"] + par_list]
        df = df.query("season == @season")
        df = df.query("year != 1992")  # 1992 not valid (as only have Jan from 1993)

        # Groupby year
        agg_dict = {}
        for par in par_list:
            if par == "tp":
                agg_dict[par] = "sum"
            else:
                agg_dict[par] = "mean"

        df = df.groupby(["member", "year"]).agg(agg_dict)

        # Calculate quantiles
        quant_df = df.quantile(quants)
        quant_df["quantile"] = quant_df.index
        quant_df["season"] = season

        df_list.append(quant_df)

    # Combine
    quant_df = pd.concat(df_list)
    quant_df.reset_index(inplace=True)
    quant_df = quant_df[["season", "quantile", "tas", "tp", "wind"]]

    # Save
    quant_df.to_csv(quant_path, encoding="utf-8", index=False)


def aggregate_s5_forecast(
    season, year, par_list=["tas", "tp", "wind"],
):
    """ Calculates seasonal averages for each S5 member for the specified variables.

    Args:
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        par_list: List. Variables of interest
        
    Returns:
        Dataframe with a single average value for each member and variable in the 
        specified season.
    
    """
    base_path = r"./data_cache/s5_seasonal"
    df_list = []
    for member in range(1, 26):
        # Read data
        fname = f"s5_morsa_{year}_{season}_member{member:02d}_bc.csv"
        fpath = os.path.join(base_path, fname)
        df = pd.read_csv(fpath)

        # Wind reported as vectors with E-W and N-S components
        # estimate total as (u**2 + v**2)**0.5
        df["wind"] = (df["uas"] ** 2 + df["vas"] ** 2) ** 0.5

        # Date range in CSV should already be correct based on filename
        # so can average directly
        agg_dict = {}
        for par in par_list:
            if par == "tp":
                agg_dict[par] = "sum"
            else:
                agg_dict[par] = "mean"
        df = df.agg(agg_dict)[par_list].to_frame().T

        assert len(df) == 1

        # Add member
        df["member"] = member

        df_list.append(df)

    # Combine
    df = pd.concat(df_list)
    df = df[["member",] + par_list]
    df.sort_values("member", inplace=True)
    df.set_index("member", inplace=True)

    return df


def assign_quantiles(
    quant_path,
    season,
    mod_df,
    par_list=["tas", "tp", "wind"],
    normal_quants=[0.33, 0.67],
    extreme_quants=[0.05, 0.95],
):
    """ Compares seasonal averages for each S5 ensemble member to the historic 
        quantiles in 'quant_path'. For each ensemble member and each variable 
        in 'par_list', classifies the predicted seasonal average according to 
        two scales:
        
            ['Below normal', 'Near normal', 'Above normal']
            ['Extreme low', 'Not extreme', 'Extreme high']
            
        The quantile boundaries defining the three classes on each scale are provided by 
        'normal_quants' and 'extreme_quants', respectively.
        
    Args:
        quant_path:     Raw str. Path to CSV of historic S5 quantiles, as returned by 
                        calculate_s5_quantiles() 
        season:         Str. ['winter', 'spring', 'early_summer', 'late_summer'] 
        mod_df:         Dataframe. Summary of S5 model results, as returned by
                        aggregate_s5_forecast()
        par_list:       List. Variables of interest
        normal_quants:  List. Two floats specifying bin edges for "normal" scale
        extreme_quants: List. Two floats specifying bin edges for "extreme" scale
        
    Returns:
        Dict. For each variable, contains the most likely class from the "normal" and "extreme"
        scales, together with an indication of forecast confidence (expressed as the percentage 
        of ensemble members in that class).
    """
    assert season in [
        "winter",
        "spring",
        "early_summer",
        "late_summer",
    ], "'season' must be one of ('winter', 'spring', early_summer', 'late_summer')."

    # Read quantiles
    quant_df = pd.read_csv(quant_path)

    # Get season
    quant_df = quant_df.query("season == @season")
    quant_df.index = quant_df["quantile"]

    # Labels for terciles and extremes
    terc_labels = ["Below normal", "Near normal", "Above normal"]
    ext_labels = ["Extreme low", "Not extreme", "Extreme high"]

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
        terc_df = pd.cut(mod_df[par], bins=terc_bins, labels=terc_labels)
        print(par)
        print(100 * terc_df.value_counts() / 25)
        terc = terc_df.value_counts().idxmax()
        terc_prob = 100 * terc_df.value_counts().max() / 25

        # Get extremes
        ext_df = pd.cut(mod_df[par], bins=ext_bins, labels=ext_labels)

        ext = ext_df.value_counts().idxmax()
        ext_prob = 100 * ext_df.value_counts().max() / 25

        # Add to results
        res_dict[par] = {
            "tercile": terc,
            "tercile_prob": terc_prob,
            "extreme": ext,
            "extreme_prob": ext_prob,
        }

    return res_dict


def get_colour(res_dict, var):
    """ Get grayscale colours based on forecast probabilities.
    
    Args:
        res_dict: Dict. From assign_quantiles()
        var:      Str. Variable of interest
        
    Returns:
        List. [tercile_intensity, extreme_intensity]
    """
    terc_prob = res_dict[var]["tercile_prob"]
    ext_prob = res_dict[var]["extreme_prob"]

    # Colours for terciles
    if terc_prob > 75:
        terc_col = (59 / 255, 120 / 255, 255 / 255)
    elif 50 < terc_prob <= 75:
        terc_col = (145 / 255, 217 / 255, 250 / 255)
    elif 35 < terc_prob <= 50:
        terc_col = (217 / 255, 245 / 255, 252 / 255)
    else:
        terc_col = (212 / 255, 222 / 255, 222 / 255)

    # Colours for extremes
    if ext_prob > 75:
        ext_col = (59 / 255, 120 / 255, 255 / 255)
    elif 50 < ext_prob <= 75:
        ext_col = (145 / 255, 217 / 255, 250 / 255)
    elif 35 < ext_prob <= 50:
        ext_col = (217 / 255, 245 / 255, 252 / 255)
    else:
        ext_col = (212 / 255, 222 / 255, 222 / 255)

    return [terc_col, ext_col]


def aggregate_performance_metrics(
    terc_fold, perf_csv, par_list=["tas", "tp", "uas", "vas"]
):
    """ Aggregates the S5 performance statistics generated by 
        09_era5_s5_tercile_plots.ipynb into a single dataset.

    Args:
        terc_fold: Str. Path to folder containing summary statistics
        perf_csv:  Str. CSV to be created.
        par_list:  List. Parameters of interest

    Returns:
        None. CSV is saved to the specified path.
    """
    df_list = []
    for season in ["winter", "spring", "early_summer", "late_summer"]:
        fname = f"morsa_bayes_net_{season}_rocss.csv"
        fpath = os.path.join(terc_fold, fname)
        df = pd.read_csv(fpath)

        # Get parameters of interest
        df = df.query("par in @par_list")

        # Add season
        df["season"] = season

        df_list.append(df)

    # Combine
    df = pd.concat(df_list)

    # Use full names for terciles
    df["terc"].replace(
        {"lower": "Below normal", "middle": "Near normal", "upper": "Above normal"},
        inplace=True,
    )

    df["roc"] = df["roc"].round(2)

    # Re-order columns
    df = df[["season", "par", "terc", "roc", "sig"]]

    df.to_csv(perf_csv, index=False)


def get_performance(season, variable, perf_df, res_dict):
    """
    Args:
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        variable: Str. Variable of interest
        perf_df:  Dataframe. Summary of long-term model performance
        res_dict: Dict. From assign_quantiles()
        
    Returns:
        Float. Historic performance ROCSS score from VisualizeR
    """
    terc = res_dict[variable]["tercile"]

    # Use 'uas' to indicate performance for 'wind'. Could be improved by combining
    # scores for 'uas' and 'vas', but this isn't straightforward
    if variable == "wind":
        variable = "uas"

    perf = perf_df.query(
        "(season == @season) and (par == @variable) and (terc == @terc)"
    )["roc"].values[0]

    return perf


def make_climate_forecast_png(season, res_dict, perf_df, out_png):
    """ Make a PNG summarising the S5 climate forecast based on the agreed
        template.
        
    Args:
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        res_dict: Dict. From assign_quantiles()
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
    ax.axis("off")

    # Create rectangle patches
    rect1 = patches.Rectangle(
        (0.00, 0.20), 5.40, 0.56, linewidth=1, edgecolor="k", facecolor="none"
    )

    rect2 = patches.Rectangle(
        (0.00, 1.23), 1.02, 1.06, linewidth=1, edgecolor="k", facecolor="none"
    )
    rect3 = patches.Rectangle(
        (1.02, 1.23), 2.20, 1.06, linewidth=1, edgecolor="k", facecolor="none"
    )
    rect4 = patches.Rectangle(
        (3.22, 1.23), 1.75, 1.06, linewidth=1, edgecolor="k", facecolor="none"
    )
    rect5 = patches.Rectangle(
        (4.97, 1.23), 2.04, 1.06, linewidth=1, edgecolor="k", facecolor="none"
    )

    rect6 = patches.Rectangle(
        (0.00, 2.29), 1.02, 0.74, linewidth=1, edgecolor="k", facecolor="none"
    )
    rect7 = patches.Rectangle(
        (1.02, 2.29), 2.20, 0.74, linewidth=1, edgecolor="k", facecolor="none"
    )
    rect8 = patches.Rectangle(
        (3.22, 2.29), 1.75, 0.74, linewidth=1, edgecolor="k", facecolor="none"
    )
    rect9 = patches.Rectangle(
        (4.97, 2.29), 2.04, 0.74, linewidth=1, edgecolor="k", facecolor="none"
    )

    rect10 = patches.Rectangle(
        (1.15, 1.28),
        0.40,
        0.28,
        linewidth=0.5,
        edgecolor="k",
        facecolor=get_colour(res_dict, "wind")[0],
    )
    rect11 = patches.Rectangle(
        (1.15, 1.61),
        0.40,
        0.28,
        linewidth=0.5,
        edgecolor="k",
        facecolor=get_colour(res_dict, "tp")[0],
    )
    rect12 = patches.Rectangle(
        (1.15, 1.94),
        0.40,
        0.28,
        linewidth=0.5,
        edgecolor="k",
        facecolor=get_colour(res_dict, "tas")[0],
    )

    rect13 = patches.Rectangle(
        (3.35, 1.28),
        0.40,
        0.28,
        linewidth=0.5,
        edgecolor="k",
        facecolor=get_colour(res_dict, "wind")[1],
    )
    rect14 = patches.Rectangle(
        (3.35, 1.61),
        0.40,
        0.28,
        linewidth=0.5,
        edgecolor="k",
        facecolor=get_colour(res_dict, "tp")[1],
    )
    rect15 = patches.Rectangle(
        (3.35, 1.94),
        0.40,
        0.28,
        linewidth=0.5,
        edgecolor="k",
        facecolor=get_colour(res_dict, "tas")[1],
    )

    rect17 = patches.Rectangle(
        (0.10, 0.51),
        0.22,
        0.22,
        linewidth=0.5,
        edgecolor="k",
        facecolor=(59 / 255, 120 / 255, 255 / 255),
    )
    rect16 = patches.Rectangle(
        (0.10, 0.24),
        0.22,
        0.22,
        linewidth=0.5,
        edgecolor="k",
        facecolor=(145 / 255, 217 / 255, 250 / 255),
    )
    rect19 = patches.Rectangle(
        (2.79, 0.51),
        0.22,
        0.22,
        linewidth=0.5,
        edgecolor="k",
        facecolor=(217 / 255, 245 / 255, 252 / 255),
    )
    rect18 = patches.Rectangle(
        (2.79, 0.24),
        0.22,
        0.22,
        linewidth=0.5,
        edgecolor="k",
        facecolor=(212 / 255, 222 / 255, 222 / 255),
    )

    # Add the patches to the axes
    rect_list = [
        rect1,
        rect2,
        rect3,
        rect4,
        rect5,
        rect6,
        rect7,
        rect8,
        rect9,
        rect10,
        rect11,
        rect12,
        rect13,
        rect14,
        rect15,
        rect16,
        rect17,
        rect18,
        rect19,
    ]

    for rect in rect_list:
        ax.add_patch(rect)

    # Column headings
    text = (
        "Prediction for the coming" "\nseason (compared to the" "\n1981 - 2010 average)"
    )
    ax.text(2.12, 2.45, text, fontsize=10, weight="bold", ha="center")

    text = "Risk of extremes"
    ax.text(4.10, 2.62, text, fontsize=10, weight="bold", ha="center")

    text = "Forecast reliability" "\n(historic performance)"
    ax.text(5.99, 2.55, text, fontsize=10, weight="bold", ha="center")

    # Row labels
    text = "Temperature"
    ax.text(0.05, 2.03, text, fontsize=8, weight="bold")

    text = "Precipitation"
    ax.text(0.05, 1.69, text, fontsize=8, weight="bold")

    text = "Wind"
    ax.text(0.05, 1.35, text, fontsize=8, weight="bold")

    # Legend text
    text = "High (> 75% agreement)"
    ax.text(0.40, 0.56, text, fontsize=8)

    text = "Medium (50 - 75% agreement)"
    ax.text(0.40, 0.28, text, fontsize=8)

    text = "Low (35 - 50% agreement)"
    ax.text(3.10, 0.56, text, fontsize=8)

    text = "Less than low (< 35% agreement)"
    ax.text(3.10, 0.28, text, fontsize=8)

    text = "Colour intensity represents " + r"$\bf{forecast \ probability*}$"
    ax.text(0.05, 0.90, text, fontsize=8)

    text = "*percentage of seasonal forecast ensemble members within each class"
    ax.text(0.05, 0.02, text, fontsize=8)

    # Forecast class labels
    # Terciles
    text = res_dict["tas"]["tercile"]
    ax.text(1.65, 2.03, text, fontsize=8, weight="bold")

    text = res_dict["tp"]["tercile"]
    ax.text(1.65, 1.69, text, fontsize=8, weight="bold")

    text = res_dict["wind"]["tercile"]
    ax.text(1.65, 1.35, text, fontsize=8, weight="bold")

    # Extremes
    text = res_dict["tas"]["extreme"]
    ax.text(3.82, 2.03, text, fontsize=8, weight="bold")

    text = res_dict["tp"]["extreme"]
    ax.text(3.82, 1.69, text, fontsize=8, weight="bold")

    text = res_dict["wind"]["extreme"]
    ax.text(3.82, 1.35, text, fontsize=8, weight="bold")

    # Reliability
    text = str(get_performance(season, "tas", perf_df, res_dict))
    ax.text(5.99, 2.03, text, fontsize=8, weight="bold", ha="center")

    text = str(get_performance(season, "tp", perf_df, res_dict))
    ax.text(5.99, 1.69, text, fontsize=8, weight="bold", ha="center")

    text = str(get_performance(season, "wind", perf_df, res_dict))
    ax.text(5.99, 1.35, text, fontsize=8, weight="bold", ha="center")

    plt.tight_layout()
    plt.savefig(out_png, dpi=300)


def hyperlink(url, text):
    """ Insert Latex hyperlink.
    """
    text = escape_latex(text)
    return NoEscape(r"\href{" + url + "}{" + text + "}")


def get_months(season):
    """ Get the start and end months for the specified season.
    """
    if season == "winter":
        return ["November", "January"]
    elif season == "spring":
        return ["February", "April"]
    elif season == "early_summer":
        return ["May", "July"]
    elif season == "late_summer":
        return ["August", "October"]


def make_forecast_pdf(year, season):
    """ Create a PDF summarising the forecast, based on the agreed template.
    
    Args:
        year:         Int. The forecast year of interest
        season:       Str. ['winter', 'spring', 'early_summer', 'late_summer']
        
    Returns:
        None. The PDF is saved.
    """

    # Table of "seasons" added as an image
    table_path = os.path.join(
        os.path.dirname(os.path.realpath(__file__)),
        "forecast_output",
        "forecast_table.png",
    )
    seas_table = (
        r"""
    \begin{wrapfigure}{L}{0.5\textwidth}
    \centering
    \vspace{-15pt}
    \includegraphics[width=0.5\textwidth]{%s}
    \vspace{-10pt}
    \end{wrapfigure}
    """
        % table_path
    )

    # Create document structure
    geometry_options = {"tmargin": "1.5cm", "lmargin": "2cm", "bmargin": "2cm"}
    doc = Document(geometry_options=geometry_options)

    # Load packages
    doc.packages.append(Package("hyperref"))
    doc.packages.append(Package("wrapfig"))
    doc.packages.append(Package("graphicx"))
    # doc.packages.append(Package('Arev'))

    # Add title
    with doc.create(MiniPage(align="c")):
        doc.append(
            LargeText(
                bold("WATExR: Seasonal forecast of weather and lake water quality")
            )
        )

    # Introduction
    if season == "winter":
        end_year = year + 1
    else:
        end_year = year

    months = get_months(season)
    date = dt.datetime.today()
    date = date.strftime("%B %d. %Y")
    doc.append(
        MediumText(
            bold(
                f"\n\n\nForecast for Lake Vansjø: {months[0]} {year} – {months[1]} {end_year}"
            )
        )
    )
    doc.append(MediumText(bold(f"\nForecast issued {date}")))

    doc.append(
        "\n\nThis page shows temperature, rainfall and wind conditions expected "
        "for south-eastern Norway during the next 3 months. For summer (May-Oct), "
        "lake water quality forecasts for the western basin of Lake Vansjø are also "
        "produced, where the aim is to predict ecological status according to the "
        "Water Framework Directive."
    )

    doc.append("\n\nWeather forecasts are issued four times a year, as follows:\n")

    doc.append(NoEscape(seas_table))

    doc.append(
        "Forecasts are generated using an ensemble of bias-corrected "
        "seasonal climate forecasts (15 members) provided by the ECMWF System 4. "
        "Lake ecological status forecasts are based on statistical modelling "
        "(click "
    )
    doc.append(hyperlink("https://github.com/icra/WATExR", "here "))
    doc.append("for further information).\n\n")

    doc.append(NoEscape(r"\rule{\textwidth}{1.5pt}"))

    # Climate forecast summary
    doc.append(
        MediumText(
            bold(
                f"\n\nWeather forecast for {months[0]} {year} – {months[1]} {end_year}"
            )
        )
    )
    clim_forecast_png = os.path.join(
        os.path.dirname(os.path.realpath(__file__)),
        "forecast_output",
        "climate_forecast_summary.png",
    )
    with doc.create(Figure(position="h!")) as fc_summary:
        fc_summary.add_image(clim_forecast_png, width="5.5in")

    doc.append(NoEscape(r"\noindent\rule{\textwidth}{1.5pt}"))

    # Water quality forecast summary
    doc.append(
        MediumText(bold("\n\nLake water quality forecast for May 2001 – July 2001"))
    )
    qual_forecast_png = os.path.join(
        os.path.dirname(os.path.realpath(__file__)),
        "forecast_output",
        "quality_forecast_summary.png",
    )
    with doc.create(Figure(position="h!")) as fc_quality:
        fc_quality.add_image(qual_forecast_png, width="5.5in")

    # Save as PDF
    forecast_pdf = os.path.join(
        os.path.dirname(os.path.realpath(__file__)),
        "forecast_output",
        f"morsa_forecast_{season}_{year}",
    )
    doc.generate_pdf(forecast_pdf, clean_tex=True)

    print("Forecast saved to:")
    print("    " + forecast_pdf + ".pdf")


def make_forecast(download, year, season):
    """ Wraps the functions above to create all forecast components.
    
    Args:
        download: Bool. Whether to update or relace S5 data
        year:     Int. Year of interest
        season:   Str. ['winter', 'spring', 'early_summer', 'late_summer']
        
    Returns:
        None. Components are saved to PDF.
    """

    print("Getting forecast...")

    if download:
        # Download and bias correct S4 data
        print("  Downloading and bias-correcting seasonal forecast data...")
        res = get_seasonal_forecast(year, season)

        if res != 0:
            print("  Failed :-(")
            raise ValueError()

    # Check that data exists for season and year
    base_path = r"./data_cache/s5_seasonal"
    search_path = os.path.join(base_path, f"s5_morsa_{year}_{season}_member*_bc.csv",)
    flist = glob.glob(search_path)

    if len(flist) != 25:
        message = (
            "ERROR: Cannot find cached forecast data for the selected season and year.\n"
            '       Consider trying again with the "Update/replace" option checked.'
        )
        print(message)
        raise ValueError(message)

    # Delete existing climate_forecast_summary.png to avoid confusion later
    clim_forecast_png = r"./forecast_output/climate_forecast_summary.png"
    if os.path.isfile(clim_forecast_png):
        os.remove(clim_forecast_png)

    # Calculate historical S5 quantiles (does not need to be re-run unless S5 download changes)
    s5_fold = (
        r"/home/jovyan/projects/WATExR/Norway_Morsa/Data/Meteorological/07_s5_seasonal"
    )
    quant_path = r"./data_cache/s5_seasonal/s5_quantiles_1993-2019.csv"
    # calculate_s5_quantiles(s5_fold, quant_path)

    # Average seasonal data
    s5_df = aggregate_s5_forecast(season, year)

    # Classify forecast
    res_dict = assign_quantiles(quant_path, season, s5_df)

    # Build table of historic performance (does not need to be re-run unless S5 download changes)
    terc_fold = r"/home/jovyan/projects/WATExR/Norway_Morsa/MetData_Processing/tercile_plots_stats/System5_vs_ERA5"
    perf_csv = r"./data_cache/s5_seasonal_forecast_performance_1993-2019.csv"
    # aggregate_performance_metrics(terc_fold, perf_csv)

    # Read table of historic performance
    perf_df = pd.read_csv(perf_csv)

    # Make summary image
    make_climate_forecast_png(season, res_dict, perf_df, clim_forecast_png)

    print("Done.")

    # Export PDF
    make_forecast_pdf(year, season)
