# AutoEpiBot - Email Sending
# Email Notification System for Alerts and Reports

send_email <- function(email_content, config) {
  log_info("Sending email notification")
  
  tryCatch({
    # Check if email is enabled
    if (!config$email$enabled) {
      log_info("Email notifications are disabled in configuration")
      return(TRUE)
    }
    
    # Determine email provider based on configuration
    if (!is.null(config$email$use_outlook) && config$email$use_outlook) {
      # Use Outlook/Office 365
      provider <- "office365"
      smtp_server <- "smtp.office365.com"
    } else {
      # Use Gmail (fallback)
      provider <- "gmail"
      smtp_server <- "smtp.gmail.com"
    }
    
    # Create email using blastula
    email <- blastula::compose_email(
      body = blastula::md(email_content),
      subject = paste0(config$email$subject_prefix, " ", format(Sys.Date(), "%B %d, %Y")),
      from = config$email$from_address,
      to = config$email$to_addresses
    )
    
    # Send email
    blastula::smtp_send(
      email,
      from = config$email$from_address,
      to = config$email$to_addresses,
      subject = paste0(config$email$subject_prefix, " ", format(Sys.Date(), "%B %d, %Y")),
      credentials = blastula::creds(
        provider = provider,
        user = config$email$from_address,
        password = config$email$password
      )
    )
    
    log_info(paste("Email sent successfully to", length(config$email$to_addresses), "recipients via", provider))
    return(TRUE)
    
  }, error = function(e) {
    log_error(paste("Error sending email:", e$message))
    return(FALSE)
  })
}

# Send individual alert email with report attachment
send_alert_email <- function(syndrome, alert_date, report_path, validation_result, config) {
  log_info(paste("Sending alert email for", syndrome$name, "on", alert_date))
  
  tryCatch({
    # Create email content
    email_content <- create_alert_email_content(syndrome, alert_date, validation_result, report_path)
    
    # Send email
    success <- send_email(email_content, config)
    
    if (success) {
      log_info(paste("Alert email sent for", syndrome$name, "on", alert_date))
    }
    
    return(success)
    
  }, error = function(e) {
    log_error(paste("Error sending alert email:", e$message))
    return(FALSE)
  })
}

