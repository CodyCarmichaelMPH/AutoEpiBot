#!/usr/bin/env Rscript
# AutoEpiBot Main Entry Point
# NSSP ESSENCE Multi-Syndrome Alert Automation
#
# Usage:
#   Rscript main.R --mode rolling
#   Rscript main.R --mode manual --startDate 2025-07-01 --endDate 2025-07-20
#   Rscript main.R --dry-run

suppressPackageStartupMessages({
  library(yaml)
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(lubridate)
  library(rmarkdown)
  library(blastula)
  library(ggplot2)
  library(knitr)
})

# Source all script modules
source("scripts/pull_timeseries.R")
source("scripts/validate_alert.R")
source("scripts/generate_report.R")
source("scripts/send_email.R")
source("scripts/helpers/logging.R")

# Parse command line arguments
parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default values
  config <- list(
    mode = "rolling",
    startDate = NULL,
    endDate = NULL,
    dry_run = FALSE
  )
  
  i <- 1
  while (i <= length(args)) {
    arg <- args[i]
    
    if (arg == "--mode") {
      if (i + 1 <= length(args)) {
        config$mode <- args[i + 1]
        i <- i + 1
      }
    } else if (arg == "--startDate") {
      if (i + 1 <= length(args)) {
        config$startDate <- args[i + 1]
        i <- i + 1
      }
    } else if (arg == "--endDate") {
      if (i + 1 <= length(args)) {
        config$endDate <- args[i + 1]
        i <- i + 1
      }
    } else if (arg == "--dry-run") {
      config$dry_run <- TRUE
    } else if (arg == "--help") {
      cat("AutoEpiBot - NSSP ESSENCE Alert Automation\n")
      cat("Usage:\n")
      cat("  Rscript main.R --mode rolling\n")
      cat("  Rscript main.R --mode manual --startDate 2025-07-01 --endDate 2025-07-20\n")
      cat("  Rscript main.R --dry-run\n")
      cat("Options:\n")
      cat("  --mode        Execution mode: 'rolling' or 'manual'\n")
      cat("  --startDate   Start date (YYYY-MM-DD format, manual mode only)\n")
      cat("  --endDate     End date (YYYY-MM-DD format, manual mode only)\n")
      cat("  --dry-run     Run without sending emails or creating reports\n")
      cat("  --help        Show this help message\n")
      quit(status = 0)
    }
    i <- i + 1
  }
  
  return(config)
}

# Load and validate configuration
load_config <- function(cli_args) {
  # Load YAML config
  if (!file.exists("config.yaml")) {
    stop("Configuration file 'config.yaml' not found")
  }
  
  config <- read_yaml("config.yaml")
  
  # Override with CLI arguments
  if (cli_args$mode != "rolling") {
    config$mode <- cli_args$mode
  }
  
  if (!is.null(cli_args$startDate)) {
    config$startDate <- cli_args$startDate
  }
  
  if (!is.null(cli_args$endDate)) {
    config$endDate <- cli_args$endDate
  }
  
  config$dry_run <- cli_args$dry_run
  
  # Validate configuration
  validate_config(config)
  
  return(config)
}

# Validate configuration parameters
validate_config <- function(config) {
  # Check required fields
  required_fields <- c("api", "syndromes", "output", "validation")
  for (field in required_fields) {
    if (is.null(config[[field]])) {
      stop(paste("Missing required configuration field:", field))
    }
  }
  
  # Validate mode
  if (!config$mode %in% c("rolling", "manual")) {
    stop("Mode must be 'rolling' or 'manual'")
  }
  
  # Validate manual mode parameters
  if (config$mode == "manual") {
    if (is.null(config$startDate) || is.null(config$endDate)) {
      stop("Manual mode requires both startDate and endDate")
    }
    
    # Validate date format
    tryCatch({
      as.Date(config$startDate)
      as.Date(config$endDate)
    }, error = function(e) {
      stop("Invalid date format. Use YYYY-MM-DD")
    })
  }
  
  # Create output directories
  dir.create(config$output$report_folder, recursive = TRUE, showWarnings = FALSE)
  dir.create(config$output$log_folder, recursive = TRUE, showWarnings = FALSE)
  
  log_info("Configuration validated successfully")
}

