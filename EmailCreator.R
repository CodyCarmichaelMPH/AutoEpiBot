############################################################
##  AutoEpi – Enhanced Email Summary Generator
##  --------------------------------------------------------
##  Prerequisites: • EmailStarterInfo.RData    (from TSCreate.R)
##                 • LogsFileLoc.RData         (from LogsCreate.R)
##                 • AutoEpi_Settings.RData    (from GUI.R)
##
##  Generates and sends automated email summaries using enhanced Outlook integration
##  - Summary of examined syndromes and date ranges
##  - List of generated reports (if any)
##  - Link to logs for detailed review
##  - Dynamic subject line based on alert count
##  - Enhanced Outlook integration based on proven email script
############################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(glue)
  library(knitr)
  library(stringr)
  library(stringdist)
})

# Enhanced Outlook integration functions (based on proven script)
load_or_install <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  suppressPackageStartupMessages(
    library(pkg, character.only = TRUE, quietly = TRUE)
  )
  TRUE
}

ensure_dependencies <- function() {
  pkgs <- c("RDCOMClient")
  vapply(pkgs, load_or_install, FUN.VALUE = logical(1))
  invisible(NULL)
}

get_outlook_app <- function() {
  app <- tryCatch(RDCOMClient::COMCreate("Outlook.Application"),
                  error = function(e) NULL)
  if (is.null(app)) {
    stop("Could not create Outlook COM object – is Outlook installed *and* running?")
  }
  app
}

# Ensure dependencies are loaded
ensure_dependencies()

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
# 5.  Enhanced email creation and sending
# ------------------------------------------------------------------

cat("Creating email...\n")

# Get recipient email addresses (prompt user if not configured)
email_recipients <- autoepi_settings$Email_Settings$Recipients

if (length(email_recipients) == 0) {
  cat("No email recipients configured in settings.\n")
  
  # In interactive mode, prompt for recipients
  if (interactive()) {
    cat("Please enter the email address(es) where you want to send the report:\n")
    email_input <- readline("Enter email addresses (comma-separated): ")
    
    if (nzchar(email_input)) {
      email_recipients <- trimws(strsplit(email_input, ",")[[1]])
      # Validate email format (basic check)
      valid_emails <- grepl("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", email_recipients)
      if (all(valid_emails)) {
        cat("Using recipients:", paste(email_recipients, collapse = ", "), "\n")
      } else {
        invalid_emails <- email_recipients[!valid_emails]
        cat("WARNING: Invalid email format detected:", paste(invalid_emails, collapse = ", "), "\n")
        cat("Email will be displayed for manual review.\n")
        email_recipients <- character(0)
      }
    } else {
      cat("No recipients provided. Email will be displayed for manual sending.\n")
      email_recipients <- character(0)
    }
  } else {
    cat("Running in non-interactive mode. Email will be displayed for manual review.\n")
  }
}

# Test Outlook availability first
outlook_available <- FALSE
if (.Platform$OS.type == "windows" && requireNamespace("RDCOMClient", quietly = TRUE)) {
  outlook_available <- tryCatch({
    test_app <- get_outlook_app()
    TRUE
  }, error = function(e) {
    cat("WARNING: Outlook not available -", conditionMessage(e), "\n")
    FALSE
  })
}

if (outlook_available) {
  # Create actual email in Outlook
  tryCatch({
    outlook_app <- get_outlook_app()
    
    # Create new mail item
    mail_item <- outlook_app$CreateItem(0)  # 0 = olMailItem
    
    # Set email properties
    mail_item[["Subject"]] <- subject_line
    mail_item[["HTMLBody"]] <- email_body
    
    # Set recipients
    if (length(email_recipients) > 0) {
      # Set primary recipients
      mail_item[["To"]] <- paste(email_recipients, collapse = "; ")
      cat("Recipients configured:", paste(email_recipients, collapse = ", "), "\n")
    } else {
      cat("No recipients set - email will be displayed for manual review\n")
    }
    
    # Attach individual HTML reports if they exist
    if (length(individual_reports_list) > 0) {
      cat("Attaching", length(individual_reports_list), "individual reports...\n")
      for (report in individual_reports_list) {
        if (file.exists(report$file_path)) {
          # Use enhanced path handling
          attachment_path <- normalizePath(report$file_path, winslash = "\\", mustWork = FALSE)
          mail_item$Attachments$Add(attachment_path)
          cat("  SUCCESS: Attached:", basename(report$file_path), "\n")
        } else {
          cat("  WARNING: Report file not found:", report$file_path, "\n")
        }
      }
    }
    
    # Determine sending behavior
    auto_send <- length(email_recipients) > 0  # Auto-send if recipients are configured
    
    if (auto_send) {
      # Send automatically
      mail_item$Send()
      cat("SUCCESS: Email sent automatically to", length(email_recipients), "recipients\n")
    } else {
      # Display for manual review and sending
      mail_item$Display()
      cat("SUCCESS: Email created and displayed in Outlook for manual review/sending\n")
    }
    
    cat("Subject:", subject_line, "\n")
    cat("Syndromes examined:", nrow(syndrome_summary), "\n")
    cat("Reports generated:", nrow(reports_generated), "\n")
    if (length(individual_reports_list) > 0) {
      cat("Individual reports attached:", length(individual_reports_list), "\n")
    }
    
  }, error = function(e) {
    cat("ERROR: Failed to create email in Outlook:", conditionMessage(e), "\n")
    outlook_available <<- FALSE  # Force fallback
  })
}

# Fallback only if Outlook is not available
if (!outlook_available) {
  cat("FALLBACK: Creating email as HTML file (Outlook not available)\n")
  
  # Create enhanced email file with instructions
  email_file <- file.path(getwd(), glue("AutoEpi_Email_{today_date}.html"))
  
  # Add instructions to the email body
  enhanced_email_body <- paste0(
    '<div style="background: #fffacd; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd;">',
    '<h3>📧 Email Instructions</h3>',
    '<p><strong>This email was saved as an HTML file because Outlook is not available.</strong></p>',
    if (length(email_recipients) > 0) {
      paste0('<p><strong>Send to:</strong> ', paste(email_recipients, collapse = ", "), '</p>')
    } else {
      '<p><strong>Recipients:</strong> Configure recipients in AutoEpi settings or enter manually</p>'
    },
    '<p><strong>Subject:</strong> ', subject_line, '</p>',
    '</div>',
    email_body
  )
  
  writeLines(enhanced_email_body, email_file)
  cat("Email content saved to:", email_file, "\n")
  cat("NEXT STEP: Open this file in a browser, copy content, and paste into your email client\n")
  
  if (length(email_recipients) > 0) {
    cat("Send to:", paste(email_recipients, collapse = ", "), "\n")
  }
}

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
