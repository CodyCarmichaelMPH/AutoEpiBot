############################################################
##  AutoEpi – Quick Workflow Execution
##  --------------------------------------------------------
##  Minimal script that simply runs all workflow scripts
##  in order. No fancy error handling - just execution.
##  
##  Use this for testing or when you want simple execution.
############################################################

cat("AutoEpiBot Quick Runner\n")
cat("=========================\n")

# Simple prerequisite check
if (!file.exists("AutoEpi_Settings.RData")) {
  stop("ERROR: Settings not found. Run GUI.R first.")
}

cat("Running workflow scripts...\n\n")

# Execute scripts in order
scripts <- c(
  "LogsCreate.R",
  "TSCreate.R", 
  "TSInvestigate.R",
  "ReportCreator.R",
  "HTMLReportGenerator.R",
  "EmailCreator.R"
)

for (script in scripts) {
  cat("Running", script, "...\n")
  source(script)
  cat("Completed", script, "\n\n")
}

cat("Quick workflow complete!\n")
