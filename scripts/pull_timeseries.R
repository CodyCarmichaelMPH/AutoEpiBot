# AutoEpiBot - Pull Time Series Data
# NSSP ESSENCE API Time Series Data Retrieval

pull_timeseries <- function(syndrome, date_range, config) {
  log_info(paste("Pulling time series for", syndrome$name))
  
  tryCatch({
    # Build API URL
    url <- paste0(config$api$base_url, "/timeSeries")
    
    # Build query parameters
    params <- config$query_params
    params$startDate <- date_range$start_date_api
    params$endDate <- date_range$end_date_api
    params$ccddCategory <- syndrome$ccddCategory
    
    # Make API request
    response <- httr::GET(
      url,
      httr::authenticate(config$api$username, config$api$password),
      query = params,
      httr::timeout(30)
    )
    
    # Check response status
    if (httr::status_code(response) != 200) {
      log_error(paste("API request failed with status:", httr::status_code(response)))
      log_error(paste("Response:", httr::content(response, as = "text")))
      return(NULL)
    }
    
    # Parse JSON response
    json_data <- httr::content(response, as = "text", encoding = "UTF-8")
    parsed_data <- jsonlite::fromJSON(json_data, flatten = TRUE)
    
    # Convert to data frame
    if (is.null(parsed_data$timeSeriesData) || length(parsed_data$timeSeriesData) == 0) {
      log_warn(paste("No time series data returned for", syndrome$name))
      return(NULL)
    }
    
    df <- as.data.frame(parsed_data$timeSeriesData)
    
    # Convert date column
    df$date <- as.Date(df$date)
    
    # Ensure numeric columns
    numeric_cols <- c("count", "expected", "levels", "colorID")
    for (col in numeric_cols) {
      if (col %in% names(df)) {
        df[[col]] <- as.numeric(df[[col]])
      }
    }
    
    log_info(paste("Retrieved", nrow(df), "time series records for", syndrome$name))
    
    return(df)
    
  }, error = function(e) {
    log_error(paste("Error pulling time series for", syndrome$name, ":", e$message))
    return(NULL)
  })
}

# Pull data details for a specific date and syndrome
pull_data_details <- function(syndrome, alert_date, config) {
  log_info(paste("Pulling data details for", syndrome$name, "on", alert_date))
  
  tryCatch({
    # Build API URL for data details
    url <- paste0(config$api$base_url, "/dataDetails")
    
    # Build query parameters
    params <- config$query_params
    params$startDate <- format(as.Date(alert_date), "%d%b%Y")
    params$endDate <- format(as.Date(alert_date), "%d%b%Y")
    params$ccddCategory <- syndrome$ccddCategory
    
    # Make API request
    response <- httr::GET(
      url,
      httr::authenticate(config$api$username, config$api$password),
      query = params,
      httr::timeout(30)
    )
    
    # Check response status
    if (httr::status_code(response) != 200) {
      log_error(paste("Data details API request failed with status:", httr::status_code(response)))
      return(NULL)
    }
    
    # Parse JSON response
    json_data <- httr::content(response, as = "text", encoding = "UTF-8")
    parsed_data <- jsonlite::fromJSON(json_data, flatten = TRUE)
    
    # Convert to data frame
    if (is.null(parsed_data$dataDetails) || length(parsed_data$dataDetails) == 0) {
      log_warn(paste("No data details returned for", syndrome$name, "on", alert_date))
      return(NULL)
    }
    
    df <- as.data.frame(parsed_data$dataDetails)
    
    log_info(paste("Retrieved", nrow(df), "data detail records for", syndrome$name, "on", alert_date))
    
    return(df)
    
  }, error = function(e) {
    log_error(paste("Error pulling data details for", syndrome$name, ":", e$message))
    return(NULL)
  })
}

# Pull historical time series for validation
pull_historical_timeseries <- function(syndrome, alert_date, config) {
  log_info(paste("Pulling historical time series for", syndrome$name, "around", alert_date))
  
  tryCatch({
    # Calculate historical date range
    alert_date_obj <- as.Date(alert_date)
    end_date <- alert_date_obj - 1  # Day before alert
    start_date <- end_date - config$validation$historical_days + 1
    
    # Build API URL
    url <- paste0(config$api$base_url, "/timeSeries")
    
    # Build query parameters
    params <- config$query_params
    params$startDate <- format(start_date, "%d%b%Y")
    params$endDate <- format(end_date, "%d%b%Y")
    params$ccddCategory <- syndrome$ccddCategory
    
    # Make API request
    response <- httr::GET(
      url,
      httr::authenticate(config$api$username, config$api$password),
      query = params,
      httr::timeout(30)
    )
    
    # Check response status
    if (httr::status_code(response) != 200) {
      log_error(paste("Historical API request failed with status:", httr::status_code(response)))
      return(NULL)
    }
    
    # Parse JSON response
    json_data <- httr::content(response, as = "text", encoding = "UTF-8")
    parsed_data <- jsonlite::fromJSON(json_data, flatten = TRUE)
    
    # Convert to data frame
    if (is.null(parsed_data$timeSeriesData) || length(parsed_data$timeSeriesData) == 0) {
      log_warn(paste("No historical time series data returned for", syndrome$name))
      return(NULL)
    }
    
    df <- as.data.frame(parsed_data$timeSeriesData)
    
    # Convert date column
    df$date <- as.Date(df$date)
    
    # Ensure numeric columns
    numeric_cols <- c("count", "expected", "levels", "colorID")
    for (col in numeric_cols) {
      if (col %in% names(df)) {
        df[[col]] <- as.numeric(df[[col]])
      }
    }
    
    log_info(paste("Retrieved", nrow(df), "historical time series records for", syndrome$name))
    
    return(df)
    
  }, error = function(e) {
    log_error(paste("Error pulling historical time series for", syndrome$name, ":", e$message))
    return(NULL)
  })
}

# Pull detailed data for alert analysis
pull_alert_details <- function(syndrome, alert_date, config) {
  log_info(paste("Pulling detailed data for alert analysis:", syndrome$name, "on", alert_date))
  
  tryCatch({
    # Get detailed data for the alert date
    detailed_data <- pull_data_details(syndrome, alert_date, config)
    
    if (!is.null(detailed_data) && nrow(detailed_data) > 0) {
      # Add additional processing for enhanced analysis
      enhanced_data <- detailed_data %>%
        dplyr::mutate(
          # Create time categories
          time_category = case_when(
            hour_of_day >= 6 & hour_of_day < 12 ~ "Morning (6-11)",
            hour_of_day >= 12 & hour_of_day < 18 ~ "Afternoon (12-17)",
            hour_of_day >= 18 & hour_of_day < 24 ~ "Evening (18-23)",
            TRUE ~ "Night (0-5)"
          ),
          # Create age categories for analysis
          age_category = case_when(
            age_group == "0-4" ~ "Pediatric",
            age_group == "5-17" ~ "School Age",
            age_group == "18-44" ~ "Young Adult",
            age_group == "45-64" ~ "Middle Age",
            age_group == "65+" ~ "Senior"
          )
        )
      
      log_info(paste("Enhanced data prepared with", nrow(enhanced_data), "records"))
      return(enhanced_data)
    } else {
      log_warn("No detailed data available for enhanced analysis")
      return(data.frame())
    }
    
  }, error = function(e) {
    log_error(paste("Error preparing enhanced data:", e$message))
    return(data.frame())
  })
} 