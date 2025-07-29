# AutoEpiBot - Alert Validation
# NSSP ESSENCE Alert Validation and False Positive Detection

validate_alert <- function(syndrome, alert_date, config) {
  log_info(paste("Validating alert for", syndrome$name, "on", alert_date))
  
  tryCatch({
    # Pull data details for the alert date
    data_details <- pull_data_details(syndrome, alert_date, config)
    
    if (is.null(data_details) || nrow(data_details) == 0) {
      log_warn(paste("No data details available for validation of", syndrome$name, "on", alert_date))
      return(list(
        is_valid = FALSE,
        reason = "No data details available",
        current_count = 0,
        expected_count = 0,
        historical_mean = 0,
        deduplicated_count = 0
      ))
    }
    
    # Deduplicate by BioSense_ID
    if ("BioSense_ID" %in% names(data_details)) {
      deduplicated_data <- data_details %>%
        distinct(BioSense_ID, .keep_all = TRUE)
      
      current_count <- nrow(deduplicated_data)
      log_info(paste("Deduplicated count for", syndrome$name, "on", alert_date, ":", current_count))
    } else {
      current_count <- nrow(data_details)
      log_warn("BioSense_ID column not found, using raw count")
    }
    
    # Pull historical time series for comparison
    historical_data <- pull_historical_timeseries(syndrome, alert_date, config)
    
    if (is.null(historical_data) || nrow(historical_data) == 0) {
      log_warn(paste("No historical data available for validation of", syndrome$name, "on", alert_date))
      return(list(
        is_valid = FALSE,
        reason = "No historical data available",
        current_count = current_count,
        expected_count = 0,
        historical_mean = 0,
        deduplicated_count = current_count
      ))
    }
    
    # Calculate historical statistics
    historical_mean <- mean(historical_data$count, na.rm = TRUE)
    historical_sd <- sd(historical_data$count, na.rm = TRUE)
    
    # Get expected count from time series data
    alert_date_obj <- as.Date(alert_date)
    current_timeseries <- historical_data %>%
      filter(date == alert_date_obj)
    
    expected_count <- if (nrow(current_timeseries) > 0) {
      current_timeseries$expected[1]
    } else {
      historical_mean  # Fallback to historical mean
    }
    
    # Validation logic
    validation_result <- perform_validation_checks(
      current_count = current_count,
      expected_count = expected_count,
      historical_mean = historical_mean,
      historical_sd = historical_sd,
      config = config
    )
    
    log_info(paste("Validation result for", syndrome$name, "on", alert_date, ":", 
                   ifelse(validation_result$is_valid, "VALID", "FALSE POSITIVE")))
    
    return(c(validation_result, list(
      current_count = current_count,
      expected_count = expected_count,
      historical_mean = historical_mean,
      historical_sd = historical_sd,
      deduplicated_count = current_count
    )))
    
  }, error = function(e) {
    log_error(paste("Error validating alert for", syndrome$name, "on", alert_date, ":", e$message))
    return(list(
      is_valid = FALSE,
      reason = paste("Validation error:", e$message),
      current_count = 0,
      expected_count = 0,
      historical_mean = 0,
      deduplicated_count = 0
    ))
  })
}

# Perform validation checks
perform_validation_checks <- function(current_count, expected_count, historical_mean, historical_sd, config) {
  # Check 1: Current count vs expected
  expected_ratio <- if (expected_count > 0) current_count / expected_count else 0
  
  # Check 2: Current count vs historical mean
  historical_ratio <- if (historical_mean > 0) current_count / historical_mean else 0
  
  # Check 3: Statistical significance (if we have historical SD)
  z_score <- if (historical_sd > 0) {
    (current_count - historical_mean) / historical_sd
  } else {
    0
  }
  
  # Validation criteria
  is_above_expected <- expected_ratio > 1.0
  is_above_historical <- historical_ratio > 1.0
  is_statistically_significant <- z_score > 1.96  # 95% confidence interval
  
  # False positive threshold check
  false_positive_threshold <- config$validation$false_positive_threshold
  is_below_false_positive_threshold <- expected_ratio < false_positive_threshold
  
  # Determine if alert is valid
  is_valid <- is_above_expected && is_above_historical && !is_below_false_positive_threshold
  
  # Generate reason for validation decision
  reasons <- c()
  if (!is_above_expected) {
    reasons <- c(reasons, "Current count below expected")
  }
  if (!is_above_historical) {
    reasons <- c(reasons, "Current count below historical mean")
  }
  if (is_below_false_positive_threshold) {
    reasons <- c(reasons, paste("Below false positive threshold (", false_positive_threshold, "x expected)"))
  }
  
  reason <- if (length(reasons) > 0) {
    paste(reasons, collapse = "; ")
  } else {
    "Alert validated successfully"
  }
  
  return(list(
    is_valid = is_valid,
    reason = reason,
    expected_ratio = expected_ratio,
    historical_ratio = historical_ratio,
    z_score = z_score,
    is_above_expected = is_above_expected,
    is_above_historical = is_above_historical,
    is_statistically_significant = is_statistically_significant,
    is_below_false_positive_threshold = is_below_false_positive_threshold
  ))
}

# Check if alert has already been processed
is_alert_processed <- function(syndrome_name, alert_date, alert_log) {
  if (is.null(alert_log) || nrow(alert_log) == 0) {
    return(FALSE)
  }
  
  # Check if this syndrome/date combination exists in the log
  processed <- alert_log %>%
    filter(syndrome == syndrome_name, date == alert_date) %>%
    nrow() > 0
  
  return(processed)
}

# Load alert log
load_alert_log <- function(config) {
  # Use single CSV file for all alerts
  log_file_path <- file.path(config$output$log_folder, config$output$alert_log_file)
  
  if (file.exists(log_file_path)) {
    tryCatch({
      log_data <- read.csv(log_file_path, stringsAsFactors = FALSE)
      log_data$date <- as.Date(log_data$date)
      # Don't log here - logging will be initialized later
      return(log_data)
    }, error = function(e) {
      # Don't log here - logging will be initialized later
      return(data.frame())
    })
  } else {
    # Don't log here - logging will be initialized later
    return(data.frame())
  }
}

# Log alert action with report tracking
log_alert_action <- function(syndrome_name, alert_date, alert_color, action, config, report_path = NULL) {
  # Create structured log entry for leadership reporting
  log_entry <- data.frame(
    date = as.Date(alert_date),
    syndrome = syndrome_name,
    alert_type = alert_color,
    status = action,
    report_path = ifelse(is.null(report_path), "", report_path),
    timestamp = Sys.time(),
    stringsAsFactors = FALSE
  )
  
  # Use single CSV file for all alerts
  log_file_path <- file.path(config$output$log_folder, config$output$alert_log_file)
  
  # Append to existing log or create new
  if (file.exists(log_file_path)) {
    existing_log <- read.csv(log_file_path, stringsAsFactors = FALSE)
    existing_log$date <- as.Date(existing_log$date)
    updated_log <- rbind(existing_log, log_entry)
  } else {
    updated_log <- log_entry
  }
  
  # Write updated log
  write.csv(updated_log, log_file_path, row.names = FALSE)
  
  # Log to system log as well
  if (!is.null(report_path) && report_path != "") {
    log_info(paste("Report generated:", report_path, "for", syndrome_name, "on", alert_date))
  } else {
    log_info(paste("Logged", action, "for", syndrome_name, "on", alert_date))
  }
} 