# Calculate date range based on mode
calculate_date_range <- function(config) {
  if (config$mode == "rolling") {
    end_date <- Sys.Date() - 1  # Yesterday
    start_date <- end_date - config$rollingWindowDays + 1
  } else {
    start_date <- as.Date(config$startDate)
    end_date <- as.Date(config$endDate)
  }
  
  # Convert to API format (DDMonYYYY)
  start_date_api <- format(start_date, "%d%b%Y")
  end_date_api <- format(end_date, "%d%b%Y")
  
  log_info(paste("Date range:", start_date_api, "to", end_date_api))
  
  return(list(
    start_date = start_date,
    end_date = end_date,
    start_date_api = start_date_api,
    end_date_api = end_date_api
  ))
}

# Main execution function
main <- function() {
  tryCatch({
    # Parse command line arguments
    cli_args <- parse_args()
    
    # Load configuration
    config <- load_config(cli_args)
    
    # Initialize logging
    init_logging(config)
    log_startup()
    
    # Calculate date range
    date_range <- calculate_date_range(config)
    
    # Load alert log
    alert_log <- load_alert_log(config)
    
    # Process each syndrome
    results <- list()
    for (syndrome in config$syndromes) {
      log_info(paste("Processing syndrome:", syndrome$name))
      
      tryCatch({
        result <- process_syndrome(syndrome, date_range, config, alert_log)
        results[[syndrome$name]] <- result
      }, error = function(e) {
        log_error(paste("Error processing syndrome", syndrome$name, ":", e$message))
      })
    }
    
    # Send leadership report email if not dry run
    if (!config$dry_run && config$email$enabled) {
      send_leadership_report_email(results, config, date_range)
    }
    
    log_shutdown()
    
  }, error = function(e) {
    log_error(paste("Fatal error:", e$message))
    quit(status = 1)
  })
}

# Process a single syndrome
process_syndrome <- function(syndrome, date_range, config, alert_log) {
  # Pull time series data
  timeseries_data <- pull_timeseries(syndrome, date_range, config)
  
  if (is.null(timeseries_data) || nrow(timeseries_data) == 0) {
    log_warn(paste("No time series data for", syndrome$name))
    return(list(status = "no_data"))
  }
  
  # Check for alerts
  alerts <- timeseries_data %>%
    filter(colorID >= config$validation$min_alert_level) %>%
    arrange(date)
  
  if (nrow(alerts) == 0) {
    log_info(paste("No alerts for", syndrome$name))
    return(list(status = "no_alerts"))
  }
  
  results <- list()
  
  for (i in 1:nrow(alerts)) {
    alert_date <- alerts$date[i]
    alert_color <- alerts$color[i]
    
    # Check if already processed
    if (is_alert_processed(syndrome$name, alert_date, alert_log)) {
      log_info(paste("Alert already processed for", syndrome$name, "on", alert_date))
      next
    }
    
    log_info(paste("Processing alert for", syndrome$name, "on", alert_date))
    
    # Validate alert
    validation_result <- validate_alert(syndrome, alert_date, config)
    
          if (validation_result$is_valid) {
        # Generate report
        report_path <- generate_report(syndrome, alert_date, validation_result, config)
        
        # Log as sent with report path
        log_alert_action(syndrome$name, alert_date, alert_color, "sent", config, report_path)
        
        results[[as.character(alert_date)]] <- list(
          status = "sent",
          report_path = report_path,
          validation = validation_result
        )
      } else {
        # Log as false positive
        log_alert_action(syndrome$name, alert_date, alert_color, "false_positive", config)
        
        results[[as.character(alert_date)]] <- list(
          status = "false_positive",
          validation = validation_result
        )
      }
  }
  
  return(results)
}

# Run main function if script is executed directly
if (!interactive()) {
  main()
} 