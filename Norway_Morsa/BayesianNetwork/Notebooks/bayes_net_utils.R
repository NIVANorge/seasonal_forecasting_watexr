bayes_net_predict <- function(rfile_fpath, sd_fpath,
                              year, chla_prevSummer, colour_prevSummer, TP_prevSummer, wind_speed, rain) {
    #' Make predictions given the evidence provided based on the pre-fitted Bayesian network (saved as 
    #' 'Vansjo_fitted_seasonal_GaussianBN_1981-2018.rds'). 
    #' 
    #' Args:
    #'     rfile_fpath:       Str. Filepath to fitted BNLearn network object (.rds file)
    #'     sd_fpath:          Str. Filepath to csv containing standard deviation info from fitted BN
    #'     year:              Int. Year for prediction
    #'     chla_prevSummer:   Float. Chl-a measured from the previous summer (mg/l)
    #'     colour_prevSummer: Float. Colour measured from the previous summer (mg Pt/l)
    #'     TP_prevSummer:     Float. Total P measured from the previous summer (mg/l)
    #'     wind_speed:        Float. Predicted wind speed for season of interest (m/s)
    #'     rain:              Float. Predicted precipitation for season of interest (mm)
    #' 
    #' Returns:
    #'     R dataframe
    
    suppressMessages(library(tidyverse))
    suppressMessages(library(bnlearn))    
  
    # Build dataframe from input data
    year <- c(year)
    chla_prevSummer <- c(chla_prevSummer)
    colour_prevSummer <- c(colour_prevSummer)
    TP_prevSummer <- c(TP_prevSummer)
    wind_speed <- c(wind_speed)
    rain <- c(rain)
    
    driving_data <- data.frame(chla_prevSummer, colour_prevSummer, TP_prevSummer, wind_speed, rain)
    row.names(driving_data) <- year
      
    # Convert any integer cols to numeric    
    driving_data[1:ncol(driving_data)] = lapply(driving_data[1:ncol(driving_data)], as.numeric) 
      
    # Load fitted Bayesian network and pre-calculated std. devs.    
    fitted_BN = readRDS(rfile_fpath)
    sds = read.csv(file=sd_fpath, header=TRUE, sep=",")  
             
    # Nodes to make predictions for. Must match nodes present in the fitted BN.
    # Add check that list is sorted alphabetically, as concatenation of final df assumes this
    nodes_to_predict = sort(c('chla','colour','cyano', 'TP')) 
        
    set.seed(1)
    
    # Loop over nodes and derive expected values
    expectedValue_li = vector(mode = "list", length = 0)
    
    for (node in nodes_to_predict){
        pred = predict(fitted_BN,
                       data=driving_data,
                       node=node,
                       method='bayes-lw',
                       n=10000
                      )
         
        # If node is cyano, then remove the boxcox transformation before adding expected value to list
        if (node=="cyano"){
            pred = (pred*0.1 + 1)**(1/0.1) # 0.1 is lambda value chosen in transformation
        } 
        expectedValue_li[[node]] = pred # Update list with value for this node
    }
    
    # Sort alphabetically    
    expectedValue_li = expectedValue_li[order(names(expectedValue_li))] 
    
    # Just select values associated with nodes for prediction, and sort alphabetically
    sd_predictedNodes = filter(sds, node %in% nodes_to_predict)
    sd_predictedNodes = sd_predictedNodes[order(sd_predictedNodes$node),]
    
    # Thresholds to use in classification
    boundaries_list = list('TP' = 29.5,     # Middle of 'Moderate' class
                           'chla' = 20.0,   # M-P boundary. WFD boundaries: [10.5, 20.0]. Only 6 observed points under 10.5 so merge G & M
                           'colour' = 48.0, # 66th percentile (i.e. upper tercile). No management implications
                           'cyano' = 1.0    # M-P boundary is 2.0, but there were only 2 values in this class. Plenty above 2 tho
                           )
    
    # Sort alphabetically
    boundaries_list = boundaries_list[order(names(boundaries_list))] 
        
    # Data for evidence, converted to named list
    evidence_li = as.list(driving_data)
    
    # Empty list to be populated with probability of being below boundary
    prob_li = vector(mode = "list", length = 0)
      
    # Loop over nodes and predict probabilities of being within various classes
    for (node in nodes_to_predict){
        boundary = unlist(boundaries_list[node], use.names=FALSE)
    
        # If cyanomax, apply boxcox transformation with lambda=0.1 to boundary first
        if (node=='cyano'){
            boundary = (boundary^0.1 - 1)/0.1
        }
        
        # Horrible hack to make 'query' available in the global namespace. See
        #     https://stackoverflow.com/q/19260580/505698
        query <<- paste("(", node, ' < ', boundary, ")", sep="")  
        prob = cpquery(fitted_BN,
                       event = eval(parse(text = query)),
                       evidence=evidence_li,
                       method='lw'
                      )
        
        # Round to 2 d.p. Below this, cpquery returns variable results over diff calls
        # Even with rounding, still get some variability in results
        prob = round(prob,digits=2)
        
        prob_li[[node]] = prob
    }   
    
    # Sort alphabetically
    prob_li = prob_li[order(names(prob_li))] # Sort alphabetically
    
    # Build dataframe
    prob_df = data.frame(node=nodes_to_predict,
                         threshold = unlist(boundaries_list, use.names=FALSE),
                         prob_below_threshold = unlist(prob_li, use.names=FALSE),
                         prob_above_threshold = 1-unlist(prob_li, use.names=FALSE),
                         expected_value = signif(unlist(expectedValue_li, use.names=FALSE),3), #Round to 3 s.f
                         st_dev = signif(sd_predictedNodes['sd'], 3)                           # Round to 3 s.f
                        ) 
  
    return(prob_df)
}

