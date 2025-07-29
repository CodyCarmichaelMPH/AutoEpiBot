# AutoEpiBot - Logging Helper
# Centralized Logging System

# Global logging configuration
log_config <- list(
  level = "INFO",
  include_timestamps = TRUE,
  log_file = NULL
)

# Initialize logging system
init_logging <- function(config) {
  log_config$level <<- config$logging$level
  log_config$include_timestamps <<- config$logging$include_timestamps
  
  # Set timezone for Tacoma, Washington (Pacific Time)
  if (!is.null(config$logging$timezone)) {
    Sys.setenv(TZ = config$logging$timezone)
  } else {
    Sys.setenv(TZ = "America/Los_Angeles")  # Default to Pacific Time
  }
  
  # Set up log file if specified
  if (!is.null(config$output$log_folder)) {
    # Use configurable log prefix
    log_prefix <- if (!is.null(config$output$system_log_prefix)) {
      config$output$system_log_prefix
    } else {
      "autoeipbot"
    }
    
    # Always use daily log files for system logs
    log_filename <- paste0(log_prefix, "_", format(Sys.Date(), "%Y-%m-%d"), ".log")
    log_config$log_file <<- file.path(config$output$log_folder, log_filename)
    
      # No log rotation needed for single CSV file
  }
  
  # Use cat instead of log_info to avoid circular dependency
  cat("Logging system initialized\n")
}

# Get current timestamp
get_timestamp <- function() {
  if (log_config$include_timestamps) {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  } else {
    ""
  }
}

# Write log message
write_log <- function(level, message) {
  timestamp <- get_timestamp()
  log_entry <- paste0("[", level, "] ", timestamp, " - ", message)
  
  # Print to console
  cat(log_entry, "\n")
  
  # Write to log file if configured
  if (!is.null(log_config$log_file)) {
    tryCatch({
      write(log_entry, log_config$log_file, append = TRUE)
    }, error = function(e) {
      # If we can't write to log file, just print to console
      cat("Warning: Could not write to log file:", e$message, "\n")
    })
  }
}

# Log levels
log_debug <- function(message) {
  if (!is.null(log_config$level) && log_config$level %in% c("DEBUG")) {
    write_log("DEBUG", message)
  }
}

log_info <- function(message) {
  if (!is.null(log_config$level) && log_config$level %in% c("DEBUG", "INFO")) {
    write_log("INFO", message)
  }
}

log_warn <- function(message) {
  if (!is.null(log_config$level) && log_config$level %in% c("DEBUG", "INFO", "WARN")) {
    write_log("WARN", message)
  }
}

log_error <- function(message) {
  if (!is.null(log_config$level) && log_config$level %in% c("DEBUG", "INFO", "WARN", "ERROR")) {
    write_log("ERROR", message)
  }
}

# Log system information
log_system_info <- function() {
  log_info("AutoEpiBot System Information")
  log_info(paste("R Version:", R.version.string))
  log_info(paste("Platform:", R.version$platform))
  log_info(paste("Working Directory:", getwd()))
  log_info(paste("Log Level:", log_config$level))
  log_info(paste("Timestamp Enabled:", log_config$include_timestamps))
  if (!is.null(log_config$log_file)) {
    log_info(paste("Log File:", log_config$log_file))
  }
  log_info("=====================================")
}

# Log configuration summary
log_config_summary <- function(config) {
  log_info("=== Configuration Summary ===")
  log_info(paste("Mode:", config$mode))
  log_info(paste("Syndromes:", length(config$syndromes)))
  for (syndrome in config$syndromes) {
    log_info(paste("  -", syndrome$name))
  }
  log_info(paste("Output Folder:", config$output$report_folder))
  log_info(paste("Log Folder:", config$output$log_folder))
  log_info(paste("Email Enabled:", config$email$enabled))
  log_info(paste("Historical Days:", config$validation$historical_days))
  log_info(paste("Min Alert Level:", config$validation$min_alert_level))
  log_info("=============================")
}

# Log API request details
log_api_request <- function(url, params, syndrome_name) {
  log_debug(paste("API Request for", syndrome_name))
  log_debug(paste("URL:", url))
  log_debug(paste("Parameters:", paste(names(params), params, sep = "=", collapse = ", ")))
}

