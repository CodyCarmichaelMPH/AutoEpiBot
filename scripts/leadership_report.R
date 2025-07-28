#!/usr/bin/env Rscript
# AutoEpiBot Leadership Reporting Utility
# Provides CSV-based reporting for leadership

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
  library(lubridate)
})

# Load configuration
load_config <- function(config_path = "config.yaml") {
  tryCatch({
    config <- yaml::read_yaml(config_path)
    return(config)
  }, error = function(e) {
    cat("Error loading config:", e$message, "\n")
    return(NULL)
  })
}

# Load alert log data
load_alert_data <- function(config) {
  # Determine log file path based on format
  if (!is.null(config$output$log_format) && config$output$log_format == "csv_by_year") {
    current_year <- format(Sys.Date(), "%Y")
    log_prefix <- if (!is.null(config$output$system_log_prefix)) {
      config$output$system_log_prefix
    } else {
      "autoeipbot"
    }
    log_file_path <- file.path(config$output$log_folder, paste0(log_prefix, "_", current_year, ".csv"))
  } else {
    log_file_path <- file.path(config$output$log_folder, config$output$alert_log_file)
  }
  
  if (file.exists(log_file_path)) {
    tryCatch({
      data <- read.csv(log_file_path, stringsAsFactors = FALSE)
      data$date <- as.Date(data$date)
      return(data)
    }, error = function(e) {
      cat("Error loading alert data:", e$message, "\n")
      return(data.frame())
    })
  } else {
    cat("No alert log file found at:", log_file_path, "\n")
    return(data.frame())
  }
}

# Generate leadership summary report
generate_leadership_summary <- function(config, date_range = NULL) {
  cat("AutoEpiBot Leadership Summary Report\n")
  cat("===================================\n\n")
  
  # Load data
  data <- load_alert_data(config)
  
  if (nrow(data) == 0) {
    cat("No alert data available for reporting.\n")
    return()
  }
  
  # Filter by date range if specified
  if (!is.null(date_range)) {
    data <- data[data$date >= date_range[1] & data$date <= date_range[2], ]
  }
  
  # Summary statistics
  cat("Report Period:", if(!is.null(date_range)) {
    paste(format(date_range[1], "%Y-%m-%d"), "to", format(date_range[2], "%Y-%m-%d"))
  } else {
    paste("All available data (", format(min(data$date), "%Y-%m-%d"), "to", format(max(data$date), "%Y-%m-%d"), ")")
  }, "\n\n")
  
  # Date range scanned
  cat("Date Range Scanned:\n")
  cat("- Start:", format(min(data$date), "%Y-%m-%d"), "\n")
  cat("- End:", format(max(data$date), "%Y-%m-%d"), "\n")
  cat("- Total Days:", n_distinct(data$date), "\n\n")
  
  # Alert activity
  alert_dates <- unique(data$date[data$status %in% c("sent", "false_positive")])
  cat("Alert Activity:\n")
  cat("- Dates with Alerts/Warnings:", length(alert_dates), "\n")
  if (length(alert_dates) > 0) {
    cat("- Alert Dates:", paste(format(alert_dates, "%Y-%m-%d"), collapse = ", "), "\n")
  }
  cat("\n")
  
  # Syndrome analysis
  syndrome_summary <- data %>%
    group_by(syndrome) %>%
    summarise(
      total_alerts = n(),
      valid_alerts = sum(status == "sent"),
      false_positives = sum(status == "false_positive"),
      reports_generated = sum(status == "sent" & report_path != "")
    )
  
  cat("Syndrome Analysis:\n")
  cat("=================\n")
  for (i in 1:nrow(syndrome_summary)) {
    row <- syndrome_summary[i, ]
    cat(sprintf("%-20s: %d total, %d valid, %d false positives, %d reports\n",
                row$syndrome, row$total_alerts, row$valid_alerts, 
                row$false_positives, row$reports_generated))
  }
  cat("\n")
  
  # Syndromes with alerts
  alert_syndromes <- syndrome_summary$syndrome[syndrome_summary$valid_alerts > 0]
  cat("Syndromes with Alerts/Warnings:\n")
  if (length(alert_syndromes) > 0) {
    for (syndrome in alert_syndromes) {
      cat("-", syndrome, "\n")
    }
  } else {
    cat("- None\n")
  }
  cat("\n")
  
  # Syndromes with false positives
  fp_syndromes <- syndrome_summary$syndrome[syndrome_summary$false_positives > 0]
  cat("Syndromes with False Positives:\n")
  if (length(fp_syndromes) > 0) {
    for (syndrome in fp_syndromes) {
      cat("-", syndrome, "\n")
    }
  } else {
    cat("- None\n")
  }
  cat("\n")
  
  # Report locations
  reports <- data[data$status == "sent" & data$report_path != "", ]
  cat("Generated Reports and Locations:\n")
  if (nrow(reports) > 0) {
    for (i in 1:nrow(reports)) {
      row <- reports[i, ]
      cat("-", row$syndrome, "(", format(row$date, "%Y-%m-%d"), "):", row$report_path, "\n")
    }
  } else {
    cat("- No reports generated\n")
  }
  cat("\n")
  
  # Overall statistics
  cat("Overall Statistics:\n")
  cat("==================\n")
  cat("- Total Alerts Processed:", nrow(data), "\n")
  cat("- Valid Alerts:", sum(data$status == "sent"), "\n")
  cat("- False Positives:", sum(data$status == "false_positive"), "\n")
  cat("- Reports Generated:", sum(data$status == "sent" & data$report_path != ""), "\n")
  cat("- Unique Syndromes:", n_distinct(data$syndrome), "\n")
  cat("- Date Range:", format(min(data$date), "%Y-%m-%d"), "to", format(max(data$date), "%Y-%m-%d"), "\n")
}

