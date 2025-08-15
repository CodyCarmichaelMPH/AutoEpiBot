############################################################
##  AutoEpi – Email Summary Generator
##  --------------------------------------------------------
##  Prerequisites: • EmailStarterInfo.RData    (from TSCreate.R)
##                 • LogsFileLoc.RData         (from LogsCreate.R)
##                 • AutoEpi_Settings.RData    (from GUI.R)
##
##  Generates and sends automated email summaries using RDCOMClient
##  - Summary of examined syndromes and date ranges
##  - List of generated reports (if any)
##  - Link to logs for detailed review
##  - Dynamic subject line based on alert count
############################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(glue)
  library(knitr)
  if (!requireNamespace("RDCOMClient", quietly = TRUE)) {
    stop("RDCOMClient package required. Install with: install.packages('RDCOMClient')")
  }
  library(RDCOMClient)
})

# ------------------------------------------------------------------
# 1.  Load required data files
# ------------------------------------------------------------------
cat("AutoEpi Email Creator\n")
cat("=====================\n")

# Load email starter info (what syndromes were queried)
if (!file.exists("EmailStarterInfo.RData")) {
  stop("EmailStarterInfo.RData not found. Run TSCreate.R first.")
}
load("EmailStarterInfo.RData")  # -> email_df

# Load logs location
if (!file.exists("LogsFileLoc.RData")) {
  stop("LogsFileLoc.RData not found. Run LogsCreate.R first.")
}
load("LogsFileLoc.RData")  # -> LogsFileLoc

# Load settings (for email configuration if needed)
if (!file.exists("AutoEpi_Settings.RData")) {
  stop("AutoEpi_Settings.RData not found. Run GUI.R first.")
}
load("AutoEpi_Settings.RData")  # -> autoepi_settings

# ------------------------------------------------------------------
# 2.  Read current logs
# ------------------------------------------------------------------
if (!file.exists(LogsFileLoc)) {
  stop("Log file not found at ", LogsFileLoc)
}

log_levels <- c("Normal", "Warning", "Alert", "False Positive")
logs_df <- read_csv(LogsFileLoc,
                    col_types = cols(
                      ObvsDate       = col_date(),
                      presented_name = col_character(),
                      AlertLevel     = col_factor(levels = log_levels),
                      ReportCreated  = col_factor(levels = c("no", "yes")),
                      ReportLocation = col_character(),
                      EmailSent      = col_factor(levels = c("no", "yes"))
                    ))

# ------------------------------------------------------------------
# 3.  Prepare email content components
# ------------------------------------------------------------------

# A. Syndrome examination summary (from email_df)
syndrome_summary <- email_df %>%
  arrange(presented_name) %>%
  select(
    Syndrome = presented_name,
    `Start Date` = StartDate,
    `End Date` = EndDate
  )

# B. Reports generated summary
reports_generated <- logs_df %>%
  filter(ReportCreated == "yes") %>%
  arrange(ObvsDate, presented_name) %>%
  select(
    Syndrome = presented_name,
    Date = ObvsDate,
    `Report Location` = ReportLocation
  )

# Load individual report metadata if available
individual_reports_path <- file.path(autoepi_settings$IO$Reports_Dir, "individual_reports_metadata.RData")
individual_reports_list <- list()
if (file.exists(individual_reports_path)) {
  load(individual_reports_path)  # individual_reports_metadata
  individual_reports_list <- individual_reports_metadata
}

# C. Count alerts for subject line
alert_count <- logs_df %>%
  filter(AlertLevel %in% c("Warning", "Alert")) %>%
  nrow()

# D. Generate subject line
today_date <- format(Sys.Date(), "%Y-%m-%d")
subject_line <- if (nrow(reports_generated) == 0) {
  glue("AutoEpi Results for {today_date} - No Alerts")
} else {
  glue("AutoEpi Results for {today_date} - {alert_count} Alert(s)")
}

# ------------------------------------------------------------------
# 4.  Create HTML email body
# ------------------------------------------------------------------

# Helper function to convert data frame to HTML table
df_to_html_table <- function(df, caption = NULL) {
  if (nrow(df) == 0) {
    return("<p><em>No data to display</em></p>")
  }
  
  html <- "<table border='1' style='border-collapse: collapse; margin: 10px 0;'>\n"
  
  if (!is.null(caption)) {
    html <- paste0(html, "<caption style='font-weight: bold; margin-bottom: 5px;'>", 
                   caption, "</caption>\n")
  }
  
  # Header row
  html <- paste0(html, "<tr style='background-color: #f0f0f0;'>\n")
  for (col_name in names(df)) {
    html <- paste0(html, "<th style='padding: 8px; text-align: left;'>", 
                   col_name, "</th>\n")
  }
  html <- paste0(html, "</tr>\n")
  
  # Data rows
  for (i in seq_len(nrow(df))) {
    html <- paste0(html, "<tr>\n")
    for (j in seq_len(ncol(df))) {
      cell_value <- df[i, j]
      if (is.na(cell_value)) cell_value <- ""
      html <- paste0(html, "<td style='padding: 8px;'>", cell_value, "</td>\n")
    }
    html <- paste0(html, "</tr>\n")
  }
  
  html <- paste0(html, "</table>\n")
  return(html)
}

