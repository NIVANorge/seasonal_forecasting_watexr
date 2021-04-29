def target_plot(mod, obs, ax=None, title=None):
    """ Target plot comparing normalised bias and normalised, unbiased RMSD between two 
        datasets (usually modelled versus observed). Based on code written by Leah 
        Jackson-Blake for the REFRESH project and described in the REFRESH report as 
        follows:
        
            "The y-axis shows normalised bias between simulated and observed. The 
             x-axis is the unbiased, normalised root mean square difference (RMSD) 
             between simulated and observed data. The distance between a point and the
             origin is total RMSD. RMSD = 1 is shown by the solid circle (any point 
             within this has positively correlated simulated and observed data and 
             positive Nash Sutcliffe scores); the dashed circle marks RMSD = 0.7. 
             Normalised unbiased root mean squared deviation is a useful way of 
             comparing standard deviations of the observed and modelled datasets."
             
        See Joliff et al. (2009) for full details:
        
            https://www.sciencedirect.com/science/article/pii/S0924796308001140
            
    Args:
        mod:   Array-like. 1D array or list of modelled values
        obs:   Array-like. 1D array or list of observed/reference values
        ax:    Matplotlib axis or None. Optional. Axis on which to plot, if desired
        title: Str. Optional. Title for plot
             
    Returns:
        Tuple (normalised_bias, normalised_unbiased_rmsd). Plot is created.
    """
    import numpy as np
    import scipy.stats as st
    import pandas as pd
    import matplotlib.pyplot as plt

    assert len(mod) == len(obs), "'mod' and 'obs' must be the same length."

    # Convert to dataframe
    df = pd.DataFrame({"mod": np.array(mod), "obs": np.array(obs),})

    # Drop null
    if df.isna().sum().sum() > 0:
        print("Dataset contains some NaN values. These will be ignored.")
        df.dropna(how="any", inplace=True)

    mod = df["mod"].values
    obs = df["obs"].values

    # Calculate stats.
    normed_bias = (mod.mean() - obs.mean()) / obs.std()
    pearson_cc, pearson_p = st.pearsonr(mod, obs)
    normed_std_dev = mod.std() / obs.std()
    normed_unbiased_rmsd = (
        1.0 + normed_std_dev ** 2 - (2 * normed_std_dev * pearson_cc)
    ) ** 0.5
    normed_unbiased_rmsd = np.copysign(normed_unbiased_rmsd, mod.std() - obs.std())

    # Setup plot
    if ax is None:
        fig = plt.figure(figsize=(5, 5))
        ax = fig.add_subplot(111, aspect="equal")

    inner_circle = plt.Circle((0, 0), 0.7, edgecolor="k", ls="--", lw=1, fill=False)
    ax.add_artist(inner_circle)

    outer_circle = plt.Circle((0, 0), 1, edgecolor="k", ls="-", lw=1, fill=False)
    ax.add_artist(outer_circle)

    vline = ax.vlines(0, -2, 2)
    hline = ax.hlines(0, -2, 2)

    # Add labels and titles
    ax.set_xlabel("Normalised, unbiased RMSD")
    ax.set_ylabel("Normalised bias")
    if title:
        ax.set_title(title)

    # Plot data
    ax.plot(normed_unbiased_rmsd, normed_bias, "ro", markersize=10, markeredgecolor="k")

    return (normed_bias, normed_unbiased_rmsd)