bayes_net_predict_operational <- function(rfile_fpath,
                                          year, chla_prevSummer, colour_prevSummer, TP_prevSummer) {
    #' Make predictions given the evidence provided based on the pre-fitted Bayesian network (saved as 
    #' 'Vansjo_fitted_seasonal_GaussianBN_1981-2019.rds'. Drop met nodes for operational forecast,
    #' and only forecast for TP, colour and cyano (not chla)). Remove standard deviation info.
    #' 
    #' Args:
    #'     rfile_fpath:       Str. Filepath to fitted BNLearn network object (.rds file)
    #'     year:              Int. Year for prediction
    #'     chla_prevSummer:   Float. Chl-a measured from the previous summer (mg/l)
    #'     colour_prevSummer: Float. Colour measured from the previous summer (mg Pt/l)
    #'     TP_prevSummer:     Float. Total P measured from the previous summer (mg/l)
    #' 
    #' Returns:
    #'     R dataframe
    
    suppressMessages(library(tidyverse))
    suppressMessages(library(bnlearn))    
  
    # Build dataframe from input data
    year <- c(year)
    chla_prevSummer <- c(chla_prevSummer)
    colour_prevSummer <- c(colour_prevSummer)
    TP_prevSummer <- c(TP_prevSummer)
    
    driving_data <- data.frame(chla_prevSummer, colour_prevSummer, TP_prevSummer)
    row.names(driving_data) <- year
      
    # Convert any integer cols to numeric    
    driving_data[1:ncol(driving_data)] = lapply(driving_data[1:ncol(driving_data)], as.numeric) 
      
    # Load fitted Bayesian network and pre-calculated std. devs.    
    fitted_BN = readRDS(rfile_fpath)
             
    # Nodes to make predictions for. Must match nodes present in the fitted BN.
    # Add check that list is sorted alphabetically, as concatenation of final df assumes this
    nodes_to_predict = sort(c('colour','cyano', 'TP')) 
    
    # Nodes to use when making predictions
    nodes_to_use = list('TP' = c('TP_prevSummer', 'chla_prevSummer'),
                        'colour' = c('colour_prevSummer'),
                        'cyano' = c("chla_prevSummer","TP_prevSummer","colour_prevSummer"))
        
    set.seed(1)
    
    # Loop over nodes and derive expected values
    expectedValue_li = vector(mode = "list", length = 0)
    
    for (node in nodes_to_predict){
        pred = predict(fitted_BN,
                       data=driving_data,
                       node=node,
                       method='bayes-lw',
                       from = unlist(nodes_to_use[node], use.names=FALSE),
                       n=10000
                      )
         
        # If node is cyano, then remove the boxcox transformation before adding expected value to list
        if (node=="cyano"){
            pred = (pred*0.1 + 1)**(1/0.1) # 0.1 is lambda value chosen in transformation
        } 
        expectedValue_li[[node]] = pred # Update list with value for this node
    }
    
    # Sort alphabetically    
    expectedValue_li = expectedValue_li[order(names(expectedValue_li))] 
    
    # Thresholds to use in classification
    boundaries_list = list('TP' = 29.5,     # Middle of 'Moderate' class
                           'colour' = 48.0, # 66th percentile (i.e. upper tercile). No management implications
                           'cyano' = 1.0    # M-P boundary is 2.0, but there were only 2 values in this class. Plenty above 2 tho
                           )
    
    # Sort alphabetically
    boundaries_list = boundaries_list[order(names(boundaries_list))]
        
    # Data for evidence, converted to named list
    evidence_li = as.list(driving_data)
    
    # Empty list to be populated with probability of being below boundary
    prob_li = vector(mode = "list", length = 0)
      
    # Loop over nodes and predict probabilities of being within various classes
    for (node in nodes_to_predict){
        boundary = unlist(boundaries_list[node], use.names=FALSE)
    
        # If cyanomax, apply boxcox transformation with lambda=0.1 to boundary first
        if (node=='cyano'){
            boundary = (boundary^0.1 - 1)/0.1
        }
        
        # Horrible hack to make 'query' available in the global namespace. See
        #     https://stackoverflow.com/q/19260580/505698
        query <<- paste("(", node, ' < ', boundary, ")", sep="")  
        prob = cpquery(fitted_BN,
                       event = eval(parse(text = query)),
                       evidence=evidence_li,
                       method='lw'
                      )
        
        # Round to 2 d.p. Below this, cpquery returns variable results over diff calls
        # Even with rounding, still get some variability in results
        prob = round(prob,digits=2)
        
        prob_li[[node]] = prob
    }   
    
    # Sort alphabetically
    prob_li = prob_li[order(names(prob_li))] # Sort alphabetically
    
    # Build dataframe
    prob_df = data.frame(node=nodes_to_predict,
                         threshold = unlist(boundaries_list, use.names=FALSE),
                         prob_below_threshold = unlist(prob_li, use.names=FALSE),
                         prob_above_threshold = 1-unlist(prob_li, use.names=FALSE),
                         expected_value = signif(unlist(expectedValue_li, use.names=FALSE),3) #Round to 3 s.f
                        ) 
  
    return(prob_df)
}