# Build email body
email_body <- glue("
<html>
<body style='font-family: Arial, sans-serif; line-height: 1.6;'>

<h2>AutoEpi Daily Summary</h2>

<p>Hello!</p>

<p>Today we examined the following syndromes on the following dates:</p>

{df_to_html_table(syndrome_summary)}

")

# Add reports section if any exist
if (nrow(reports_generated) > 0) {
  email_body <- paste0(email_body, glue("
<p>The following reports were generated:</p>

{df_to_html_table(reports_generated)}

"))
  
  # Add individual report links if available
  if (length(individual_reports_list) > 0) {
    email_body <- paste0(email_body, "
<h3>Individual Alert Reports</h3>
<p>Detailed HTML reports have been generated for each syndrome:</p>
<ul>
")
    
    for (report in individual_reports_list) {
      report_name <- basename(report$file_path)
      email_body <- paste0(email_body, glue("
<li><strong>{report$syndrome}</strong> ({report$date}) - {report$visit_count} visits
    <br/>Attachment: <a href='file:///{normalizePath(report$file_path, winslash='/')}'>Open Report</a>
</li>
"))
    }
    
    email_body <- paste0(email_body, "</ul>")
  }
  
} else {
  email_body <- paste0(email_body, "
<p><strong>No reports were generated today.</strong> All examined syndromes were within normal parameters.</p>

")
}

# Add footer
email_body <- paste0(email_body, glue("
<p>Please view detailed logs at: <code>{LogsFileLoc}</code></p>

<hr style='margin: 20px 0;'>

<p style='font-size: 0.9em; color: #666;'>
This report was generated by AutoEpiBot. For assistance after November 1, 2025, 
please contact Cody Carmichael, MPH, CPH at 
<a href='mailto:codymicah.carmichael@gmail.com'>codymicah.carmichael@gmail.com</a>
</p>

</body>
</html>
"))

# ------------------------------------------------------------------
# 5.  Create and send email using RDCOMClient
# ------------------------------------------------------------------

cat("Creating email...\n")

tryCatch({
  # Create Outlook application object
  outlook_app <- COMCreate("Outlook.Application")
  
  # Create new mail item
  mail_item <- outlook_app$CreateItem(0)  # 0 = olMailItem
  
  # Set email properties
  mail_item[["Subject"]] <- subject_line
  mail_item[["HTMLBody"]] <- email_body
  
  # Set recipients from configuration
  email_recipients <- autoepi_settings$Email_Settings$Recipients
  from_address <- autoepi_settings$Email_Settings$From_Address
  
  if (length(email_recipients) > 0) {
    # Set primary recipients
    mail_item[["To"]] <- paste(email_recipients, collapse = "; ")
    cat("Recipients configured:", paste(email_recipients, collapse = ", "), "\n")
  } else {
    cat("WARNING: No email recipients configured in settings\n")
  }
  
  if (nzchar(from_address)) {
    # Note: Setting SentOnBehalfOfName for display purposes
    # Actual sending account depends on logged-in Outlook user
    mail_item[["SentOnBehalfOfName"]] <- from_address
  }
  
  # Attach individual HTML reports if they exist
  if (length(individual_reports_list) > 0) {
    cat("Attaching", length(individual_reports_list), "individual reports...\n")
    for (report in individual_reports_list) {
      if (file.exists(report$file_path)) {
        mail_item$Attachments$Add(normalizePath(report$file_path))
        cat("  SUCCESS: Attached:", basename(report$file_path), "\n")
      }
    }
  }
  
  # Check if auto-send is enabled (can be added to settings later)
  auto_send <- length(email_recipients) > 0  # Auto-send if recipients are configured
  
  if (auto_send) {
    # Send automatically
    mail_item$Send()
    cat("SUCCESS: Email sent automatically to", length(email_recipients), "recipients\n")
  } else {
    # Display for manual review
    mail_item$Display()
    cat("Email created and displayed in Outlook for manual review\n")
  }
  
  cat("Subject:", subject_line, "\n")
  cat("Syndromes examined:", nrow(syndrome_summary), "\n")
  cat("Reports generated:", nrow(reports_generated), "\n")
  if (length(individual_reports_list) > 0) {
    cat("Individual reports attached:", length(individual_reports_list), "\n")
  }
  
}, error = function(e) {
  cat("ERROR: Error creating email:", conditionMessage(e), "\n")
  cat("Make sure Microsoft Outlook is installed and accessible.\n")
  
  # Fallback: Save email content to file
  email_file <- file.path(getwd(), glue("AutoEpi_Email_{today_date}.html"))
  writeLines(email_body, email_file)
  cat("Email content saved to:", email_file, "\n")
})

# ------------------------------------------------------------------
# 6.  Update logs to mark emails as processed
# ------------------------------------------------------------------

# Update EmailSent status for syndromes that were in today's run
today_syndromes <- unique(email_df$presented_name)

logs_df <- logs_df %>%
  mutate(
    EmailSent = case_when(
      presented_name %in% today_syndromes ~ 
        factor("yes", levels = c("no", "yes")),
      TRUE ~ EmailSent
    )
  )

# Save updated logs
write_csv(logs_df, LogsFileLoc)

updated_email_count <- logs_df %>%
  filter(presented_name %in% today_syndromes) %>%
  nrow()

cat("Updated", updated_email_count, "log entries to mark emails as sent\n")

cat("\nAutoEpi Email Creator Complete\n")
cat("==============================\n")

# ------------------------------------------------------------------
# 7.  Summary output
# ------------------------------------------------------------------
cat("Email Summary:\n")
cat("   Subject:", subject_line, "\n")
cat("   Syndromes examined:", nrow(syndrome_summary), "\n") 
cat("   Reports generated:", nrow(reports_generated), "\n")
cat("   Alert level records:", alert_count, "\n")
cat("   Log file:", LogsFileLoc, "\n")
