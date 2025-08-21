
############################################################
##  AutoEpi – Log bootstrapper (CSV edition)
##  --------------------------------------------------------
##  1.  Loads saved settings.
##  2.  Finds (or builds) a log CSV in the configured Logs_Dir.
##  3.  Writes the CSV (if new or updated).
##  4.  Saves the CSV path as LogsFileLoc in LogsFileLoc.RData
############################################################

## --- 1.  Load global settings ----------------------------------------------
load("AutoEpi_Settings.RData")          # provides 'autoepi_settings'
if (!exists("autoepi_settings"))
  stop("autoepi_settings object not found – check AutoEpi_Settings.RData")

logs_dir    <- normalizePath(autoepi_settings$IO$Logs_Dir, winslash = "/",
                             mustWork = FALSE)
reports_dir <- normalizePath(autoepi_settings$IO$Reports_Dir, winslash = "/",
                             mustWork = FALSE)

if (!dir.exists(logs_dir))
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

## --- 2.  Locate or create the log CSV --------------------------------------
candidate_csvs <- list.files(logs_dir,
                             pattern = "\\.csv$",
                             full.names = TRUE)

# Use the most-recent CSV if one exists
if (length(candidate_csvs)) {
  csv_file <- candidate_csvs[order(file.info(candidate_csvs)$mtime,
                                   decreasing = TRUE)][1]
  
  # Use readr for proper column type handling
  suppressPackageStartupMessages(library(readr))
  logs_df <- read_csv(csv_file,
                      col_types = cols(
                        ObvsDate       = col_date(),
                        presented_name = col_character(),
                        AlertLevel     = col_factor(levels = c("Normal", "Warning", "Alert", "False Positive")),
                        ReportCreated  = col_factor(levels = c("no", "yes")),
                        ReportLocation = col_character(),
                        EmailSent      = col_factor(levels = c("no", "yes"))
                      ))
  
  message("Existing log found: ", csv_file)
  
} else {
  # --- Build a fresh template ----------------------------------------------
  logs_df <- data.frame(
    ObvsDate       = as.Date(character()),
    presented_name = character(),
    AlertLevel     = factor(character(),
                            levels = c("Normal", "Warning",
                                       "Alert", "False Positive")),
    ReportCreated  = factor(character(), levels = c("no", "yes")),
    ReportLocation = character(),   # fill when you append rows
    EmailSent      = factor(character(), levels = c("no", "yes")),
    stringsAsFactors = FALSE
  )
  
  csv_file <- file.path(logs_dir, "autoepi_logs.csv")
  message("No existing log – new template will be created: ", csv_file)
}

## --- 3.  Persist / refresh the CSV -----------------------------------------
write_csv(logs_df, csv_file)

## --- 4.  Advertise log location --------------------------------------------
LogsFileLoc <- csv_file
save(LogsFileLoc, file = file.path("LogsFileLoc.RData"))
message("LogsFileLoc saved to LogsFileLoc.RData (", LogsFileLoc, ")")

## --- 5.  Clean exit ---------------------------------------------------------
invisible(TRUE)