# Log API response details
log_api_response <- function(response, syndrome_name) {
  status <- httr::status_code(response)
  log_debug(paste("API Response for", syndrome_name, "- Status:", status))
  
  if (status != 200) {
    log_error(paste("API Error for", syndrome_name, "- Status:", status))
    log_error(paste("Response:", httr::content(response, as = "text")))
  }
}

# Log validation results
log_validation_results <- function(syndrome_name, alert_date, validation_result) {
  log_info(paste("Validation Results for", syndrome_name, "on", alert_date))
  log_info(paste("  - Valid:", validation_result$is_valid))
  log_info(paste("  - Current Count:", validation_result$current_count))
  log_info(paste("  - Expected Count:", validation_result$expected_count))
  log_info(paste("  - Historical Mean:", round(validation_result$historical_mean, 1)))
  log_info(paste("  - Expected Ratio:", round(validation_result$expected_ratio, 2)))
  log_info(paste("  - Reason:", validation_result$reason))
}

# Log performance metrics
log_performance <- function(operation, start_time, end_time = Sys.time()) {
  duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
  log_info(paste("Performance:", operation, "-", round(duration, 2), "seconds"))
}

# Log memory usage
log_memory_usage <- function() {
  if (requireNamespace("pryr", quietly = TRUE)) {
    mem_usage <- pryr::mem_used()
    log_debug(paste("Memory Usage:", format(mem_usage, units = "MB")))
  }
}

# Log error with stack trace
log_error_with_trace <- function(error, context = "") {
  log_error(paste("Error in", context, ":", error$message))
  
  # Log stack trace if available
  if (!is.null(error$call)) {
    log_error("Call stack:")
    log_error(paste("  ", deparse(error$call)))
  }
}

# Log data quality metrics
log_data_quality <- function(data, context) {
  if (!is.null(data) && nrow(data) > 0) {
    log_info(paste("Data Quality for", context))
    log_info(paste("  - Rows:", nrow(data)))
    log_info(paste("  - Columns:", ncol(data)))
    log_info(paste("  - Missing Values:", sum(is.na(data))))
    
    # Log column names for debugging
    log_debug(paste("  - Columns:", paste(names(data), collapse = ", ")))
  } else {
    log_warn(paste("No data available for", context))
  }
}

# Log alert processing summary
log_alert_summary <- function(results) {
  log_info("=== Alert Processing Summary ===")
  
  total_syndromes <- length(results)
  total_alerts <- 0
  valid_alerts <- 0
  false_positives <- 0
  no_alerts <- 0
  no_data <- 0
  
  for (syndrome_name in names(results)) {
    syndrome_results <- results[[syndrome_name]]
    
    if (syndrome_results$status == "no_alerts") {
      no_alerts <- no_alerts + 1
    } else if (syndrome_results$status == "no_data") {
      no_data <- no_data + 1
    } else {
      for (date_result in syndrome_results) {
        if (is.list(date_result) && !is.null(date_result$status)) {
          total_alerts <- total_alerts + 1
          if (date_result$status == "sent") {
            valid_alerts <- valid_alerts + 1
          } else if (date_result$status == "false_positive") {
            false_positives <- false_positives + 1
          }
        }
      }
    }
  }
  
  log_info(paste("Total Syndromes:", total_syndromes))
  log_info(paste("Total Alerts:", total_alerts))
  log_info(paste("Valid Alerts:", valid_alerts))
  log_info(paste("False Positives:", false_positives))
  log_info(paste("No Alerts:", no_alerts))
  log_info(paste("No Data:", no_data))
  log_info("===============================")
}

# Log file operations
log_file_operation <- function(operation, file_path, success = TRUE) {
  if (success) {
    log_info(paste(operation, "successful:", file_path))
  } else {
    log_error(paste(operation, "failed:", file_path))
  }
}

# Log directory operations
log_directory_operation <- function(operation, dir_path, success = TRUE) {
  if (success) {
    log_info(paste(operation, "successful:", dir_path))
  } else {
    log_error(paste(operation, "failed:", dir_path))
  }
}

