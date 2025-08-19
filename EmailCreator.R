#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(glue)
  library(stringr)
  library(fs)
  library(readr)
  library(dplyr)
  library(lubridate)
})

# Check if RDCOMClient is available
if (!requireNamespace("RDCOMClient", quietly = TRUE)) {
  stop("RDCOMClient package is required for email functionality. Please install it first.")
}

# -----------------------
# Configuration
# -----------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript EmailCreator.R <settings_path> <logs_csv_path>")
}

settings_path <- args[[1]]
logs_path <- args[[2]]

if (!file.exists(settings_path)) stop("Settings file not found: ", settings_path)
if (!file.exists(logs_path)) stop("Logs file not found: ", logs_path)

# Load required data files
load(settings_path)  # loads autoepi_settings

# Load additional data files if they exist
if (file.exists("LogsFileLoc.RData")) {
  load("LogsFileLoc.RData")  # loads LogsFileLoc
}

if (file.exists("reportsData.RData")) {
  load("reportsData.RData")  # loads reports_df
}

reports_dir <- normalizePath(autoepi_settings$IO$Reports_Dir, winslash = "/", mustWork = FALSE)

# -----------------------
# Helper Functions
# -----------------------
`%||%` <- function(a, b) if (!is.null(a) && length(a)) a else b

# Format date for display (MM-DD-YYYY)
fmt_date_display <- function(d) {
  if (inherits(d, "Date")) return(format(d, "%m-%d-%Y"))
  if (is.character(d)) {
    # Try to parse and format
    parsed <- tryCatch(as.Date(d), error = function(e) NULL)
    if (!is.null(parsed)) return(format(parsed, "%m-%d-%Y"))
  }
  as.character(d)
}

# -----------------------
# Load and Process Data
# -----------------------
# Find Rendered reports
rendered_root <- path(reports_dir, "Rendered")
if (!dir_exists(rendered_root)) {
  message("No Rendered directory found. Creating email without report links.")
  html_files <- character(0)
} else {
  html_files <- dir_ls(rendered_root, regexp = "\\_AutoEpi.html$", recurse = TRUE, type = "file")
}

# Index reports
report_index <- tibble::tibble(
  path = html_files,
  file = path_file(html_files),
  date_key = str_match(file, "^(.*?)__")[,2],
  syndrome_key = str_match(file, "__(.*?)__AutoEpi.html$")[,2]
)

# Load logs
logs <- read_csv(logs_path, show_col_types = FALSE)

# Normalize column names (handle case variations)
col_names <- tolower(names(logs))
names(logs) <- col_names

# Ensure required columns exist
required_cols <- c("obvsdate", "presented_name", "alertlevel", "reportcreated", "reportlocation", "emailsent")
missing_cols <- setdiff(required_cols, col_names)
if (length(missing_cols) > 0) {
  stop("Missing required columns in logs: ", paste(missing_cols, collapse = ", "))
}

# Normalize data
logs <- logs %>%
  mutate(
    ObvsDate = as.Date(obvsdate),
    Date_Display = fmt_date_display(ObvsDate),
    Syndrome = presented_name,
    Alert_Level = as.character(alertlevel),  # AlertLevel is already a factor with correct levels
    Report_Created = if_else(reportcreated == "yes", "Yes", "No"),
    Email_Sent = if_else(emailsent == "yes", "Yes", "No"),
    obvsdate_chr = as.character(obvsdate),
    presented_name_norm = str_to_lower(str_squish(presented_name))
  )

# Match reports to logs
report_index <- report_index %>%
  mutate(
    obvsdate_chr = date_key,
    presented_name_norm = str_to_lower(str_squish(syndrome_key))
  )

# Update logs with report information
logs_updated <- logs %>% 
  left_join(report_index, by = c("obvsdate_chr", "presented_name_norm")) %>%
  mutate(
    Report_Created = if_else(!is.na(path), "Yes", Report_Created),
    Report_Location = if_else(!is.na(path), path, reportlocation),
    Email_Sent = "Yes"  # This email will be sent
  ) %>%
  select(-file, -date_key, -syndrome_key, -obvsdate_chr, -presented_name_norm)

# -----------------------
# Prepare Email Content
# -----------------------
# Get date range for email
date_range <- range(logs_updated$ObvsDate, na.rm = TRUE)
start_date <- fmt_date_display(date_range[1])
end_date <- fmt_date_display(date_range[2])

# Separate alerts from non-alerts
alerts <- logs_updated %>% 
  filter(Alert_Level %in% c("Warning", "Alert", "False Positive")) %>%
  arrange(factor(Alert_Level, levels = c("Alert", "Warning", "False Positive")), ObvsDate, Syndrome) %>%
  select(Date = Date_Display, Syndrome, `Alert Level` = Alert_Level, `Report Created` = Report_Created)

non_alerts <- logs_updated %>% 
  filter(Alert_Level == "Normal") %>%
  arrange(ObvsDate, Syndrome) %>%
  select(Date = Date_Display, Syndrome, `Alert Level` = Alert_Level, `Report Created` = Report_Created)

# Count summary
total_records <- nrow(logs_updated)
alert_count <- nrow(alerts)
non_alert_count <- nrow(non_alerts)
reports_created <- sum(logs_updated$Report_Created == "Yes", na.rm = TRUE)

# Count by alert level for more detailed summary
alert_breakdown <- logs_updated %>%
  count(Alert_Level) %>%
  arrange(factor(Alert_Level, levels = c("Alert", "Warning", "False Positive", "Normal")))