tercile_plot_from_dataframes <- function(obs_df, s5_df, var_name, pdf_path) {
    #' Hacky function for reformatting R dataframes produced by the Bayesian network for use  
    #' with VisualizeR's 'tercilePlot' function. This is achieved by munging/overwriting data 
    #' & attributes in two pre-existing Climate4R objects. It's not pretty, but easier than 
    #' creating the objects from scratch.'
    #' 
    #' Each dataframe MUST contain data for only a single node/variable.
    #' 
    #' Args:
    #'     obs_df:   Dataframe. Must have columns named 'year', 'node' and 'value'
    #'     s5_df:    Dataframe. Must have columns named 'year', 'node' and 'sim_s5_01' to 
    #'               'sim_s5_25' 
    #'     var_name: Str. Name of variable for use in plot title
    #'     pdf_path: Str. File path for PDF to be created
    #' 
    #' Returns:
    #'     None. The tercile plot is saved as a PDF to 'pdf_path'.
    suppressMessages(library(loadeR))
    suppressMessages(library(visualizeR))  
    suppressMessages(library(Cairo)) 
  
    # Read previously downloaded ERA5 and S5 datasets with the correct Climate4R format.
    # These are used as "templates" to be overwritten with new data, as this is easier than
    # manually constructing appropriate Climate4R objects
    ers5_path <- '../../Data/Meteorological/RData/era5_morsa_1980-2019_daily.rda'
    load(file=ers5_path)
    e5 <- era5_daily[[1]]

    s5_path <- '../../Data/Meteorological/RData/s5_morsa_bayes_net_hindcast_summer.rda'
    load(file=s5_path)
    s5 <- data[[1]]
    
    # Update relevant parts of "observed" dataset
    e5$Dates$start <- as.Date(ISOdate(obs_df$year, 5, 1))
    e5$Dates$end <- as.Date(ISOdate(obs_df$year, 10, 31))
    e5$Data <- obs_df$value
    
    attr(e5$Data, 'dimensions') = 'time'
    attr(e5$Data, 'dim') = length(obs_df$value)

    # Update relevant parts of S5 dataset
    s5$Dates$start <- as.Date(ISOdate(s5_df$year, 5, 1))
    s5$Dates$end <- as.Date(ISOdate(s5_df$year, 10, 31))
    
    drops <- c("X", "year", "node")
    s5_df_vals <- s5_df[ , !(names(s5_df) %in% drops)]
    s5$Data <- t(as.matrix(s5_df_vals))
    
    attr(s5$Data, 'dimensions') = c('member', 'time')  
    attr(s5$Variable, 'longname') <- var_name

    # Save
    CairoPDF(file = pdf_path, width = 10)
    tercilePlot(obs = redim(e5), hindcast = redim(s5))
    dev.off()        
}