# Create alert email content
create_alert_email_content <- function(syndrome, alert_date, validation_result, report_path) {
  alert_date_formatted <- format(as.Date(alert_date), "%B %d, %Y")
  
  # Determine status and color
  status_text <- if (validation_result$is_valid) "VALID ALERT" else "FALSE POSITIVE"
  status_color <- if (validation_result$is_valid) "#28a745" else "#dc3545"
  
  email_content <- paste0('
# AutoEpiBot Alert Notification

## Alert Summary

**Syndrome:** ', syndrome$name, '  
**Date:** ', alert_date_formatted, '  
**Status:** <span style="color: ', status_color, '; font-weight: bold;">', status_text, '</span>

## Validation Details

- **Current Count:** ', validation_result$current_count, '
- **Expected Count:** ', validation_result$expected_count, '
- **Historical Mean:** ', round(validation_result$historical_mean, 1), '
- **Ratio (Current/Expected):** ', round(validation_result$expected_ratio, 2), 'x
- **Z-Score:** ', round(validation_result$z_score, 2), '

## Validation Results

| Check | Result |
|-------|--------|
| Above Expected | ', ifelse(validation_result$is_above_expected, "✅ PASS", "❌ FAIL"), ' |
| Above Historical Mean | ', ifelse(validation_result$is_above_historical, "✅ PASS", "❌ FAIL"), ' |
| Statistically Significant | ', ifelse(validation_result$is_statistically_significant, "✅ PASS", "❌ FAIL"), ' |

## Reason

', validation_result$reason, '

## Report

', if (validation_result$is_valid) {
    paste0('A detailed HTML report has been generated and is available at:  
**', report_path, '**')
  } else {
    'No report generated for false positive alerts.'
  }, '

---

*This alert was processed automatically by AutoEpiBot.*
')
  
  return(email_content)
}

# Send test email
send_test_email <- function(config) {
  log_info("Sending test email")
  
  test_content <- paste0('
# AutoEpiBot Test Email

This is a test email to verify that the email configuration is working correctly.

**Test Details:**
- **Date:** ', format(Sys.time(), "%B %d, %Y at %I:%M %p"), '
- **System:** AutoEpiBot
- **Status:** Test

If you receive this email, the email configuration is working properly.

---

*This is an automated test message from AutoEpiBot.*
')
  
  return(send_email(test_content, config))
}

# Validate email configuration
validate_email_config <- function(config) {
  log_info("Validating email configuration")
  
  # Check required fields
  required_fields <- c("enabled", "smtp_server", "smtp_port", "from_address", "to_addresses")
  for (field in required_fields) {
    if (is.null(config$email[[field]])) {
      log_error(paste("Missing required email configuration field:", field))
      return(FALSE)
    }
  }
  
  # Check if email is enabled
  if (!config$email$enabled) {
    log_info("Email notifications are disabled")
    return(TRUE)
  }
  
  # Validate email addresses
  if (!grepl("@", config$email$from_address)) {
    log_error("Invalid from_address format")
    return(FALSE)
  }
  
  for (to_address in config$email$to_addresses) {
    if (!grepl("@", to_address)) {
      log_error(paste("Invalid to_address format:", to_address))
      return(FALSE)
    }
  }
  
  log_info("Email configuration validated successfully")
  return(TRUE)
}

# Create email credentials file (for blastula)
create_email_credentials <- function(config) {
  log_info("Creating email credentials")
  
  tryCatch({
    # Create credentials file for blastula
    blastula::create_smtp_creds_file(
      file = "email_creds",
      user = config$email$from_address,
      password = config$email$password,
      provider = "gmail"
    )
    
    log_info("Email credentials created successfully")
    return(TRUE)
    
  }, error = function(e) {
    log_error(paste("Error creating email credentials:", e$message))
    return(FALSE)
  })
}

# Send leadership report email
send_leadership_report_email <- function(results, config, date_range) {
  log_info("Sending leadership report email")
  
  tryCatch({
    # Count alerts and collect report paths
    total_alerts <- 0
    valid_alerts <- 0
    false_positives <- 0
    report_paths <- list()
    
    for (syndrome_name in names(results)) {
      syndrome_results <- results[[syndrome_name]]
      if (syndrome_results$status != "no_alerts" && syndrome_results$status != "no_data") {
        for (date_name in names(syndrome_results)) {
          date_result <- syndrome_results[[date_name]]
          if (is.list(date_result) && !is.null(date_result$status)) {
            total_alerts <- total_alerts + 1
            if (date_result$status == "sent") {
              valid_alerts <- valid_alerts + 1
              if (!is.null(date_result$report_path)) {
                report_paths[[length(report_paths) + 1]] <- date_result$report_path
              }
            } else if (date_result$status == "false_positive") {
              false_positives <- false_positives + 1
            }
          }
        }
      }
    }
    
    # Create leadership report content
    leadership_content <- create_leadership_report_content(results, config, date_range)
    
    # Send email with attachments if reports exist
    if (length(report_paths) > 0) {
      send_email_with_attachments(leadership_content, report_paths, config)
    } else {
      send_email(leadership_content, config)
    }
    
    log_info(paste("Leadership report email sent with", total_alerts, "alerts processed"))
    
  }, error = function(e) {
    log_error(paste("Error sending leadership report email:", e$message))
  })
}

# Create comprehensive leadership report content
create_leadership_report_content <- function(results, config, date_range) {
  # Get alert log data for comprehensive reporting
  alert_log <- load_alert_log(config)
  
  # Extract dates and syndromes from results
  dates_scanned <- paste(format(date_range$start_date, "%Y-%m-%d"), "to", format(date_range$end_date, "%Y-%m-%d"))
  
  # Collect alert information
  alert_dates <- c()
  alert_syndromes <- c()
  false_positive_syndromes <- c()
  report_locations <- c()
  
  for (syndrome_name in names(results)) {
    syndrome_results <- results[[syndrome_name]]
    
    if (syndrome_results$status != "no_alerts" && syndrome_results$status != "no_data") {
      for (date_name in names(syndrome_results)) {
        date_result <- syndrome_results[[date_name]]
        if (is.list(date_result) && !is.null(date_result$status)) {
          alert_dates <- c(alert_dates, date_name)
          
          if (date_result$status == "sent") {
            alert_syndromes <- c(alert_syndromes, syndrome_name)
            if (!is.null(date_result$report_path)) {
              report_locations <- c(report_locations, paste0(syndrome_name, " (", date_name, "): ", date_result$report_path))
            }
          } else if (date_result$status == "false_positive") {
            false_positive_syndromes <- c(false_positive_syndromes, syndrome_name)
          }
        }
      }
    }
  }
  
  # Remove duplicates
  alert_dates <- unique(alert_dates)
  alert_syndromes <- unique(alert_syndromes)
  false_positive_syndromes <- unique(false_positive_syndromes)
  
  # Build comprehensive report
  report_content <- paste0('
# AutoEpiBot Leadership Report

Report Generated: ', format(Sys.time(), "%B %d, %Y at %I:%M %p"), '

## Executive Summary

### Date Range Scanned
', dates_scanned, '

### Alert Activity Summary
- Dates with Alerts/Warnings: ', if(length(alert_dates) > 0) paste(alert_dates, collapse = ", ") else "None", '
- Total Alert Dates: ', length(alert_dates), '
- Total Syndromes Processed: ', length(results), '

### Syndromes with Alerts/Warnings
', if(length(alert_syndromes) > 0) paste("- ", alert_syndromes, collapse = "\n") else "- None", '

### Syndromes with False Positives
', if(length(false_positive_syndromes) > 0) paste("- ", false_positive_syndromes, collapse = "\n") else "- None", '

### Generated Reports and Locations
', if(length(report_locations) > 0) paste("- ", report_locations, collapse = "\n") else "- No reports generated", '

## Detailed Analysis

### Alert Statistics
- Valid Alerts: ', length(alert_syndromes), '
- False Positives: ', length(false_positive_syndromes), '
- Reports Generated: ', length(report_locations), '

### System Performance
- Processing Time: ', format(Sys.time() - Sys.time(), "%H:%M:%S"), '
- Data Sources: NSSP ESSENCE API
- Validation Method: Statistical comparison with historical trends

## Recommendations

', if(length(alert_syndromes) > 0) {
  paste0("- Immediate Action Required: Review alerts for ", paste(alert_syndromes, collapse = ", "), "
- Follow-up Monitoring: Continue surveillance for the next 7-14 days
- Stakeholder Notification: Consider notifying relevant public health partners")
} else {
  "- No Immediate Action Required: All alerts have been processed and validated
- Continue Routine Monitoring: System is functioning normally"
}, '

---

This report was generated automatically by AutoEpiBot for leadership review.
')
  
  return(report_content)
}

# Send email with attachments (for reports)
send_email_with_attachments <- function(email_content, attachment_paths, config) {
  log_info(paste("Sending email with", length(attachment_paths), "attachments"))
  
  tryCatch({
    # Create email with attachments using blastula
    email <- blastula::compose_email(
      body = blastula::md(email_content),
      subject = paste0(config$email$subject_prefix, " ", format(Sys.Date(), "%B %d, %Y")),
      from = config$email$from_address,
      to = config$email$to_addresses
    )
    
    # Add attachments
    for (attachment_path in attachment_paths) {
      if (file.exists(attachment_path)) {
        email <- blastula::add_attachment(email, attachment_path)
        log_info(paste("Added attachment:", attachment_path))
      } else {
        log_warn(paste("Attachment file not found:", attachment_path))
      }
    }
    
    # Send email
    blastula::smtp_send(
      email,
      from = config$email$from_address,
      to = config$email$to_addresses,
      subject = paste0(config$email$subject_prefix, " ", format(Sys.Date(), "%B %d, %Y")),
      credentials = blastula::creds(
        provider = "gmail",
        user = config$email$from_address,
        password = config$email$password
      )
    )
    
    log_info(paste("Email with attachments sent successfully to", length(config$email$to_addresses), "recipients"))
    return(TRUE)
    
  }, error = function(e) {
    log_error(paste("Error sending email with attachments:", e$message))
    return(FALSE)
  })
} 