# Log email operations
log_email_operation <- function(operation, recipients, success = TRUE) {
  if (success) {
    log_info(paste(operation, "successful to", length(recipients), "recipients"))
  } else {
    log_error(paste(operation, "failed"))
  }
}

# Log configuration validation
log_config_validation <- function(config, validation_result) {
  if (validation_result) {
    log_info("Configuration validation successful")
  } else {
    log_error("Configuration validation failed")
  }
}

# Log startup sequence
log_startup <- function() {
  log_info("AutoEpiBot Starting")
  log_system_info()
}

# Log shutdown sequence
log_shutdown <- function() {
  log_info("AutoEpiBot Shutting Down")
  log_info("Cleanup completed")
}

# Log periodic status
log_status <- function(message) {
  log_info(paste("STATUS:", message))
}

# Log warning with context
log_warning_with_context <- function(message, context = "") {
  if (context != "") {
    log_warn(paste(context, ":", message))
  } else {
    log_warn(message)
  }
}

# Log success with context
log_success <- function(message, context = "") {
  if (context != "") {
    log_info(paste("SUCCESS:", context, "-", message))
  } else {
    log_info(paste("SUCCESS:", message))
  }
}

# Clean up old log files
cleanup_old_logs <- function(log_folder, log_prefix, max_files) {
  tryCatch({
    # Get all log files with the prefix
    log_files <- list.files(log_folder, pattern = paste0(log_prefix, "_.*\\.log$"), full.names = TRUE)
    
    if (length(log_files) > max_files) {
      # Sort by modification time (oldest first)
      file_info <- file.info(log_files)
      file_info$path <- log_files
      file_info <- file_info[order(file_info$mtime), ]
      
      # Remove oldest files beyond max_files
      files_to_remove <- file_info$path[1:(length(log_files) - max_files)]
      
      for (file in files_to_remove) {
        unlink(file)
        log_debug(paste("Removed old log file:", file))
      }
      
      log_info(paste("Cleaned up", length(files_to_remove), "old log files"))
    }
  }, error = function(e) {
    log_warn(paste("Error cleaning up old logs:", e$message))
  })
}

# Log report generation
log_report_generated <- function(report_path, syndrome_name, alert_date) {
  log_info(paste("Report generated:", report_path, "for", syndrome_name, "on", alert_date))
}

# Log report access
log_report_accessed <- function(report_path, access_type = "viewed") {
  log_info(paste("Report accessed:", report_path, "-", access_type))
}

# Get report statistics
get_report_statistics <- function(config) {
  # Use single CSV file for all alerts
  log_file_path <- file.path(config$output$log_folder, config$output$alert_log_file)
  
  if (file.exists(log_file_path)) {
    tryCatch({
      log_data <- read.csv(log_file_path, stringsAsFactors = FALSE)
      
      # Filter for reports generated
      reports <- log_data[log_data$status == "sent" & log_data$report_path != "", ]
      
      stats <- list(
        total_reports = nrow(reports),
        reports_by_syndrome = table(reports$syndrome),
        reports_by_date = table(format(as.Date(reports$date), "%Y-%m")),
        latest_report = if (nrow(reports) > 0) max(reports$date) else NULL
      )
      
      return(stats)
    }, error = function(e) {
      log_error(paste("Error getting report statistics:", e$message))
      return(NULL)
    })
  } else {
    return(NULL)
  }
}

# List available reports
list_available_reports <- function(config, syndrome = NULL, date_range = NULL) {
  # Use single CSV file for all alerts
  log_file_path <- file.path(config$output$log_folder, config$output$alert_log_file)
  
  if (file.exists(log_file_path)) {
    tryCatch({
      log_data <- read.csv(log_file_path, stringsAsFactors = FALSE)
      
      # Filter for reports generated
      reports <- log_data[log_data$status == "sent" & log_data$report_path != "", ]
      
      # Apply filters
      if (!is.null(syndrome)) {
        reports <- reports[reports$syndrome == syndrome, ]
      }
      
      if (!is.null(date_range)) {
        reports <- reports[reports$date >= date_range[1] & reports$date <= date_range[2], ]
      }
      
      return(reports)
    }, error = function(e) {
      log_error(paste("Error listing reports:", e$message))
      return(data.frame())
    })
  } else {
    return(data.frame())
  }
} 