# Export data for external analysis
export_leadership_data <- function(config, output_file = "leadership_report.csv", date_range = NULL) {
  data <- load_alert_data(config)
  
  if (nrow(data) == 0) {
    cat("No data to export.\n")
    return()
  }
  
  # Filter by date range if specified
  if (!is.null(date_range)) {
    data <- data[data$date >= date_range[1] & data$date <= date_range[2], ]
  }
  
  # Export to CSV
  write.csv(data, output_file, row.names = FALSE)
  cat("Data exported to:", output_file, "\n")
  cat("Rows exported:", nrow(data), "\n")
}

# Main function
main <- function() {
  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0 || "--help" %in% args) {
    cat("AutoEpiBot Leadership Reporting Utility\n")
    cat("Usage:\n")
    cat("  Rscript leadership_report.R [options]\n")
    cat("\nOptions:\n")
    cat("  --summary              Generate summary report\n")
    cat("  --export [filename]    Export data to CSV\n")
    cat("  --start-date YYYY-MM-DD  Start date for filtering\n")
    cat("  --end-date YYYY-MM-DD    End date for filtering\n")
    cat("  --help                 Show this help message\n")
    return()
  }
  
  # Load configuration
  config <- load_config()
  if (is.null(config)) {
    cat("Failed to load configuration.\n")
    return(1)
  }
  
  # Parse date range
  date_range <- NULL
  start_date_idx <- which(args == "--start-date")
  end_date_idx <- which(args == "--end-date")
  
  if (length(start_date_idx) > 0 && length(end_date_idx) > 0) {
    start_date <- as.Date(args[start_date_idx + 1])
    end_date <- as.Date(args[end_date_idx + 1])
    date_range <- c(start_date, end_date)
  }
  
  # Execute requested action
  if ("--summary" %in% args) {
    generate_leadership_summary(config, date_range)
  }
  
  if ("--export" %in% args) {
    export_idx <- which(args == "--export")
    output_file <- if (length(export_idx) > 0 && export_idx < length(args)) {
      args[export_idx + 1]
    } else {
      "leadership_report.csv"
    }
    export_leadership_data(config, output_file, date_range)
  }
}

# Run if called directly
if (!interactive()) {
  main()
} 