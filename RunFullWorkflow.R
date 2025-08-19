############################################################
##  AutoEpi – Simple Workflow Runner (DEPRECATED)
##  --------------------------------------------------------
##  NOTE: This script is deprecated. Use AutoEpiBot_Runner.R instead
##        for better error handling and progress tracking.
##  
##  Basic workflow execution - runs all scripts in order
############################################################

cat("WARNING: This script is deprecated. Please use AutoEpiBot_Runner.R for better functionality.\n")
cat("Continuing with basic workflow...\n\n")

# Check prerequisites
if (!file.exists("AutoEpi_Settings.RData")) {
  stop("ERROR: AutoEpi_Settings.RData not found. Please run GUI.R first to configure settings.")
}

start_time <- Sys.time()

tryCatch({
  
  # Step 1: Initialize logging system
  cat("Step 1: Initializing logging system...\n")
  source("LogsCreate.R")
  cat("SUCCESS: Logging system ready\n\n")
  
  # Step 2: Pull time series data
  cat("Step 2: Pulling time series data from ESSENCE...\n")
  source("TSCreate.R")
  cat("SUCCESS: Time series data collected\n\n")
  
  # Step 3: Investigate and filter alerts
  cat("Step 3: Investigating alerts and filtering false positives...\n")
  source("TSInvestigate.R")
  cat("SUCCESS: Alert investigation complete\n\n")
  
  # Step 4: Generate comprehensive visualizations
  cat("Step 4: Creating visualizations and maps...\n")
  source("ReportCreator.R")
  cat("SUCCESS: Comprehensive report generated\n\n")
  
  # Step 5: Generate individual HTML reports
  cat("Step 5: Creating individual HTML reports per syndrome+date...\n")
  source("render_autoepi_reports.R")
  cat("SUCCESS: Individual HTML reports created\n\n")
  
  # Step 6: Send email summary
  cat("Step 6: Preparing and sending email summary...\n")
  source("EmailCreator.R")
  cat("SUCCESS: Email summary sent\n\n")
  
  end_time <- Sys.time()
  duration <- round(as.numeric(end_time - start_time, units = "mins"), 2)
  
  cat("AutoEpiBot Workflow Complete!\n")
  cat("================================\n")
  cat("Total runtime:", duration, "minutes\n")
  cat("Check your Reports folder for generated files\n")
  cat("Check your email for the summary\n\n")
  
}, error = function(e) {
  cat("ERROR: Workflow failed with error:\n")
  cat("Error:", conditionMessage(e), "\n")
  cat("Check the individual script outputs for details\n")
})

cat("AutoEpiBot workflow finished at", format(Sys.time()), "\n")