# Get investigation context if available
investigation_info <- ""
if (exists("reports_df") && nrow(reports_df) > 0) {
  investigation_info <- glue("\n\nInvestigation Results:\n- Records Investigated: {nrow(reports_df)}\n- These records passed the statistical threshold test and were retained for detailed analysis.")
}

# -----------------------
# Create Email Content
# -----------------------
# Create email subject
email_subject <- glue("AutoEpi Daily Summary Report - {start_date} to {end_date}")

# Create email body sections
alert_breakdown_text <- paste0("- ", alert_breakdown$Alert_Level, ": ", alert_breakdown$n, " records", collapse = "\n")

alerts_text <- if(nrow(alerts) > 0) {
  paste0(apply(alerts, 1, function(row) {
    paste0("Date: ", row['Date'], "\nSyndrome: ", row['Syndrome'], "\nAlert Level: ", row['Alert Level'], "\nReport Created: ", row['Report Created'], "\n")
  }), collapse = "\n")
} else {
  "No alerts requiring attention."
}

non_alerts_text <- if(nrow(non_alerts) > 0) {
  paste0(apply(non_alerts, 1, function(row) {
    paste0("Date: ", row['Date'], "\nSyndrome: ", row['Syndrome'], "\nAlert Level: ", row['Alert Level'], "\nReport Created: ", row['Report Created'], "\n")
  }), collapse = "\n")
} else {
  "No normal activity records."
}

# Create email body
email_body <- glue("
AutoEpi Daily Summary Report
============================

Date Range: {start_date} to {end_date}
Generated: {format(Sys.time(), \"%m-%d-%Y %H:%M:%S %Z\")}

Summary:
- Total Records: {total_records}
- Alerts Requiring Attention: {alert_count}
- Normal Records: {non_alert_count}
- Reports Generated: {reports_created}

Alert Level Breakdown:
{alert_breakdown_text}{investigation_info}

ALERTS REQUIRING ATTENTION:
==========================
{alerts_text}

NORMAL ACTIVITY:
===============
{non_alerts_text}

Alert Level Definitions:
- Alert: Significant increase in cases requires immediate investigation
- Warning: Moderate increase in cases monitor closely
- False Positive: Initial alert was flagged but investigation showed normal levels
- Normal: No significant increase in cases detected

Next Steps:
- High Priority: Review Alert level syndromes these require immediate investigation
- Medium Priority: Monitor Warning level syndromes for trends
- Low Priority: False Positive flags indicate normal activity after investigation
- Access generated reports using the file paths below
- Update logs with any follow-up actions taken

Investigation Process:
The AutoEpi system uses a two-stage process:
1. Initial Detection: Time series analysis identifies potential increases
2. Investigation: Detailed analysis compares visit counts to historical thresholds

Records marked as False Positive passed initial detection but failed the statistical threshold test during investigation.

File Locations:
- Logs File: {logs_path}
- Reports Directory: {reports_dir}
- Rendered Reports: {rendered_root}

This is an automated report from the AutoEpi surveillance system. Please contact the system administrator if you have any questions.
")

# -----------------------
# Send Email via Outlook
# -----------------------
tryCatch({
  # Create Outlook application object
  outlook_app <- RDCOMClient::COMCreate("Outlook.Application")
  
  # Create email item
  mail_item <- outlook_app$CreateItem(0)  # 0 = olMailItem
  
  # Set email properties
  mail_item[["Subject"]] <- email_subject
  mail_item[["Body"]] <- email_body
  
  # Get recipient from settings if available
  if (!is.null(autoepi_settings$Email$Recipients)) {
    mail_item[["To"]] <- autoepi_settings$Email$Recipients
  }
  
  # Display email for review before sending
  mail_item$Display()
  
  # Ask user if they want to send
  cat("\n=== AutoEpi Email Summary Generated ===\n")
  cat("Email subject:", email_subject, "\n")
  cat("Email displayed in Outlook for review.\n")
  cat("\nSummary:\n")
  cat("- Total records processed:", total_records, "\n")
  cat("- Alerts requiring attention:", alert_count, "\n")
  cat("- Normal records:", non_alert_count, "\n")
  cat("- Reports generated:", reports_created, "\n")
  cat("\nThe email is now open in Outlook.\n")
  cat("Please review and send manually, or close to cancel.\n")
  
  # Note: We don't automatically send - user must review and send manually
  # This prevents accidental emails and allows for customization
  
}, error = function(e) {
  cat("ERROR: Failed to create email via Outlook:\n")
  cat("Error message:", conditionMessage(e), "\n")
  cat("Possible causes:\n")
  cat("- Outlook not installed or not running\n")
  cat("- Security settings blocking COM access\n")
  cat("- RDCOMClient package issues\n")
  
  # Fallback: save email content to file
  email_dir <- path(reports_dir, "Emails")
  dir_create(email_dir, recurse = TRUE)
  email_filename <- glue("AutoEpi_Summary_{format(Sys.Date(), '%Y-%m-%d')}.txt")
  email_path <- path(email_dir, email_filename)
  writeLines(email_body, email_path)
  
  cat("\nFallback: Email content saved to:", email_path, "\n")
  cat("Please send this content manually via your email client.\n")
})

# -----------------------
# Update Logs
# -----------------------
# Save updated logs
backup_path <- paste0(logs_path, ".bak")
file.copy(logs_path, backup_path, overwrite = TRUE)
write_csv(logs_updated, logs_path)

cat("\nLogs updated and backed up to:", backup_path, "\n")
cat("Email sent status updated in logs.\n")
