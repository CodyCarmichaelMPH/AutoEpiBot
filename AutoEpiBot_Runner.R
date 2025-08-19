############################################################
##  AutoEpiBot – Automated Execution Script
##  --------------------------------------------------------
##  Runs the complete AutoEpiBot workflow in the correct order
##  (excluding GUI.R - assumes settings are already configured)
##  
##  Execute this script to run the full epidemiological 
##  surveillance workflow automatically.
############################################################

cat("AutoEpiBot Automated Runner\n")
cat("===============================\n")
cat("Starting automated epidemiological surveillance workflow...\n\n")

# Record start time
workflow_start <- Sys.time()

# Define the workflow scripts in execution order
workflow_scripts <- c(
  "LogsCreate.R",           # 1. Initialize logging system
  "TSCreate.R",             # 2. Pull time series data from ESSENCE
  "TSInvestigate.R",        # 3. Investigate alerts and filter false positives
  "ReportCreator.R",        # 4. Generate comprehensive visualizations and maps
  "render_autoepi_reports.R",  # 5. Create individual HTML reports per syndrome+date
  "EmailCreator.R"          # 6. Send email summary with attachments
)

# Script descriptions for user feedback
script_descriptions <- c(
  "Initializing logging system",
  "Pulling time series data from ESSENCE API",
  "Investigating alerts and filtering false positives", 
  "Generating comprehensive visualizations and maps",
  "Rendering individual HTML reports per syndrome+date",
  "Preparing and sending email summary with attachments"
)

# ------------------------------------------------------------------
# Prerequisite checks
# ------------------------------------------------------------------
cat("Checking prerequisites...\n")

# Check if settings exist
if (!file.exists("AutoEpi_Settings.RData")) {
  cat("ERROR: AutoEpi_Settings.RData not found\n")
  cat("   Please run GUI.R first to configure your settings\n")
  stop("Settings file missing - workflow cannot proceed")
}

# Check if all workflow scripts exist
missing_scripts <- workflow_scripts[!file.exists(workflow_scripts)]
if (length(missing_scripts) > 0) {
  cat("ERROR: Missing required scripts:\n")
  for (script in missing_scripts) {
    cat("  -", script, "\n")
  }
  stop("Required scripts missing - workflow cannot proceed")
}

cat("SUCCESS: All prerequisites met\n\n")

# ------------------------------------------------------------------
# Execute workflow scripts
# ------------------------------------------------------------------
cat("Starting workflow execution...\n")
cat("Time:", format(Sys.time()), "\n\n")

execution_results <- list()
overall_success <- TRUE

for (i in seq_along(workflow_scripts)) {
  script_name <- workflow_scripts[i]
  description <- script_descriptions[i]
  
  cat("═══════════════════════════════════════════════════════════\n")
  cat("Step", i, "of", length(workflow_scripts), "\n")
  cat(description, "\n")
  cat("Script:", script_name, "\n")
  cat("═══════════════════════════════════════════════════════════\n")
  
  step_start <- Sys.time()
  
  tryCatch({
    # Execute the script based on its type
    if (script_name == "render_autoepi_reports.R") {
      # This script expects settings file as argument, can auto-discover report files
      system2("Rscript", args = c(script_name, "AutoEpi_Settings.RData"), 
              stdout = TRUE, stderr = TRUE)
    } else if (script_name == "EmailCreator.R") {
      # This script expects settings and logs file as arguments
      if (!exists("LogsFileLoc")) {
        load("LogsFileLoc.RData")
      }
      system2("Rscript", args = c(script_name, "AutoEpi_Settings.RData", LogsFileLoc), 
              stdout = TRUE, stderr = TRUE)
    } else {
      # Standard scripts that can be sourced
      source(script_name)
    }
    
    step_end <- Sys.time()
    step_duration <- round(as.numeric(step_end - step_start, units = "secs"), 1)
    
    cat("SUCCESS: Step", i, "completed successfully in", step_duration, "seconds\n\n")
    
    execution_results[[script_name]] <- list(
      success = TRUE,
      duration = step_duration,
      error = NULL
    )
    
  }, error = function(e) {
    step_end <- Sys.time()
    step_duration <- round(as.numeric(step_end - step_start, units = "secs"), 1)
    
    cat("ERROR: Step", i, "failed after", step_duration, "seconds\n")
    cat("Error:", conditionMessage(e), "\n\n")
    
    execution_results[[script_name]] <<- list(
      success = FALSE,
      duration = step_duration,
      error = conditionMessage(e)
    )
    
    overall_success <<- FALSE
    
    # Ask user if they want to continue with remaining steps
    cat("Would you like to continue with remaining steps? (Continue anyway: y/n)\n")
    # For automated execution, we'll continue by default
    # In interactive mode, uncomment the following lines:
    # response <- readline("Continue? (y/n): ")
    # if (tolower(response) != "y") {
    #   stop("Workflow terminated by user")
    # }
    cat("Continuing with remaining steps...\n\n")
  })
}

# ------------------------------------------------------------------
# Final summary
# ------------------------------------------------------------------
workflow_end <- Sys.time()
total_duration <- round(as.numeric(workflow_end - workflow_start, units = "mins"), 2)

cat("AutoEpiBot Workflow Summary\n")
cat("==============================\n")
cat("Execution completed at:", format(workflow_end), "\n")
cat("Total runtime:", total_duration, "minutes\n\n")

cat("Step-by-step results:\n")
for (i in seq_along(workflow_scripts)) {
  script_name <- workflow_scripts[i]
  result <- execution_results[[script_name]]
  
  status_icon <- if (result$success) "[SUCCESS]" else "[FAILED] "
  status_text <- if (result$success) "SUCCESS" else "FAILED"
  
  cat(sprintf("%s Step %d: %s (%s) - %.1fs\n", 
              status_icon, i, script_name, status_text, result$duration))
  
  if (!result$success) {
    cat(sprintf("    Error: %s\n", result$error))
  }
}

cat("\n")

if (overall_success) {
  cat("SUCCESS: All steps completed successfully!\n")
  cat("Check your Reports folder for generated files\n")
  cat("Check your email for the automated summary\n")
  cat("Check your logs for detailed audit trail\n")
} else {
  cat("WARNING: Workflow completed with some errors\n")
  cat("Review the summary above for details\n")
  cat("Fix any issues and re-run the workflow\n")
}

cat("\nWorkflow execution log saved internally\n")
cat("AutoEpiBot Runner finished\n")
